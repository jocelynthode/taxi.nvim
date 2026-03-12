local aliases = require("taxi.aliases")
local balance = require("taxi.balance")
local commands = require("taxi.commands")
local config = require("taxi.config")
local format = require("taxi.format")
local status = require("taxi.status")

local M = {}

---Trigger an alias update immediately.
function M.update_now()
  aliases.update_now()
end

---Omnifunc completion callback for taxi aliases.
---@param findstart integer
---@param base string
---@return integer|table
function M.complete(findstart, base)
  return aliases.complete(findstart, base)
end

---Align columns in the current taxi buffer.
function M.format_file()
  format.format_file()
end

---Show the current taxi balance using notify or scratch mode.
function M.show_balance()
  balance.show_balance()
end

---Show the current taxi status via notification.
---@param opts table|nil
function M.show_status(opts)
  status.show_status(opts)
end

---Setup plugin configuration.
---@param opts table|nil
function M.setup(opts)
  config.setup(opts)
  commands.setup_commands()
end

---Report whether the balance command is running.
---@return boolean
function M.is_balance_inflight()
  return balance.is_balance_inflight()
end

---Report whether alias updates are running.
---@return boolean
function M.is_alias_update_inflight()
  return aliases.is_alias_update_inflight()
end

return M
