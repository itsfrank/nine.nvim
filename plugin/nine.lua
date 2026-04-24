if vim.g.loaded_nine then
  return
end
vim.g.loaded_nine = true

vim.api.nvim_create_user_command("Nine", function(opts)
  require("nine").open(opts)
end, { range = true })
