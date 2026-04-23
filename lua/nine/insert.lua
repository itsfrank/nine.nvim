local M = {}

local function split_lines(text)
  return vim.split(text, "\n", { plain = true, trimempty = false })
end

local function valid_position(bufnr, row, col)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false, "target buffer is no longer valid"
  end
  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if row < 0 or row >= line_count then
    return false, "original cursor line is no longer valid"
  end
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  if col < 0 or col > #line then
    return false, "original cursor column is no longer valid"
  end
  return true
end

function M.apply(request, insert_text)
  local ok, err = valid_position(request.bufnr, request.row, request.col)
  if not ok then
    return false, err
  end

  local lines = split_lines(insert_text)
  vim.api.nvim_buf_set_text(request.bufnr, request.row, request.col, request.row, request.col, lines)

  local final_row = request.row
  local final_col = request.col
  if #lines == 1 then
    final_col = final_col + #lines[1]
  else
    final_row = final_row + (#lines - 1)
    final_col = #lines[#lines]
  end

  local target_win = vim.fn.bufwinid(request.bufnr)
  if target_win ~= -1 then
    vim.api.nvim_win_set_cursor(target_win, { final_row + 1, final_col })
  end

  return true
end

return M
