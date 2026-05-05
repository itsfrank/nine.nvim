local M = {}

function M.new(opts)
  local agent = (opts or {}).agent or "pi"
  if agent == "opencode" then
    return require("nine.client.opencode").new(opts)
  end
  return require("nine.client.pi").new(opts)
end

return M
