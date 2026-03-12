local source = {}

---Create a blink-cmp source instance.
---@param opts table|nil
---@return table
function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts or {}
  return self
end

---Enable source only for taxi buffers.
---@return boolean
function source:enabled()
  return vim.bo.filetype == "taxi"
end

---Provide completion items for taxi aliases.
---@param _ table
---@param callback fun(response: table)
function source:get_completions(_, callback)
  local aliases = require("taxi.aliases").get_cached_aliases()
  local items = {}
  local kind = require("blink.cmp.types").CompletionItemKind.Text

  for _, alias in ipairs(aliases) do
    table.insert(items, {
      label = alias[1],
      kind = kind,
      detail = alias[2],
    })
  end

  callback({
    items = items,
    is_incomplete_backward = false,
    is_incomplete_forward = false,
  })
end

return source
