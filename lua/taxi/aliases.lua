local config = require("taxi.config")
local system = require("taxi.system")

local M = {}

local cached_aliases = {}
local updated_aliases = {}

local state = {
  pending = false,
  inflight = false,
}

---Parse a single alias line from `taxi alias list`.
---@param line string
---@return table|nil
local function parse_alias_line(line)
  local parts = vim.split(line, "%s+", { trimempty = true })
  if #parts > 2 then
    local alias = parts[2]
    local text = table.concat(parts, " ", 4)
    return { alias, text }
  end
end

---Parse alias output lines into updated_aliases.
---@param lines string[]
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

---Persist cached_aliases to disk.
local function cache_aliases()
  local payload = {}
  for _, alias in ipairs(cached_aliases) do
    table.insert(payload, alias[1] .. "|" .. alias[2])
  end

  local cache_file = config.get_cache_path()
  local directory = vim.fn.fnamemodify(cache_file, ":p:h")
  if vim.fn.isdirectory(directory) == 0 then
    vim.fn.mkdir(directory, "p")
  end

  vim.fn.writefile(payload, cache_file)
end

---Read cached aliases from disk into memory.
local function read_aliases()
  local cache_file = config.get_cache_path()
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

---Deduplicate, order, and cache updated_aliases.
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

---Refresh cached aliases from taxi output.
local function update_aliases()
  updated_aliases = {}
  state.inflight = true
  system.start_job({ "taxi", "alias", "list", "--no-inactive" }, {
    on_exit = function(code, stdout, timed_out)
      state.inflight = false
      if timed_out then
        return
      end
      if code ~= 0 then
        return
      end

      parse_updated_aliases(stdout)
      process_aliases()
    end,
    on_timeout = function()
      state.inflight = false
    end,
  })
end

---Run `taxi update` and refresh aliases on success.
local function run_alias_update()
  if not config.get().aliases.auto_update then
    return
  end

  system.start_job({ "taxi", "update" }, {
    on_exit = function(code, stdout, timed_out)
      if timed_out then
        return
      end
      if code == 0 then
        if config.get().aliases.notify_on_update then
          local message = "taxi update completed"
          if stdout and #stdout > 0 then
            message = table.concat(stdout, "\n")
          end
          system.notify(message, vim.log.levels.INFO)
        end
        update_aliases()
      end
    end,
  })
end

---Debounce alias updates after opening a file.
local function schedule_alias_update()
  if not config.get().aliases.auto_update then
    return
  end

  if state.pending then
    return
  end

  state.pending = true
  local delay = config.get().aliases.update_debounce_ms or 0
  if delay < 0 then
    delay = 0
  end

  vim.defer_fn(function()
    state.pending = false
    run_alias_update()
  end, delay)
end

---Load cached aliases and schedule a background refresh.
function M.assemble_aliases()
  read_aliases()
  schedule_alias_update()
end

---Trigger an alias update immediately.
function M.update_now()
  run_alias_update()
end

---Omnifunc completion callback for taxi aliases.
---@param findstart integer
---@param base string
---@return integer|table
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

---Return a copy of cached aliases for completion sources.
---@return table
function M.get_cached_aliases()
  return vim.deepcopy(cached_aliases)
end

---Report whether alias updates are running.
---@return boolean
function M.is_alias_update_inflight()
  return state.inflight
end

return M
