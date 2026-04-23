local M = {}

local function termcodes(value)
  return vim.api.nvim_replace_termcodes(value, true, false, true)
end

function M.project_root()
  return vim.fn.getcwd()
end

function M.fake_pi_script()
  return M.project_root() .. "/tests/fake-pi.js"
end

function M.log_file(name)
  return M.project_root() .. "/tests/" .. name .. ".log"
end

function M.reset_log(path)
  vim.fn.delete(path)
end

function M.read_file(path)
  if vim.fn.filereadable(path) == 0 then
    return ""
  end
  return table.concat(vim.fn.readfile(path), "\n")
end

function M.read_lines(path)
  if vim.fn.filereadable(path) == 0 then
    return {}
  end
  return vim.fn.readfile(path)
end

function M.wait_until(predicate, timeout, message)
  local ok = vim.wait(timeout or 3000, predicate, 20)
  assert(ok, message or "timed out waiting for condition")
end

function M.setup_nine(opts)
  package.loaded["nine"] = nil
  require("nine").setup(opts)
end

function M.open_nine()
  vim.cmd("Nine")
  M.wait_until(function()
    return vim.bo.buftype == "nofile"
  end, 1000, "prompt window did not open")
end

function M.submit_prompt(text)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(text, "\n", { plain = true, trimempty = false }))
  vim.api.nvim_feedkeys(termcodes("<C-d>"), "xt", false)
end

function M.current_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)
end

function M.set_buffer(lines, cursor)
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  if cursor then
    vim.api.nvim_win_set_cursor(0, cursor)
  end
  return bufnr
end

return M
