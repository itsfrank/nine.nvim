vim.opt.runtimepath:append(vim.fn.getcwd())
require("plugin/nine")

local t = require("tests.test_utils")
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

t.wait_until(function()
  return table.concat(t.current_lines(bufnr), "\n") == "aHELLObc"
end, 4000, "expected insertion to be applied")

local cursor = vim.api.nvim_win_get_cursor(0)
assert(cursor[1] == 1 and cursor[2] == 6, "cursor did not move to end of inserted text")

vim.cmd("undo")
assert(table.concat(t.current_lines(bufnr), "\n") == "abc", "expected one undo to revert insertion")

local lines = t.read_lines(log)
assert(#lines == 1, "expected one prompt attempt")

vim.cmd("qa!")
