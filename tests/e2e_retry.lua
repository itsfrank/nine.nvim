vim.opt.runtimepath:append(vim.fn.getcwd())
require("plugin/nine")

local t = require("tests.test_utils")
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
assert(#lines == 2, "expected two prompt attempts")
assert(lines[2]:match("invalid for this operation"), "expected repair prompt on second attempt")

vim.cmd("qa!")
