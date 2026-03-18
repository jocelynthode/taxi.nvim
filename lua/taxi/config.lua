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

local known_top_level_keys = {
  aliases = true,
  balance = true,
  cache = true,
  commands = true,
  completion = true,
}

local known_balance_keys = {
  enabled = true,
  cmd = true,
  mode = true,
}

local known_cache_keys = {
  path = true,
}

local known_aliases_keys = {
  auto_update = true,
  update_debounce_ms = true,
  notify_on_update = true,
}

local known_commands_keys = {
  timeout_ms = true,
}

local known_completion_keys = {
  omnifunc = true,
}

---@param tbl table
---@param known_keys table<string, boolean>
---@param section string
local function validate_known_keys(tbl, known_keys, section)
  for key, _ in pairs(tbl) do
    if not known_keys[key] then
      error(string.format("taxi.nvim: invalid option '%s.%s'", section, key))
    end
  end
end

---@param value any
---@return "auto"|boolean
local function normalize_omnifunc(value)
  if value == nil then
    return "auto"
  end

  if value == true or value == false or value == "auto" then
    return value
  end

  if type(value) == "string" then
    local normalized = value:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if normalized == "auto" then
      return "auto"
    end
    if normalized == "true" then
      return true
    end
    if normalized == "false" then
      return false
    end
  end

  error("taxi.nvim: completion.omnifunc must be one of: 'auto', true, false")
end

---@param opts table|nil
---@return table
local function validate_and_normalize(opts)
  vim.validate({
    opts = { opts, "table", true },
  })

  opts = vim.deepcopy(opts or {})
  validate_known_keys(opts, known_top_level_keys, "setup")

  vim.validate({
    balance = { opts.balance, "table", true },
    cache = { opts.cache, "table", true },
    aliases = { opts.aliases, "table", true },
    commands = { opts.commands, "table", true },
    completion = { opts.completion, "table", true },
  })

  if opts.balance then
    validate_known_keys(opts.balance, known_balance_keys, "balance")
    vim.validate({
      enabled = { opts.balance.enabled, "boolean", true },
      cmd = { opts.balance.cmd, { "table", "string" }, true },
      mode = { opts.balance.mode, "string", true },
    })

    if opts.balance.mode ~= nil and opts.balance.mode ~= "notify" and opts.balance.mode ~= "scratch" then
      error("taxi.nvim: balance.mode must be 'notify' or 'scratch'")
    end
  end

  if opts.cache then
    validate_known_keys(opts.cache, known_cache_keys, "cache")
    vim.validate({
      path = { opts.cache.path, "string", true },
    })
  end

  if opts.aliases then
    validate_known_keys(opts.aliases, known_aliases_keys, "aliases")
    vim.validate({
      auto_update = { opts.aliases.auto_update, "boolean", true },
      update_debounce_ms = { opts.aliases.update_debounce_ms, "number", true },
      notify_on_update = { opts.aliases.notify_on_update, "boolean", true },
    })

    if opts.aliases.update_debounce_ms ~= nil and opts.aliases.update_debounce_ms < 0 then
      error("taxi.nvim: aliases.update_debounce_ms must be >= 0")
    end
  end

  if opts.commands then
    validate_known_keys(opts.commands, known_commands_keys, "commands")
    vim.validate({
      timeout_ms = { opts.commands.timeout_ms, "number", true },
    })

    if opts.commands.timeout_ms ~= nil and opts.commands.timeout_ms < 0 then
      error("taxi.nvim: commands.timeout_ms must be >= 0")
    end
  end

  if opts.completion then
    validate_known_keys(opts.completion, known_completion_keys, "completion")
    opts.completion.omnifunc = normalize_omnifunc(opts.completion.omnifunc)
  end

  return opts
end

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
  local normalized = validate_and_normalize(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), normalized)
end

return M
