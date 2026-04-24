local fw = require("tests.framework")
local t = require("tests.test_utils")

fw.test("retries malformed replacement output", function()
  local log = t.log_file("visual_retry")

  t.reset_log(log)
  vim.env.NINE_FAKE_PI_SCENARIO = "visual-retry-once"
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
  end, 4000, "expected replacement to be applied after retry")

  local lines = t.read_lines(log)
  fw.eq(#lines, 2, "should make two prompt attempts")
  fw.matches(lines[2], 'replacement_text', "repair prompt should request replacement response shape")
end)
