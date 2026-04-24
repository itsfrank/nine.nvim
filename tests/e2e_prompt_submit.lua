local fw = require("tests.framework")
local t = require("tests.test_utils")

fw.test("submitting prompt from insert mode does not replay Ctrl-D into original buffer", function()
  local bufnr = t.set_buffer({ "hello world" }, { 1, 5 })
  local submitted = nil

  vim.cmd("startinsert")
  require("nine.ui.prompt").open({
    on_submit = function(text)
      submitted = text
    end,
  })

  t.wait_until(function()
    return vim.bo.buftype == "nofile"
  end, 1000, "prompt window did not open")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "Insert some text", "" })
  vim.api.nvim_win_set_cursor(0, { 2, 0 })

  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes("i<C-d>", true, false, true),
    "xt",
    false
  )

  t.wait_until(function()
    return submitted ~= nil
  end, 1000, "prompt was not submitted")

  fw.eq(submitted, "Insert some text\n", "prompt text should include the trailing blank line")
  fw.eq(table.concat(t.current_lines(bufnr), "\n"), "hello world", "Ctrl-D should not modify the original buffer")
  fw.eq(vim.api.nvim_win_get_cursor(0), { 1, 5 }, "original cursor should be preserved")
end)
