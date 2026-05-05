local Opencode = {}
Opencode.__index = Opencode

local function json_encode(value)
  if vim.json and vim.json.encode then
    return vim.json.encode(value)
  end
  return vim.fn.json_encode(value)
end

local function json_decode(value)
  if vim.json and vim.json.decode then
    return vim.json.decode(value)
  end
  return vim.fn.json_decode(value)
end

function Opencode.new(opts)
  local self = setmetatable({}, Opencode)
  self.opts = vim.tbl_deep_extend("force", {
    opencode_host = "localhost",
    opencode_port = 63636,
    on_event = nil,
    on_stderr = nil,
    on_exit = nil,
  }, opts or {})
  self.subscribers = {}
  return self
end

function Opencode:configure(opts)
  self.opts = vim.tbl_deep_extend("force", self.opts, opts or {})
end

function Opencode:_base_url()
  return string.format("http://%s:%d", self.opts.opencode_host, self.opts.opencode_port)
end

function Opencode:subscribe(cb)
  table.insert(self.subscribers, cb)
  return function()
    for i, fn in ipairs(self.subscribers) do
      if fn == cb then
        table.remove(self.subscribers, i)
        break
      end
    end
  end
end

function Opencode:_emit_event(event)
  if self.opts.on_event then
    pcall(self.opts.on_event, event)
  end
  local subscribers = {}
  for i, cb in ipairs(self.subscribers) do
    subscribers[i] = cb
  end
  for _, cb in ipairs(subscribers) do
    pcall(cb, event)
  end
end

function Opencode:_http_request(method, path, body, callback)
  local url = self:_base_url() .. path
  local args = { "curl", "--silent", "--show-error", "--fail", "--location", "--retry", "1" }

  if method then
    table.insert(args, "-X")
    table.insert(args, method)
  end
  if body then
    table.insert(args, "-H")
    table.insert(args, "Content-Type: application/json")
    table.insert(args, "-d")
    table.insert(args, json_encode(body))
  end
  table.insert(args, url)

  vim.system(args, {}, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        local err = res.stderr ~= "" and res.stderr or string.format("Request failed with exit code %d", res.code)
        callback(nil, err)
        return
      end
      callback(res.stdout or "", nil)
    end)
  end)
end

function Opencode:_create_session(callback)
  self:_http_request("POST", "/session", { title = "nine.nvim" }, function(body, err)
    if err then
      callback(nil, err)
      return
    end
    local ok, decoded = pcall(json_decode, body)
    if not ok or type(decoded) ~= "table" then
      callback(nil, string.format("invalid session response: %s", body))
      return
    end
    if type(decoded.id) == "string" then
      callback(decoded.id, nil)
      return
    end
    if type(decoded) == "table" and #decoded > 0 then
      local newest = decoded[1]
      for _, s in ipairs(decoded) do
        if type(s) == "table" and type(s.time) == "table" and type(s.time.created) == "number" then
          if not newest.time or not newest.time.created or s.time.created > newest.time.created then
            newest = s
          end
        end
      end
      if type(newest) == "table" and type(newest.id) == "string" then
        callback(newest.id, nil)
        return
      end
    end
    callback(nil, string.format("invalid session response: %s", body))
  end)
end

function Opencode:_send_message(session_id, message, callback)
  local payload = {
    parts = {
      { type = "text", text = message },
    },
  }
  self:_http_request("POST", "/session/" .. session_id .. "/message", payload, function(body, err)
    if err then
      callback(nil, err)
      return
    end
    local ok, decoded = pcall(json_decode, body)
    if not ok or type(decoded) ~= "table" then
      callback(nil, string.format("invalid message response: %s", body))
      return
    end
    callback(decoded, nil)
  end)
end

function Opencode:_extract_last_text(parts)
  if type(parts) ~= "table" then
    return nil
  end
  local last_text = nil
  for _, part in ipairs(parts) do
    if type(part) == "table" and part.type == "text" and type(part.text) == "string" then
      last_text = part.text
    end
  end
  return last_text
end

function Opencode:_emit_streaming_events(text)
  self:_emit_event({
    type = "message_start",
    message = { role = "assistant" },
  })

  self:_emit_event({
    type = "message_update",
    message = { role = "assistant" },
    assistantMessageEvent = { type = "text_delta", delta = text },
  })

  self:_emit_event({
    type = "message_end",
    message = { role = "assistant" },
  })

  self:_emit_event({
    type = "agent_end",
    messages = {},
  })
end

function Opencode:prompt(message, on_response)
  local uv = vim.uv or vim.loop
  local id = "opencode-" .. tostring(uv.hrtime())

  self:_create_session(function(session_id, err)
    if err then
      if on_response then
        on_response({ success = false, error = string.format("session creation failed: %s", err) })
      end
      return
    end

    self:_send_message(session_id, message, function(response, msg_err)
      if msg_err then
        if on_response then
          on_response({ success = false, error = string.format("message send failed: %s", msg_err) })
        end
        return
      end

      local parts = nil
      if type(response) == "table" and #response > 0 then
        for i = #response, 1, -1 do
          local msg = response[i]
          if type(msg) == "table" and msg.info and msg.info.role == "assistant" then
            parts = msg.parts
            break
          end
        end
      elseif type(response) == "table" and response.parts then
        parts = response.parts
      end

      local text = self:_extract_last_text(parts)
      if not text then
        if on_response then
          on_response({ success = false, error = "no text part in response" })
        end
        return
      end

      self:_emit_streaming_events(text)

      if on_response then
        on_response({ success = true })
      end
    end)
  end)

  return id
end

return Opencode
