local config = require("taxi.config")
local system = require("taxi.system")
local status = require("taxi.status")

local M = {}

local state = {
  job_id = nil,
  seq = 0,
  inflight = false,
  scratch_bufnr = nil,
}

---@return integer
local function get_or_create_scratch_buf()
  if state.scratch_bufnr and vim.api.nvim_buf_is_valid(state.scratch_bufnr) then
    return state.scratch_bufnr
  end

  local buf = vim.api.nvim_create_buf(false, true)
  state.scratch_bufnr = buf
  vim.api.nvim_buf_set_name(buf, "_taxibalance")
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  return buf
end

---@param buf integer
---@return integer
local function ensure_scratch_window(buf)
  local winid = vim.fn.bufwinid(buf)
  if winid ~= -1 and vim.api.nvim_win_is_valid(winid) then
    return winid
  end

  vim.cmd("belowright 7split")
  winid = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(winid, buf)
  vim.wo[winid].wrap = false
  return winid
end

---Show the current taxi balance using notify or scratch mode.
function M.show_balance()
  if not config.get().balance.enabled then
    return
  end

  if not system.ensure_taxi_available() then
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
      local balance_failed = code ~= 0 or #balance == 0
      if balance_failed then
        balance = { "Could not read the balance" }
      end

      if config.get().balance.mode == "notify" then
        local level = balance_failed and vim.log.levels.WARN or vim.log.levels.INFO
        system.notify(table.concat(balance, "\n"), level)
        if balance_failed then
          status.show_status({ level = vim.log.levels.ERROR })
        end
        return
      end

      local prev_win = vim.api.nvim_get_current_win()
      local buf = get_or_create_scratch_buf()
      local winid = ensure_scratch_window(buf)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, balance)
      if vim.api.nvim_win_is_valid(prev_win) and prev_win ~= winid then
        vim.api.nvim_set_current_win(prev_win)
      end
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
  state.seq = state.seq + 1
  if state.job_id and state.job_id.kill then
    pcall(state.job_id.kill, state.job_id, 15)
    state.job_id = nil
  end
  state.inflight = false
  if config.get().balance.mode == "notify" then
    return
  end

  local bufnr = state.scratch_bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.fn.bufnr("^_taxibalance$")
  end

  if bufnr and bufnr > 0 then
    local winid = vim.fn.bufwinid(bufnr)
    if winid ~= -1 and vim.api.nvim_win_is_valid(winid) then
      pcall(vim.api.nvim_win_close, winid, true)
    end
  end

  state.scratch_bufnr = nil
end

---Report whether the balance command is running.
---@return boolean
function M.is_balance_inflight()
  return state.inflight
end

return M
