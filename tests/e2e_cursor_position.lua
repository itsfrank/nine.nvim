local fw = require("tests.framework")
local t = require("tests.test_utils")

fw.test("does not move cursor after insertion", function()
  local log = t.log_file("cursor_position")

  t.reset_log(log)
  vim.env.NINE_FAKE_PI_SCENARIO = "delayed-success"
  vim.env.NINE_FAKE_PI_LOG = log

  t.setup_nine({
    pi_cmd = "node",
    pi_args = { t.fake_pi_script() },
  })

  local bufnr = t.set_buffer({ "before", "target", "after" }, { 2, 3 })
  local target_win = vim.api.nvim_get_current_win()

  t.open_nine()
  t.submit_prompt("insert something here")

  local user_cursor = { 3, 0 }
  vim.api.nvim_win_set_cursor(target_win, user_cursor)

  t.wait_until(function()
    return table.concat(t.current_lines(bufnr), "\n"):match("HELLO") ~= nil
  end, 4000, "expected insertion to be applied")

  local actual = table.concat(t.current_lines(bufnr), "\n")
  local expected = table.concat({
    "before",
    "tarHELLOget",
    "after",
  }, "\n")

  fw.eq(actual, expected, "insertion should still happen at the original request cursor")
  fw.eq(vim.api.nvim_win_get_cursor(target_win), user_cursor, "nine should not move the user's cursor after insertion")
end)
