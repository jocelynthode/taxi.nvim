local M = {}

local cached_aliases = {}
local updated_aliases = {}
local is_closing = false
local taxi_missing_notified = false
local alias_update_pending = false
local balance_job_id = nil
local balance_seq = 0
local balance_inflight = false

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
  },
  commands = {
    timeout_ms = 10000,
  },
  completion = {
    omnifunc = "auto",
  },
}

local config = vim.deepcopy(default_config)

local function should_use_omnifunc()
  if config.completion.omnifunc == "auto" then
    return not pcall(require, "blink.cmp")
  end
  return config.completion.omnifunc == true
end

local function get_cache_path()
  return config.cache.path or default_config.cache.path
end

local function ensure_taxi_available()
  if vim.fn.executable("taxi") == 1 then
    return true
  end

  if not taxi_missing_notified then
    taxi_missing_notified = true
    vim.notify("taxi executable not found in PATH", vim.log.levels.WARN, { title = "taxi" })
  end

  return false
end

local notify_timeout

local function parse_alias_line(line)
  local parts = vim.split(line, "%s+", { trimempty = true })
  if #parts > 2 then
    local alias = parts[2]
    local text = table.concat(parts, " ", 4)
    return { alias, text }
  end
end

local function parse_updated_aliases(lines)
  for _, line in ipairs(lines) do
    if line ~= "" then
      local value = parse_alias_line(line)
      if value then
        table.insert(updated_aliases, value)
      end
    end
  end
end

local function cache_aliases()
  local payload = {}
  for _, alias in ipairs(cached_aliases) do
    table.insert(payload, alias[1] .. "|" .. alias[2])
  end

  local cache_file = get_cache_path()
  local directory = vim.fn.fnamemodify(cache_file, ":p:h")
  if vim.fn.isdirectory(directory) == 0 then
    vim.fn.mkdir(directory, "p")
  end

  vim.fn.writefile(payload, cache_file)
end

local function read_aliases()
  local cache_file = get_cache_path()
  if vim.fn.filereadable(cache_file) == 0 then
    return
  end

  cached_aliases = {}
  local lines = vim.fn.readfile(cache_file)
  for _, line in ipairs(lines) do
    local parts = vim.split(line, "|", { trimempty = true })
    if #parts > 1 then
      table.insert(cached_aliases, { parts[1], parts[2] })
    end
  end
end

local function process_aliases()
  local merged = {}
  local ordered = {}
  for _, alias in ipairs(updated_aliases) do
    if not merged[alias[1]] then
      merged[alias[1]] = alias[2]
      table.insert(ordered, alias[1])
    end
  end

  cached_aliases = {}
  for _, name in ipairs(ordered) do
    table.insert(cached_aliases, { name, merged[name] })
  end

  cache_aliases()
end

local function jobstart_capture(cmd, on_done)
  if not ensure_taxi_available() then
    return
  end
  local stdout = {}
  local done = false
  local timed_out = false
  local opts = {
    stdout_buffered = true,
    on_stdout = function(_, data)
      stdout = data
    end,
    on_exit = function(_, code)
      if done then
        return
      end
      done = true
      if timed_out then
        return
      end
      on_done(code, stdout, false)
    end,
  }

  local job_id = vim.fn.jobstart(cmd, opts)
  if job_id <= 0 then
    return
  end

  local timeout_ms = config.commands.timeout_ms or 0
  if timeout_ms > 0 then
    vim.defer_fn(function()
      if done then
        return
      end
      done = true
      timed_out = true
      pcall(vim.fn.jobstop, job_id)
      notify_timeout(cmd)
      on_done(-1, {}, true)
    end, timeout_ms)
  end
end

local function resolve_cmd(cmd)
  if type(cmd) == "string" then
    return cmd
  end
  return cmd
end

local function format_cmd(cmd)
  if type(cmd) == "string" then
    return cmd
  end
  return table.concat(cmd, " ")
end

notify_timeout = function(cmd)
  vim.notify("taxi command timed out: " .. format_cmd(cmd), vim.log.levels.WARN, { title = "taxi" })
end

local function update_aliases()
  updated_aliases = {}
  jobstart_capture({ "taxi", "alias", "list", "--no-inactive" }, function(code, stdout, timed_out)
    if timed_out then
      return
    end
    if code ~= 0 then
      return
    end

    parse_updated_aliases(stdout)
    process_aliases()
  end)
end

local function schedule_alias_update()
  if not config.aliases.auto_update then
    return
  end

  if alias_update_pending then
    return
  end

  alias_update_pending = true
  local delay = config.aliases.update_debounce_ms or 0
  if delay < 0 then
    delay = 0
  end

  vim.defer_fn(function()
    alias_update_pending = false
    jobstart_capture({ "taxi", "update" }, function(code, _, timed_out)
      if timed_out then
        return
      end
      if code == 0 then
        update_aliases()
      end
    end)
  end, delay)
end

function M.assemble_aliases()
  read_aliases()
  schedule_alias_update()
end

function M.complete(findstart, base)
  if findstart == 1 then
    local line = vim.api.nvim_get_current_line()
    local start = vim.fn.col(".") - 1
    while start > 0 and line:sub(start, start):match("[%w_%-%?]") do
      start = start - 1
    end
    return start
  end

  local matches = {}
  local prefix = vim.pesc(base)
  for _, alias in ipairs(cached_aliases) do
    if alias[1]:match("^" .. prefix) then
      table.insert(matches, { word = alias[1], menu = alias[2] })
    end
  end

  return matches
end

local function str_pad(value, length)
  local indent = string.rep(" ", 4)
  local diff = length - #value
  if diff < 0 then
    diff = 0
  end
  local space = string.rep(" ", diff)
  if value:sub(1, 1) == "-" then
    return space .. value .. indent
  end
  return value .. space .. indent
end

local function parse_line(line)
  return line:match("^([%w_%-%?]+)%s+([0-9:%?%-]+)%s+(.*)$")
end

function M.format_file()
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local data = {}
  local col_sizes = { 0, 0 }

  for index, line in ipairs(lines) do
    local alias, time, desc = parse_line(line)
    if alias then
      table.insert(data, { index, alias, time, desc })
      if #alias > col_sizes[1] then
        col_sizes[1] = #alias
      end
      if #time > col_sizes[2] then
        col_sizes[2] = #time
      end
    end
  end

  for _, entry in ipairs(data) do
    local index, alias, time, desc = unpack(entry)
    lines[index] = str_pad(alias, col_sizes[1]) .. str_pad(time, col_sizes[2]) .. desc
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
end

function M.show_balance()
  if not config.balance.enabled then
    return
  end

  if not ensure_taxi_available() then
    return
  end

  if is_closing then
    return
  end

  balance_seq = balance_seq + 1
  local seq = balance_seq
  local stdout = {}
  local done = false

  if balance_job_id then
    pcall(vim.fn.jobstop, balance_job_id)
    balance_job_id = nil
  end

  balance_inflight = true
  local balance_cmd = resolve_cmd(config.balance.cmd)
  local timeout_ms = config.commands.timeout_ms or 0
  balance_job_id = vim.fn.jobstart(balance_cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if seq ~= balance_seq then
        return
      end
      stdout = data
    end,
    on_exit = function(_, code)
      if done then
        return
      end
      done = true
      if seq ~= balance_seq then
        return
      end
      balance_job_id = nil
      balance_inflight = false
      local balance = stdout or {}
      if code ~= 0 or #balance == 0 then
        balance = { "Could not read the balance" }
      end

      if config.balance.mode == "notify" then
        local level = code == 0 and vim.log.levels.INFO or vim.log.levels.WARN
        vim.notify(table.concat(balance, "\n"), level, { title = "taxi" })
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
  })

  if balance_job_id > 0 and timeout_ms > 0 then
    vim.defer_fn(function()
      if done then
        return
      end
      done = true
      if seq ~= balance_seq then
        return
      end
      pcall(vim.fn.jobstop, balance_job_id)
      balance_job_id = nil
      balance_inflight = false
      notify_timeout(balance_cmd)
    end, timeout_ms)
  end

  if balance_job_id <= 0 then
    balance_job_id = nil
    balance_inflight = false
  end
end

function M.balance_close()
  is_closing = true
  balance_seq = balance_seq + 1
  if balance_job_id then
    pcall(vim.fn.jobstop, balance_job_id)
    balance_job_id = nil
  end
  balance_inflight = false
  if config.balance.mode == "notify" then
    return
  end
  local winnr = vim.fn.bufwinnr("^_taxibalance$")
  if winnr > 0 then
    vim.cmd(winnr .. "wincmd w")
    vim.cmd("wincmd q")
  end
end

function M.insert_enter()
  if not should_use_omnifunc() then
    return
  end

  if vim.fn.col(".") == 1 then
    local keys = vim.api.nvim_replace_termcodes("<c-x><c-o>", true, false, true)
    vim.api.nvim_feedkeys(keys, "n", false)
  end
end

function M.setup_buffer()
  if should_use_omnifunc() then
    vim.bo.omnifunc = "v:lua.require'taxi'.complete"
    vim.opt_local.completeopt:append("longest")
  end

  local buf = vim.api.nvim_get_current_buf()
  local group = vim.api.nvim_create_augroup("TaxiBuffer" .. buf, { clear = true })

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    buffer = buf,
    callback = M.format_file,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    buffer = buf,
    callback = M.show_balance,
  })

  vim.api.nvim_create_autocmd("QuitPre", {
    group = group,
    buffer = buf,
    callback = M.balance_close,
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    buffer = buf,
    callback = M.insert_enter,
  })

  M.assemble_aliases()
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), opts or {})
end

function M.get_cached_aliases()
  return vim.deepcopy(cached_aliases)
end

function M.is_balance_inflight()
  return balance_inflight
end

return M
