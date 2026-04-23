local M = {}

local state = {
  buf = nil,
  win = nil,
}

local function close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  state.buf = nil
  state.win = nil
end

local function dimensions()
  local current_width = vim.api.nvim_win_get_width(0)
  local width = math.min(80, current_width)
  width = math.min(width, math.max(20, vim.o.columns - 4))
  width = math.max(20, width)
  local height = 5
  return width, height
end

function M.open(opts)
  opts = opts or {}
  close()

  local width, height = dimensions()
  local row = math.floor((vim.o.lines - height) / 2) - 1
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

  local win_opts = {
    relative = "editor",
    style = "minimal",
    border = "rounded",
    width = width,
    height = height,
    row = math.max(0, row),
    col = math.max(0, col),
    title = " nine ",
    title_pos = "center",
    footer = " Ctrl-D submit · Esc cancel ",
    footer_pos = "center",
  }

  local ok, win = pcall(vim.api.nvim_open_win, buf, true, win_opts)
  if not ok then
    win_opts.title = nil
    win_opts.title_pos = nil
    win_opts.footer = nil
    win_opts.footer_pos = nil
    win = vim.api.nvim_open_win(buf, true, win_opts)
  end

  state.buf = buf
  state.win = win

  local function submit()
    if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
      return
    end
    local lines = vim.api.nvim_buf_get_lines(state.buf, 0, -1, false)
    local text = table.concat(lines, "\n")
    close()
    if opts.on_submit then
      opts.on_submit(text)
    end
  end

  local function cancel()
    close()
    if opts.on_cancel then
      opts.on_cancel()
    end
  end

  vim.keymap.set({ "i", "n" }, "<C-d>", submit, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", cancel, { buffer = buf, nowait = true, silent = true })

  vim.schedule(function()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_set_current_win(state.win)
      vim.cmd("startinsert")
    end
  end)
end

function M.close()
  close()
end

return M
