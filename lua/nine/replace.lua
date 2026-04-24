local M = {}

local function split_lines(text)
  return vim.split(text, "\n", { plain = true, trimempty = false })
end

local function resolve_range(request)
  local bufnr = request.bufnr
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil, nil, nil, nil, "target buffer is no longer valid"
  end

  local start_row = request.start_row
  local start_col = request.start_col
  local end_row = request.end_row
  local end_col = request.end_col

  if request.mark_namespace and request.start_mark_id and request.end_mark_id then
    local start_mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, request.mark_namespace, request.start_mark_id, {})
    local end_mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, request.mark_namespace, request.end_mark_id, {})
    if start_mark and #start_mark >= 2 and end_mark and #end_mark >= 2 then
      start_row = start_mark[1]
      start_col = start_mark[2]
      end_row = end_mark[1]
      end_col = end_mark[2]
    else
      return nil, nil, nil, nil, "original selection is no longer valid"
    end
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if start_row < 0 or start_row >= line_count or end_row < 0 or end_row >= line_count then
    return nil, nil, nil, nil, "original selection lines are no longer valid"
  end
  if end_row < start_row or (end_row == start_row and end_col < start_col) then
    return nil, nil, nil, nil, "original selection range is no longer valid"
  end

  local start_line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ""
  local end_line = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] or ""
  if start_col < 0 or start_col > #start_line or end_col < 0 or end_col > #end_line then
    return nil, nil, nil, nil, "original selection columns are no longer valid"
  end

  return start_row, start_col, end_row, end_col
end

local function cleanup_marks(request)
  if request.mark_namespace and vim.api.nvim_buf_is_valid(request.bufnr) then
    if request.start_mark_id then
      pcall(vim.api.nvim_buf_del_extmark, request.bufnr, request.mark_namespace, request.start_mark_id)
    end
    if request.end_mark_id then
      pcall(vim.api.nvim_buf_del_extmark, request.bufnr, request.mark_namespace, request.end_mark_id)
    end
  end
end

function M.apply(request, replacement_text)
  local start_row, start_col, end_row, end_col, err = resolve_range(request)
  if not start_row then
    return false, err
  end

  vim.api.nvim_buf_set_text(request.bufnr, start_row, start_col, end_row, end_col, split_lines(replacement_text))
  cleanup_marks(request)

  return true
end

function M.discard(request)
  cleanup_marks(request)
end

return M
