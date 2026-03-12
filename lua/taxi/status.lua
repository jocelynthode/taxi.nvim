local system = require("taxi.system")

local M = {}

---Show the current taxi status via notification.
---@param opts table|nil
function M.show_status(opts)
  opts = opts or {}
  if not system.ensure_taxi_available() then
    return
  end

  system.start_job({ "taxi", "status" }, {
    on_exit = function(code, stdout, timed_out)
      if timed_out then
        return
      end

      local message = stdout or {}
      if code ~= 0 or #message == 0 then
        message = { "Could not read taxi status" }
      end

      local level = opts.level or (code == 0 and vim.log.levels.INFO or vim.log.levels.WARN)
      system.notify(table.concat(message, "\n"), level)
    end,
  })
end

return M
