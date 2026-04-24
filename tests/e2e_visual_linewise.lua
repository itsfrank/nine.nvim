local fw = require("tests.framework")
local t = require("tests.test_utils")

fw.test("replaces full selected lines", function()
  local log = t.log_file("visual_linewise")

  t.reset_log(log)
  vim.env.NINE_FAKE_PI_SCENARIO = "visual-linewise"
  vim.env.NINE_FAKE_PI_LOG = log

  t.setup_nine({
    pi_cmd = "node",
    pi_args = { t.fake_pi_script() },
  })

  local bufnr = t.set_buffer({ "before", "old one", "old two", "after" }, { 2, 0 })
  t.open_nine_range({ 2, 1 }, { 3, 7 })
  t.submit_prompt("rewrite selected lines")

  t.wait_until(function()
    return table.concat(t.current_lines(bufnr), "\n") == table.concat({ "before", "new one", "new two", "after" }, "\n")
  end, 4000, "expected linewise replacement to be applied")
end)
