local Client = require("nine.client")
local flow = require("nine.flow")

local M = {}

local state = {
  client = nil,
}

local defaults = {
  pi_cmd = "pi",
  pi_args = { "--mode", "rpc", "--no-session", "--tools", "read,grep,find,ls" },
  cwd = nil,
  auto_start = true,
  on_event = nil,
  on_stderr = nil,
  on_exit = nil,
}

local function get_client()
  if not state.client then
    state.client = Client.new(defaults)
  end
  return state.client
end

function M.setup(opts)
  defaults = vim.tbl_deep_extend("force", {}, defaults, opts or {})
  if state.client then
    state.client:configure(defaults)
  end
  return M
end

function M.open(opts)
  flow.run(get_client(), opts or {})
end

return M
