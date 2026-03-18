local aliases = require("taxi.aliases")
local balance = require("taxi.balance")
local status = require("taxi.status")
local config = require("taxi.config")
local format = require("taxi.format")

local M = {}

local commands_registered = false

local function has_completeopt(value)
  local options = vim.opt_local.completeopt:get()
  for _, option in ipairs(options) do
    if option == value then
      return true
    end
  end
  return false
end

---Trigger omni completion on first column insert.
function M.insert_enter()
  if not config.should_use_omnifunc() then
    return
  end

  if vim.fn.col(".") == 1 then
    local keys = vim.api.nvim_replace_termcodes("<c-x><c-o>", true, false, true)
    vim.api.nvim_feedkeys(keys, "n", false)
  end
end

---Register user commands once.
function M.setup_commands()
  if commands_registered then
    return
  end
  commands_registered = true

  vim.api.nvim_create_user_command("TaxiUpdate", function()
    aliases.update_now()
  end, {})

  vim.api.nvim_create_user_command("TaxiBalance", function()
    balance.show_balance()
  end, {})

  vim.api.nvim_create_user_command("TaxiStatus", function()
    status.show_status()
  end, {})
end

---Configure buffer-local settings and autocmds for taxi files.
function M.setup_buffer()
  M.setup_commands()
  if config.should_use_omnifunc() then
    vim.bo.omnifunc = "v:lua.require'taxi'.complete"
    if not has_completeopt("longest") then
      vim.opt_local.completeopt:append("longest")
    end
  end

  local buf = vim.api.nvim_get_current_buf()
  local group = vim.api.nvim_create_augroup("TaxiBuffer" .. buf, { clear = true })

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    buffer = buf,
    callback = format.format_file,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    buffer = buf,
    callback = balance.show_balance,
  })

  vim.api.nvim_create_autocmd("QuitPre", {
    group = group,
    buffer = buf,
    callback = balance.balance_close,
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    buffer = buf,
    callback = M.insert_enter,
  })

  aliases.assemble_aliases()
end

return M
