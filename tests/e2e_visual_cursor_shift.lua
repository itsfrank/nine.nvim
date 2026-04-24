local fw = require("tests.framework")
local t = require("tests.test_utils")

fw.test("tracks original selection after edits above", function()
  local log = t.log_file("visual_cursor_shift")

  t.reset_log(log)
  vim.env.NINE_FAKE_PI_SCENARIO = "visual-delayed-success"
  vim.env.NINE_FAKE_PI_LOG = log

  t.setup_nine({
    pi_cmd = "node",
    pi_args = { t.fake_pi_script() },
  })

  local bufnr = t.set_buffer({ "before", "hello world", "after" }, { 2, 0 })
  t.open_nine_range({ 2, 7 }, { 2, 11 })
  t.submit_prompt("rewrite selected text")

  vim.defer_fn(function()
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { "inserted above" })
  end, 50)

  t.wait_until(function()
    return table.concat(t.current_lines(bufnr), "\n"):match("hello nine") ~= nil
  end, 4000, "expected replacement to be applied")

  local actual = table.concat(t.current_lines(bufnr), "\n")
  local expected = table.concat({
    "inserted above",
    "before",
    "hello nine",
    "after",
  }, "\n")

  fw.eq(actual, expected, "replacement should track original selection after edits above")
end)
