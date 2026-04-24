local fw = require("tests.framework")
local t = require("tests.test_utils")

fw.test("tracks original cursor after edits above", function()
  local log = t.log_file("cursor_shift")

  t.reset_log(log)
  vim.env.NINE_FAKE_PI_SCENARIO = "delayed-success"
  vim.env.NINE_FAKE_PI_LOG = log

  t.setup_nine({
    pi_cmd = "node",
    pi_args = { t.fake_pi_script() },
  })

  local bufnr = t.set_buffer({ "before", "target", "after" }, { 2, 3 })
  t.open_nine()
  t.submit_prompt("insert something here")

  vim.defer_fn(function()
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { "inserted above" })
  end, 50)

  t.wait_until(function()
    return table.concat(t.current_lines(bufnr), "\n"):match("HELLO") ~= nil
  end, 4000, "expected insertion to be applied")

  local actual = table.concat(t.current_lines(bufnr), "\n")
  local expected = table.concat({
    "inserted above",
    "before",
    "tarHELLOget",
    "after",
  }, "\n")

  fw.eq(actual, expected, "insertion should track original cursor after edits above")
end)
