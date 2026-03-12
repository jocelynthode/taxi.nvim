local M = {}

local default_config = {
  balance = {
    enabled = true,
    cmd = { "taxi", "zebra", "balance" },
    mode = "notify",
  },
  cache = {
    path = vim.fn.stdpath("data") .. "/taxi/taxi_aliases",
  },
  aliases = {
    auto_update = true,
    update_debounce_ms = 200,
    notify_on_update = true,
  },
  commands = {
    timeout_ms = 10000,
  },
  completion = {
    omnifunc = "auto",
  },
}

local config = vim.deepcopy(default_config)

---Return the current configuration table.
---@return table
function M.get()
  return config
end

---Return the alias cache path from config/defaults.
---@return string
function M.get_cache_path()
  return config.cache.path or default_config.cache.path
end

---Return whether omnifunc should be enabled.
---@return boolean
function M.should_use_omnifunc()
  if config.completion.omnifunc == "auto" then
    return not pcall(require, "blink.cmp") and not pcall(require, "cmp")
  end
  return config.completion.omnifunc == true
end

---Setup plugin configuration.
---@param opts table|nil
function M.setup(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts or {})
end

return M
