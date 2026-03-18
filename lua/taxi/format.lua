local M = {}
local unpack = table.unpack or unpack

---Pad a string to a minimum length with taxi formatting.
---@param value string
---@param length integer
---@return string
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

---Parse a taxi line into alias, time, and description.
---@param line string
---@return string|nil, string|nil, string|nil
local function parse_line(line)
  return line:match("^([%w_%-%?]+)%s+([0-9:%?%-]+)%s+(.*)$")
end

---Align columns in the current taxi buffer.
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

return M
