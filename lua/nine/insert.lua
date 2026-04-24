local M = {}

local function split_lines(text)
  return vim.split(text, "\n", { plain = true, trimempty = false })
end

local function resolve_position(request)
  local bufnr = request.bufnr
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil, nil, "target buffer is no longer valid"
  end

  local row = request.row
  local col = request.col
  if request.mark_namespace and request.mark_id then
    local mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, request.mark_namespace, request.mark_id, {})
    if mark and #mark >= 2 then
      row = mark[1]
      col = mark[2]
    else
      return nil, nil, "original cursor position is no longer valid"
    end
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if row < 0 or row >= line_count then
    return nil, nil, "original cursor line is no longer valid"
  end
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  if col < 0 or col > #line then
    return nil, nil, "original cursor column is no longer valid"
  end
  return row, col
end

local function cleanup_mark(request)
  if request.mark_namespace and request.mark_id and vim.api.nvim_buf_is_valid(request.bufnr) then
    pcall(vim.api.nvim_buf_del_extmark, request.bufnr, request.mark_namespace, request.mark_id)
  end
end

function M.apply(request, insert_text)
  local row, col, err = resolve_position(request)
  if not row then
    return false, err
  end

  local lines = split_lines(insert_text)
  vim.api.nvim_buf_set_text(request.bufnr, row, col, row, col, lines)

  cleanup_mark(request)

  return true
end

function M.discard(request)
  cleanup_mark(request)
end

return M
