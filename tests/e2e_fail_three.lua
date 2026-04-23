vim.opt.runtimepath:append(vim.fn.getcwd())
require("plugin/nine")

local t = require("tests.test_utils")
local log = t.log_file("fail_three")

t.reset_log(log)
vim.env.NINE_FAKE_PI_SCENARIO = "fail-three"
vim.env.NINE_FAKE_PI_LOG = log

local notifications = {}
local original_notify = vim.notify
vim.notify = function(message, level, opts)
  table.insert(notifications, { message = message, level = level, opts = opts })
end

t.setup_nine({
  pi_cmd = "node",
  pi_args = { t.fake_pi_script() },
})

local bufnr = t.set_buffer({ "abc" }, { 1, 1 })
t.open_nine()
t.submit_prompt("insert something here")

t.wait_until(function()
  return #t.read_lines(log) == 3
end, 4000, "expected three prompt attempts")

t.wait_until(function()
  for _, item in ipairs(notifications) do
    if item.level == vim.log.levels.ERROR then
      return true
    end
  end
  return false
end, 4000, "expected error notification")

assert(table.concat(t.current_lines(bufnr), "\n") == "abc", "buffer should remain unchanged after hard failure")

vim.notify = original_notify
vim.cmd("qa!")
