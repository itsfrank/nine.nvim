local M = {}

local tests = {}
local current_file = nil

local colors = {
  reset = "\27[0m",
  bold = "\27[1m",
  dim = "\27[2m",
  red = "\27[31m",
  green = "\27[32m",
  yellow = "\27[33m",
  cyan = "\27[36m",
}

local function color(name, text)
  if vim.env.NO_COLOR then
    return text
  end
  return (colors[name] or "") .. text .. colors.reset
end

local function stdout(line)
  io.stdout:write(line .. "\n")
end

local function to_string(value)
  if type(value) == "string" then
    return value
  end
  return vim.inspect(value)
end

local function ensure_trailing_newline(value)
  if value == "" or value:sub(-1) == "\n" then
    return value
  end
  return value .. "\n"
end

local function make_diff(expected, received)
  if type(expected) ~= "string" or type(received) ~= "string" then
    return nil
  end

  local ok, diff = pcall(vim.text.diff, ensure_trailing_newline(expected), ensure_trailing_newline(received), {
    result_type = "unified",
    ctxlen = 3,
  })

  if not ok or not diff or diff == "" then
    return nil
  end

  return diff
end

local function fail(details)
  details.__nine_failure = true
  error(details, 0)
end

function M.set_current_file(file)
  current_file = file
end

function M.test(name, fn)
  table.insert(tests, {
    file = current_file or "unknown",
    name = name,
    fn = fn,
  })
end

function M.eq(actual, expected, message)
  if vim.deep_equal(actual, expected) then
    return
  end

  fail({
    message = message or "expected values to be equal",
    expected = to_string(expected),
    received = to_string(actual),
    diff = make_diff(to_string(actual), to_string(expected)),
  })
end

function M.truthy(value, message)
  if value then
    return
  end

  fail({
    message = message or "expected value to be truthy",
    expected = "truthy value",
    received = to_string(value),
  })
end

function M.matches(value, pattern, message)
  if type(value) == "string" and value:match(pattern) then
    return
  end

  fail({
    message = message or string.format("expected value to match %q", pattern),
    expected = string.format("match: %s", pattern),
    received = to_string(value),
  })
end

function M.capture_notifications()
  local notifications = {}
  local original_notify = vim.notify

  vim.notify = function(message, level, opts)
    table.insert(notifications, { message = message, level = level, opts = opts })
  end

  return notifications, function()
    vim.notify = original_notify
  end
end

local function silence_notifications(fn)
  local original_notify = vim.notify
  vim.notify = function() end
  local ok, err = xpcall(fn, function(e)
    if type(e) == "table" and e.__nine_failure then
      return e
    end
    return {
      message = tostring(e),
      traceback = debug.traceback("", 2),
    }
  end)
  vim.notify = original_notify
  return ok, err
end

local function reset_editor()
  pcall(vim.cmd, "silent! %bwipeout!")
  vim.cmd("enew")
end

local function test_label(test)
  return string.format("%s - %s", test.file, test.name)
end

local function color_diff(diff)
  local lines = vim.split(diff:gsub("\n$", ""), "\n", { plain = true })
  for i, line in ipairs(lines) do
    if line:match("^@@") then
      lines[i] = color("cyan", line)
    elseif line:sub(1, 1) == "+" and not line:match("^%+%+%+") then
      lines[i] = color("green", line)
    elseif line:sub(1, 1) == "-" and not line:match("^%-%-%-") then
      lines[i] = color("red", line)
    end
  end
  return table.concat(lines, "\n")
end

local function print_failure(index, result)
  stdout("")
  stdout(color("bold", string.format("%d) %s", index, test_label(result.test))))
  stdout("")
  stdout(color("red", result.error.message or "test failed"))

  if result.error.expected ~= nil or result.error.received ~= nil then
    stdout("")
    stdout(color("green", "Expected:"))
    stdout(result.error.expected or "nil")
    stdout("")
    stdout(color("red", "Received:"))
    stdout(result.error.received or "nil")
  end

  if result.error.diff then
    stdout("")
    stdout(color("cyan", "Diff:"))
    stdout(color_diff(result.error.diff))
  end

  if result.error.traceback then
    stdout("")
    stdout(color("yellow", "Traceback:"))
    stdout(result.error.traceback:gsub("^\n", ""))
  end
end

function M.run()
  stdout(color("bold", "nine test suite"))
  stdout("")

  local results = {}
  local passed = 0
  local failed = 0

  for _, test in ipairs(tests) do
    reset_editor()
    local start = vim.uv.hrtime()
    local ok, err = silence_notifications(test.fn)
    local elapsed_ms = math.floor((vim.uv.hrtime() - start) / 1000000 + 0.5)

    local result = {
      test = test,
      ok = ok,
      error = err,
      elapsed_ms = elapsed_ms,
    }
    table.insert(results, result)

    if ok then
      passed = passed + 1
      stdout(string.format("%s %-18s %-48s %s", color("green", "✓"), test.file, test.name, color("dim", string.format("%4dms", elapsed_ms))))
    else
      failed = failed + 1
      stdout(string.format("%s %-18s %-48s %s", color("red", "✗"), test.file, test.name, color("dim", string.format("%4dms", elapsed_ms))))
    end
  end

  if failed > 0 then
    stdout("")
    stdout(color("red", "Failures:"))
    local index = 1
    for _, result in ipairs(results) do
      if not result.ok then
        print_failure(index, result)
        index = index + 1
      end
    end
  end

  stdout("")
  stdout(color("bold", "Summary:"))
  stdout(string.format("  %s", color("green", string.format("%d passed", passed))))
  stdout(string.format("  %s", color(failed > 0 and "red" or "dim", string.format("%d failed", failed))))
  stdout(string.format("  %s", color("dim", string.format("%d total", #tests))))

  if failed > 0 then
    vim.cmd("cquit")
  end
  vim.cmd("qa!")
end

return M
