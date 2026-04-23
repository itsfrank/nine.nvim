local M = {}

local frames = {
  "⠋",
  "⠙",
  "⠹",
  "⠸",
  "⠼",
  "⠴",
  "⠦",
  "⠧",
  "⠇",
  "⠏",
}

local state = {
  timer = nil,
  buf = nil,
  win = nil,
  frame = 1,
  message = "",
}

local function render()
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    return
  end
  local text = string.format("%s %s", frames[state.frame], state.message or "")
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { text })
  state.frame = (state.frame % #frames) + 1
end

local function position(width)
  return {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    width = width,
    height = 1,
    row = 1,
    col = math.max(0, vim.o.columns - width - 2),
  }
end

local function close_window()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  state.win = nil
  state.buf = nil
end

function M.start(message)
  M.stop()
  state.message = message or "nine working"
  state.frame = 1
  local width = math.min(math.max(#state.message + 4, 18), math.max(18, vim.o.columns - 4))
  state.buf = vim.api.nvim_create_buf(false, true)
  state.win = vim.api.nvim_open_win(state.buf, false, position(width))
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = state.buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = state.buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = state.buf })

  local uv = vim.uv or vim.loop
  state.timer = uv.new_timer()
  render()
  state.timer:start(100, 100, vim.schedule_wrap(render))
end

function M.update(message)
  state.message = message or state.message
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    local width = math.min(math.max(#state.message + 4, 18), math.max(18, vim.o.columns - 4))
    vim.api.nvim_win_set_config(state.win, position(width))
    render()
  end
end

function M.stop()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
  close_window()
  state.frame = 1
  state.message = ""
end

return M
