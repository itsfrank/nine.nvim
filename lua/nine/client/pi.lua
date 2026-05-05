local Client = {}
Client.__index = Client

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

local function ensure_list(value)
  if value == nil then
    return nil
  end
  if type(value) == "table" then
    return value
  end
  return { value }
end

local function next_id(seq)
  local uv = vim.uv or vim.loop
  return string.format("%d-%d", uv.hrtime(), seq)
end

function Client.new(opts)
  local self = setmetatable({}, Client)
  self.opts = vim.tbl_deep_extend("force", {
    pi_cmd = "pi",
    pi_args = { "--mode", "rpc", "--no-session", "--tools", "read,grep,find,ls" },
    cwd = vim.fn.getcwd(),
    auto_start = true,
    on_event = nil,
    on_stderr = nil,
    on_exit = nil,
  }, opts or {})
  self.job_id = nil
  self.seq = 0
  self.pending = {}
  self.subscribers = {}
  return self
end

function Client:configure(opts)
  self.opts = vim.tbl_deep_extend("force", self.opts, opts or {})
end

function Client:is_running()
  if not self.job_id then
    return false
  end
  return vim.fn.jobwait({ self.job_id }, 0)[1] == -1
end

function Client:subscribe(cb)
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

function Client:_emit_event(event)
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

function Client:_handle_stdout_line(line)
  if not line or line == "" then
    return
  end

  local ok, decoded = pcall(json_decode, line)
  if not ok then
    if self.opts.on_stderr then
      pcall(self.opts.on_stderr, { raw = line, error = decoded })
    end
    return
  end

  if decoded.type == "response" and decoded.id and self.pending[decoded.id] then
    local cb = self.pending[decoded.id]
    self.pending[decoded.id] = nil
    pcall(cb, decoded)
  end

  self:_emit_event(decoded)
end

function Client:_on_stdout(_, data)
  for _, line in ipairs(ensure_list(data) or {}) do
    self:_handle_stdout_line(line)
  end
end

function Client:_on_stderr(_, data)
  if not self.opts.on_stderr then
    return
  end
  for _, line in ipairs(ensure_list(data) or {}) do
    if line and line ~= "" then
      pcall(self.opts.on_stderr, line)
    end
  end
end

function Client:_on_exit(_, code, _)
  self.job_id = nil
  for id, cb in pairs(self.pending) do
    self.pending[id] = nil
    pcall(cb, {
      type = "response",
      id = id,
      success = false,
      error = string.format("pi exited with code %s", tostring(code)),
    })
  end
  if self.opts.on_exit then
    pcall(self.opts.on_exit, code)
  end
end

function Client:start()
  if self:is_running() then
    return true
  end

  local cmd = { self.opts.pi_cmd }
  vim.list_extend(cmd, self.opts.pi_args or {})

  local job_id = vim.fn.jobstart(cmd, {
    cwd = self.opts.cwd,
    stdout_buffered = false,
    stderr_buffered = false,
    on_stdout = function(...)
      self:_on_stdout(...)
    end,
    on_stderr = function(...)
      self:_on_stderr(...)
    end,
    on_exit = function(...)
      self:_on_exit(...)
    end,
  })

  if job_id <= 0 then
    return false, string.format("failed to start pi rpc process: %s", tostring(job_id))
  end

  self.job_id = job_id
  return true
end

function Client:prompt(message, on_response)
  if self.opts.auto_start ~= false then
    local ok, err = self:start()
    if not ok then
      return nil, err
    end
  end

  if not self:is_running() then
    return nil, "pi process is not running"
  end

  self.seq = self.seq + 1
  local id = next_id(self.seq)
  if on_response then
    self.pending[id] = on_response
  end

  local payload = json_encode({ id = id, type = "prompt", message = message }) .. "\n"
  if vim.fn.chansend(self.job_id, payload) < 0 then
    self.pending[id] = nil
    return nil, "failed to send prompt to pi"
  end

  return id
end

return Client
