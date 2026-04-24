local fw = require("tests.framework")
local t = require("tests.test_utils")

fw.test("replaces a characterwise visual selection", function()
  local log = t.log_file("visual_replace")

  t.reset_log(log)
  vim.env.NINE_FAKE_PI_SCENARIO = "visual-success"
  vim.env.NINE_FAKE_PI_LOG = log

  t.setup_nine({
    pi_cmd = "node",
    pi_args = { t.fake_pi_script() },
  })

  local bufnr = t.set_buffer({ "hello world" }, { 1, 0 })
  t.open_nine_range({ 1, 7 }, { 1, 11 })
  t.submit_prompt("rewrite selected text")

  t.wait_until(function()
    return table.concat(t.current_lines(bufnr), "\n") == "hello nine"
  end, 4000, "expected replacement to be applied")

  vim.cmd("silent undo")
  fw.eq(table.concat(t.current_lines(bufnr), "\n"), "hello world", "one undo should revert replacement")

  local lines = t.read_lines(log)
  fw.eq(#lines, 1, "should make one prompt attempt")
  fw.matches(lines[1], "Only the selected range will be replaced", "prompt should explain selection-only mutation")
  fw.matches(lines[1], "You cannot modify text outside the selected range", "prompt should explain immutable context")
end)
