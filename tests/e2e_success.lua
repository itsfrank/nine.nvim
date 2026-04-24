local fw = require("tests.framework")
local t = require("tests.test_utils")

fw.test("inserts text and supports single undo", function()
  local log = t.log_file("success")

  t.reset_log(log)
  vim.env.NINE_FAKE_PI_SCENARIO = "success"
  vim.env.NINE_FAKE_PI_LOG = log

  t.setup_nine({
    pi_cmd = "node",
    pi_args = { t.fake_pi_script() },
  })

  local bufnr = t.set_buffer({ "abc" }, { 1, 1 })
  t.open_nine()
  t.submit_prompt("insert something here")
  fw.eq(vim.api.nvim_get_mode().mode, "n", "submitting from the prompt should leave insert mode")

  t.wait_until(function()
    return table.concat(t.current_lines(bufnr), "\n") == "aHELLObc"
  end, 4000, "expected insertion to be applied")

  local cursor = vim.api.nvim_win_get_cursor(0)
  fw.eq(cursor, { 1, 6 }, "cursor should move to end of inserted text")

  vim.cmd("silent undo")
  fw.eq(table.concat(t.current_lines(bufnr), "\n"), "abc", "one undo should revert insertion")

  local lines = t.read_lines(log)
  fw.eq(#lines, 1, "should make one prompt attempt")
end)
