local fw = require("tests.framework")
local t = require("tests.test_utils")

fw.test("retries malformed JSON once", function()
  local log = t.log_file("retry")

  t.reset_log(log)
  vim.env.NINE_FAKE_PI_SCENARIO = "retry-once"
  vim.env.NINE_FAKE_PI_LOG = log

  t.setup_nine({
    pi_cmd = "node",
    pi_args = { t.fake_pi_script() },
  })

  local bufnr = t.set_buffer({ "abc" }, { 1, 1 })
  t.open_nine()
  t.submit_prompt("insert something here")

  t.wait_until(function()
    return table.concat(t.current_lines(bufnr), "\n") == "aHELLObc"
  end, 4000, "expected insertion after retry")

  local lines = t.read_lines(log)
  fw.eq(#lines, 2, "should make two prompt attempts")
  fw.matches(lines[2], "invalid for this operation", "second attempt should use repair prompt")
end)
