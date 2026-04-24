local context = require("nine.context")
local format = require("nine.format")
local insert = require("nine.insert")
local replace = require("nine.replace")
local prompt = require("nine.ui.prompt")
local spinner = require("nine.ui.spinner")

local M = {}

local state = {
  active = false,
  run = nil,
}

local function finish_with_error(message)
  spinner.stop()
  state.active = false
  state.run = nil
  vim.notify(message, vim.log.levels.ERROR, { title = "nine" })
end

local function finish_success(message)
  spinner.stop()
  state.active = false
  state.run = nil
  if message then
    vim.notify(message, vim.log.levels.INFO, { title = "nine" })
  end
end

local function handle_agent_event(event)
  local run = state.run
  if not run then
    return
  end

  if event.type == "message_start" and event.message and event.message.role == "assistant" then
    run.current_message_chunks = {}
    return
  end

  if event.type == "message_update"
    and event.message
    and event.message.role == "assistant"
    and event.assistantMessageEvent
    and event.assistantMessageEvent.type == "text_delta" then
    run.current_message_chunks = run.current_message_chunks or {}
    table.insert(run.current_message_chunks, event.assistantMessageEvent.delta)
    return
  end

  if event.type == "message_end" and event.message and event.message.role == "assistant" then
    local text = table.concat(run.current_message_chunks or {})
    if text ~= "" then
      run.last_message_text = text
    end
    run.current_message_chunks = nil
    return
  end

  if event.type == "agent_end" and run.waiting_for_agent_end then
    run.waiting_for_agent_end = false
    if run.on_attempt_done then
      local cb = run.on_attempt_done
      run.on_attempt_done = nil
      cb(run.last_message_text or "")
    end
  end
end

local function cleanup_subscription()
  local run = state.run
  if run and run.unsubscribe then
    run.unsubscribe()
    run.unsubscribe = nil
  end
end

local function complete_failure(message)
  cleanup_subscription()
  finish_with_error(message)
end

local function complete_success(message)
  cleanup_subscription()
  finish_success(message)
end

local function send_attempt(client, text, callback)
  local run = state.run
  run.current_message_chunks = nil
  run.last_message_text = nil
  run.waiting_for_agent_end = true
  run.on_attempt_done = callback

  local id, err = client:prompt(text, function(resp)
    if not resp.success then
      run.waiting_for_agent_end = false
      run.on_attempt_done = nil
      complete_failure(resp.error or "pi prompt failed")
    end
  end)

  if not id then
    run.waiting_for_agent_end = false
    run.on_attempt_done = nil
    complete_failure(err or "failed to send prompt to pi")
  end
end

local function build_attempt_prompt(run, user_prompt, attempt)
  local is_replace = run.request.kind == "replace"
  if attempt == 1 then
    spinner.update("nine thinking")
    if is_replace then
      return format.build_replace_prompt(run.request, user_prompt)
    end
    return format.build_insert_prompt(run.request, user_prompt)
  end

  spinner.update(string.format("nine repairing output (%d/3)", attempt))
  local shape = is_replace and '{"replacement_text":"..."}' or '{"insert_text":"..."}'
  return format.build_repair_prompt(run.last_raw or "", run.last_error or "unknown error", shape)
end

local function parse_response(run, raw)
  if run.request.kind == "replace" then
    return format.parse_replace_response(raw)
  end
  return format.parse_insert_response(raw)
end

local function discard_request(request)
  if not request then
    return
  end
  if request.kind == "replace" then
    replace.discard(request)
  else
    insert.discard(request)
  end
end

local function apply_response(run, decoded)
  local ok, err
  if run.request.kind == "replace" then
    ok, err = replace.apply(run.request, decoded.replacement_text)
    return ok, err or "Replaced with nine"
  end
  ok, err = insert.apply(run.request, decoded.insert_text)
  return ok, err or "Inserted with nine"
end

local function process_attempt(client, user_prompt, attempt)
  local run = state.run
  if not run then
    return
  end

  local prompt_text = build_attempt_prompt(run, user_prompt, attempt)

  send_attempt(client, prompt_text, function(raw)
    run.last_raw = raw
    local decoded, parse_err = parse_response(run, raw)
    if decoded then
      local ok, message_or_err = apply_response(run, decoded)
      if not ok then
        complete_failure(message_or_err)
        return
      end
      complete_success(message_or_err)
      return
    end

    run.last_error = parse_err
    if attempt < 3 then
      process_attempt(client, user_prompt, attempt + 1)
      return
    end

    complete_failure(parse_err)
  end)
end

function M.run(client, opts)
  if state.active then
    vim.notify("nine is already running", vim.log.levels.WARN, { title = "nine" })
    return
  end

  local prepared_request = nil
  if opts and opts.range and opts.range > 0 then
    local request, err = context.capture_selection(opts)
    if not request then
      vim.notify(err or "failed to capture visual selection", vim.log.levels.ERROR, { title = "nine" })
      return
    end
    prepared_request = request
  else
    prepared_request = context.capture()
  end

  state.active = true
  prompt.open({
    on_cancel = function()
      prompt.close()
      discard_request(prepared_request)
      state.active = false
      state.run = nil
    end,
    on_submit = function(text)
      if not text or text:match("^%s*$") then
        discard_request(prepared_request)
        state.active = false
        vim.notify("nine prompt was empty", vim.log.levels.WARN, { title = "nine" })
        return
      end

      local request = prepared_request
      state.run = {
        request = request,
        current_message_chunks = nil,
        last_message_text = nil,
        waiting_for_agent_end = false,
        on_attempt_done = nil,
        last_raw = nil,
        last_error = nil,
      }
      state.run.unsubscribe = client:subscribe(handle_agent_event)

      spinner.start("nine thinking")
      process_attempt(client, text, 1)
    end,
  })
end

return M
