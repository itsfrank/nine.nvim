local M = {}

local cursor_namespace = vim.api.nvim_create_namespace("nine_cursor")

local function relative_path(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return nil
  end
  return vim.fn.fnamemodify(name, ":.")
end

local function line_prefix_suffix(line, col)
  local prefix = line:sub(1, col)
  local suffix = line:sub(col + 1)
  return prefix, suffix
end

function M.capture()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  local before_cursor, after_cursor = line_prefix_suffix(line, col)
  local start_row = math.max(0, row - 20)
  local end_row = math.min(vim.api.nvim_buf_line_count(bufnr), row + 21)
  local context_lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)

  local mark_id = vim.api.nvim_buf_set_extmark(bufnr, cursor_namespace, row, col, {
    right_gravity = true,
  })

  return {
    bufnr = bufnr,
    row = row,
    col = col,
    mark_namespace = cursor_namespace,
    mark_id = mark_id,
    filetype = vim.bo[bufnr].filetype,
    path = relative_path(bufnr),
    before_cursor = before_cursor,
    after_cursor = after_cursor,
    context_start_row = start_row,
    context_lines = context_lines,
  }
end

return M
