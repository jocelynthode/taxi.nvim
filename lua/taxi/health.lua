local config = require("taxi.config")

local M = {}

---@param path string
---@return string|nil
local function first_existing_parent(path)
  local current = vim.fn.fnamemodify(path, ":p")
  for _ = 1, 10 do
    if vim.fn.isdirectory(current) == 1 then
      return current
    end
    local parent = vim.fn.fnamemodify(current, ":h")
    if parent == current then
      break
    end
    current = parent
  end
  return nil
end

---@param cache_path string
---@return boolean, string
local function is_cache_writable(cache_path)
  if vim.fn.filereadable(cache_path) == 1 then
    if vim.fn.filewritable(cache_path) == 1 then
      return true, "cache file is writable"
    end
    return false, "cache file exists but is not writable"
  end

  local directory = vim.fn.fnamemodify(cache_path, ":p:h")
  if vim.fn.isdirectory(directory) == 1 then
    if vim.fn.filewritable(directory) == 2 then
      return true, "cache directory is writable"
    end
    return false, "cache directory is not writable"
  end

  local parent = first_existing_parent(directory)
  if not parent then
    return false, "could not find an existing parent directory"
  end

  if vim.fn.filewritable(parent) == 2 then
    return true, "cache directory does not exist yet, but parent is writable"
  end

  return false, "cache directory missing and parent is not writable"
end

function M.check()
  vim.health.start("taxi.nvim")

  local has_nvim_10 = vim.fn.has("nvim-0.10") == 1
  if has_nvim_10 then
    vim.health.ok("Neovim version is supported (0.10+)")
  else
    vim.health.error("Neovim 0.10+ is required")
  end

  if vim.fn.executable("taxi") == 1 then
    vim.health.ok("taxi executable found in PATH")
  else
    vim.health.error("taxi executable not found in PATH")
  end

  local cache_path = config.get_cache_path()
  local writable, message = is_cache_writable(cache_path)
  if writable then
    vim.health.ok(string.format("cache path: %s (%s)", cache_path, message))
  else
    vim.health.warn(string.format("cache path: %s (%s)", cache_path, message))
  end

  local cfg = config.get()
  vim.health.info(string.format("balance.mode=%s", cfg.balance.mode))
  vim.health.info(string.format("commands.timeout_ms=%d", cfg.commands.timeout_ms))
  vim.health.info(string.format("completion.omnifunc=%s", tostring(cfg.completion.omnifunc)))
end

return M
