local config = require("taxi.config")
local system = require("taxi.system")

local M = {}

local is_closing = false

local state = {
  job_id = nil,
  seq = 0,
  inflight = false,
}

---Show the current taxi balance using notify or scratch mode.
function M.show_balance()
  if not config.get().balance.enabled then
    return
  end

  if not system.ensure_taxi_available() then
    return
  end

  if is_closing then
    return
  end

  state.seq = state.seq + 1
  local seq = state.seq

  if state.job_id and state.job_id.kill then
    pcall(state.job_id.kill, state.job_id, 15)
    state.job_id = nil
  end

  state.inflight = true
  local balance_cmd = system.resolve_cmd(config.get().balance.cmd)
  state.job_id = system.start_job(balance_cmd, {
    on_exit = function(code, stdout, timed_out)
      if seq ~= state.seq then
        return
      end
      state.job_id = nil
      state.inflight = false
      if timed_out then
        return
      end

      local balance = stdout or {}
      if code ~= 0 or #balance == 0 then
        balance = { "Could not read the balance" }
      end

      if config.get().balance.mode == "notify" then
        local level = code == 0 and vim.log.levels.INFO or vim.log.levels.WARN
        system.notify(table.concat(balance, "\n"), level)
        return
      end

      local winnr = vim.fn.bufwinnr("^_taxibalance$")
      local buf

      if winnr > 0 then
        vim.cmd(winnr .. "wincmd w")
        buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
      else
        vim.cmd("belowright 7new _taxibalance")
        buf = vim.api.nvim_get_current_buf()
        vim.bo[buf].buftype = "nofile"
        vim.bo[buf].bufhidden = "wipe"
        vim.bo[buf].buflisted = false
        vim.bo[buf].swapfile = false
        vim.bo[buf].modifiable = true
        vim.wo[0].wrap = false
      end

      vim.api.nvim_buf_set_lines(buf, 0, -1, false, balance)
      vim.cmd("wincmd k")
    end,
    on_timeout = function()
      if seq ~= state.seq then
        return
      end
      state.job_id = nil
      state.inflight = false
    end,
  })

  if not state.job_id then
    state.job_id = nil
    state.inflight = false
  end
end

---Close the balance scratch window if present.
function M.balance_close()
  is_closing = true
  state.seq = state.seq + 1
  if state.job_id and state.job_id.kill then
    pcall(state.job_id.kill, state.job_id, 15)
    state.job_id = nil
  end
  state.inflight = false
  if config.get().balance.mode == "notify" then
    return
  end
  local winnr = vim.fn.bufwinnr("^_taxibalance$")
  if winnr > 0 then
    vim.cmd(winnr .. "wincmd w")
    vim.cmd("wincmd q")
  end
end

---Report whether the balance command is running.
---@return boolean
function M.is_balance_inflight()
  return state.inflight
end

return M
