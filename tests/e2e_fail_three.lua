local fw = require("tests.framework")
local t = require("tests.test_utils")

fw.test("reports error after three bad attempts", function()
  local log = t.log_file("fail_three")

  t.reset_log(log)
  vim.env.NINE_FAKE_PI_SCENARIO = "fail-three"
  vim.env.NINE_FAKE_PI_LOG = log

  local notifications, restore_notifications = fw.capture_notifications()

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

  restore_notifications()

  fw.eq(table.concat(t.current_lines(bufnr), "\n"), "abc", "buffer should remain unchanged after hard failure")
end)
