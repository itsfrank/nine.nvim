vim.opt.runtimepath:append(vim.fn.getcwd())
require("plugin/nine")

local fw = require("tests.framework")

local test_files = {
  "e2e_success",
  "e2e_retry",
  "e2e_fail_three",
  "e2e_cursor_shift",
  "e2e_cursor_position",
  "e2e_visual_replace",
  "e2e_visual_linewise",
  "e2e_visual_cursor_shift",
  "e2e_visual_retry",
  "e2e_prompt_submit",
}

for _, file in ipairs(test_files) do
  fw.set_current_file(file)
  require("tests." .. file)
end

fw.run()
