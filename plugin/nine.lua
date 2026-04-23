if vim.g.loaded_nine then
  return
end
vim.g.loaded_nine = true

vim.api.nvim_create_user_command("Nine", function()
  require("nine").open()
end, {})
