local M = {}

local function json_decode(value)
  if vim.json and vim.json.decode then
    return vim.json.decode(value)
  end
  return vim.fn.json_decode(value)
end

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function fenced_context(lines, start_row)
  local numbered = {}
  for i, line in ipairs(lines) do
    numbered[i] = string.format("%5d | %s", start_row + i, line)
  end
  return table.concat(numbered, "\n")
end

local function parse_response(raw, field_name)
  local text = trim(raw or "")
  if text == "" then
    return nil, "empty response"
  end

  local ok, decoded = pcall(json_decode, text)
  if not ok then
    return nil, string.format("json parse error: %s", decoded)
  end
  if type(decoded) ~= "table" then
    return nil, "response was not a JSON object"
  end
  if type(decoded[field_name]) ~= "string" then
    return nil, string.format("response.%s must be a string", field_name)
  end

  return decoded
end

function M.build_insert_prompt(request, prompt)
  local parts = {
    "You are generating text to insert at a precise cursor position in the user's current buffer.",
    "Return strict JSON only with this exact shape:",
    '{"insert_text":"..."}',
    "Do not include markdown fences.",
    "Do not include explanations.",
    "Do not describe edits.",
    "Generate only the text that should be inserted at the cursor position.",
    "Do not modify any other location.",
    "",
    "User request:",
    prompt,
    "",
    "Buffer metadata:",
    string.format("- filetype: %s", request.filetype ~= "" and request.filetype or "unknown"),
    string.format("- path: %s", request.path or "[No Name]"),
    string.format("- cursor_line: %d", request.row + 1),
    string.format("- cursor_col: %d", request.col),
    "",
    "Current line split at cursor:",
    string.format("- before_cursor: %q", request.before_cursor),
    string.format("- after_cursor: %q", request.after_cursor),
    "",
    "Surrounding context:",
    fenced_context(request.context_lines, request.context_start_row),
  }

  return table.concat(parts, "\n")
end

function M.build_replace_prompt(request, prompt)
  local parts = {
    "You are rewriting a selected range in the user's current buffer.",
    "Return strict JSON only with this exact shape:",
    '{"replacement_text":"..."}',
    "Do not include markdown fences.",
    "Do not include explanations.",
    "Do not describe edits.",
    "Only the selected range will be replaced.",
    "Text before and after the selection is immutable context.",
    "You cannot modify text outside the selected range.",
    "Even if the user asks for broader changes, return only text that should replace the selected range.",
    "Do not include unchanged surrounding context unless it is inside the selected range.",
    "",
    "User request:",
    prompt,
    "",
    "Buffer metadata:",
    string.format("- filetype: %s", request.filetype ~= "" and request.filetype or "unknown"),
    string.format("- path: %s", request.path or "[No Name]"),
    string.format("- selection_start_line: %d", request.start_row + 1),
    string.format("- selection_start_col: %d", request.start_col),
    string.format("- selection_end_line: %d", request.end_row + 1),
    string.format("- selection_end_col: %d", request.end_col),
    "",
    "Selected text:",
    request.selected_text,
    "",
    "Text immediately before selection on the start line:",
    request.before_selection,
    "",
    "Text immediately after selection on the end line:",
    request.after_selection,
    "",
    "Surrounding immutable context:",
    fenced_context(request.context_lines, request.context_start_row),
  }

  return table.concat(parts, "\n")
end

function M.build_repair_prompt(raw_output, error_message, response_shape)
  response_shape = response_shape or '{"insert_text":"..."}'
  return table.concat({
    "Your previous response was invalid for this operation.",
    "Return strict JSON only with this exact shape:",
    response_shape,
    "Do not include markdown fences.",
    "Do not include explanations.",
    "",
    "Validation error:",
    error_message,
    "",
    "Previous output:",
    raw_output,
    "",
    "Return corrected JSON only.",
  }, "\n")
end

function M.parse_insert_response(raw)
  return parse_response(raw, "insert_text")
end

function M.parse_replace_response(raw)
  return parse_response(raw, "replacement_text")
end

return M
