local config = require("taxi.config")

local M = {}

local taxi_missing_notified = false

---Format a command for logging.
---@param cmd string|string[]
---@return string
function M.format_cmd(cmd)
  if type(cmd) == "string" then
    return cmd
  end
  return table.concat(cmd, " ")
end

---Normalize a command into a form accepted by vim.system.
---@param cmd string|string[]
---@return string|string[]
function M.resolve_cmd(cmd)
  if type(cmd) == "string" then
    return cmd
  end
  return cmd
end

---Send a taxi-scoped notification.
---@param message string
---@param level? integer
function M.notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "taxi" })
end

---Notify about a taxi command timeout.
---@param cmd string|string[]
function M.notify_timeout(cmd)
  vim.notify("taxi command timed out: " .. M.format_cmd(cmd), vim.log.levels.WARN, { title = "taxi" })
end

---Check for the taxi executable and notify once if missing.
---@return boolean
function M.ensure_taxi_available()
  if vim.fn.executable("taxi") == 1 then
    return true
  end

  if not taxi_missing_notified then
    taxi_missing_notified = true
    vim.notify("taxi executable not found in PATH", vim.log.levels.WARN, { title = "taxi" })
  end

  return false
end

---Run external command with timeout and buffered stdout (Neovim 0.10+).
---@param cmd string|string[]
---@param opts table
---@return table|nil
function M.start_job(cmd, opts)
  if not M.ensure_taxi_available() then
    return nil
  end

  local done = false
  local timed_out = false
  local on_exit = opts.on_exit
  local on_timeout = opts.on_timeout

  local timeout_ms = config.get().commands.timeout_ms or 0

  local handle = vim.system(cmd, { text = true }, function(result)
    if done then
      return
    end
    done = true
    if timed_out then
      return
    end
    local output = {}
    if result.stdout and result.stdout ~= "" then
      output = vim.split(result.stdout, "\n", { trimempty = true })
    end
    if on_exit then
      vim.schedule(function()
        on_exit(result.code or 0, output, false)
      end)
    end
  end)

  if timeout_ms > 0 then
    vim.defer_fn(function()
      if done then
        return
      end
      done = true
      timed_out = true
      if handle and handle.kill then
        pcall(handle.kill, handle, 15)
      end
      M.notify_timeout(cmd)
      if on_timeout then
        on_timeout()
      end
      if on_exit then
        vim.schedule(function()
          on_exit(-1, {}, true)
        end)
      end
    end, timeout_ms)
  end

  return handle
end

return M
