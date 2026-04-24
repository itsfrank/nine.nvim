local M = {}

local cursor_namespace = vim.api.nvim_create_namespace("nine_cursor")
local selection_namespace = vim.api.nvim_create_namespace("nine_selection")

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

local function context_range(bufnr, start_row, end_row)
  local context_start_row = math.max(0, start_row - 20)
  local context_end_row = math.min(vim.api.nvim_buf_line_count(bufnr), end_row + 21)
  return context_start_row, vim.api.nvim_buf_get_lines(bufnr, context_start_row, context_end_row, false)
end

local function split_text_range(bufnr, start_row, start_col, end_row, end_col)
  local lines = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
  return table.concat(lines, "\n")
end

local function line_length(bufnr, row)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  return #line
end

local function visual_mode()
  local mode = vim.fn.visualmode()
  if mode == "" then
    mode = vim.fn.mode()
  end
  return mode
end

function M.capture()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1] - 1
  local col = cursor[2]
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  local before_cursor, after_cursor = line_prefix_suffix(line, col)
  local context_start, context_lines = context_range(bufnr, row, row)

  local mark_id = vim.api.nvim_buf_set_extmark(bufnr, cursor_namespace, row, col, {
    right_gravity = true,
  })

  return {
    kind = "insert",
    bufnr = bufnr,
    row = row,
    col = col,
    mark_namespace = cursor_namespace,
    mark_id = mark_id,
    filetype = vim.bo[bufnr].filetype,
    path = relative_path(bufnr),
    before_cursor = before_cursor,
    after_cursor = after_cursor,
    context_start_row = context_start,
    context_lines = context_lines,
  }
end

function M.capture_selection(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local mode = visual_mode()

  if mode == "\22" then
    return nil, "blockwise visual selection is not supported yet"
  end

  local start_row = math.max(0, (opts.line1 or vim.fn.line("'<")) - 1)
  local end_row = math.max(0, (opts.line2 or vim.fn.line("'>")) - 1)
  local start_col
  local end_col

  if mode == "V" then
    start_col = 0
    end_col = line_length(bufnr, end_row)
  else
    start_col = vim.fn.col("'<") - 1
    end_col = vim.fn.col("'>")
  end

  if end_row < start_row or (end_row == start_row and end_col < start_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  if start_row < 0 or start_row >= line_count or end_row < 0 or end_row >= line_count then
    return nil, "visual selection is no longer valid"
  end

  start_col = math.max(0, math.min(start_col, line_length(bufnr, start_row)))
  end_col = math.max(0, math.min(end_col, line_length(bufnr, end_row)))

  local selected_text = split_text_range(bufnr, start_row, start_col, end_row, end_col)
  local start_line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1] or ""
  local end_line = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] or ""
  local before_selection = start_line:sub(1, start_col)
  local after_selection = end_line:sub(end_col + 1)
  local context_start, context_lines = context_range(bufnr, start_row, end_row)

  local start_mark_id = vim.api.nvim_buf_set_extmark(bufnr, selection_namespace, start_row, start_col, {
    right_gravity = false,
  })
  local end_mark_id = vim.api.nvim_buf_set_extmark(bufnr, selection_namespace, end_row, end_col, {
    right_gravity = true,
  })

  return {
    kind = "replace",
    bufnr = bufnr,
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
    mark_namespace = selection_namespace,
    start_mark_id = start_mark_id,
    end_mark_id = end_mark_id,
    filetype = vim.bo[bufnr].filetype,
    path = relative_path(bufnr),
    selected_text = selected_text,
    before_selection = before_selection,
    after_selection = after_selection,
    context_start_row = context_start,
    context_lines = context_lines,
  }
end

return M
