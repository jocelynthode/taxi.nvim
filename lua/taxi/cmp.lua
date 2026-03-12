local source = {}

---Create an nvim-cmp source instance.
---@return table
function source.new()
  return setmetatable({}, { __index = source })
end

---Enable source only for taxi buffers.
---@return boolean
function source:is_available()
  return vim.bo.filetype == "taxi"
end

---Return the source name for debugging.
---@return string
function source:get_debug_name()
  return "taxi"
end

---Provide completion items for taxi aliases.
---@param params table
---@param callback fun(response: table)
function source:complete(params, callback)
  local aliases = require("taxi.aliases").get_cached_aliases()
  local items = {}

  for _, alias in ipairs(aliases) do
    table.insert(items, {
      label = alias[1],
      kind = vim.lsp.protocol.CompletionItemKind.Text,
      documentation = alias[2],
    })
  end

  callback({ items = items, isIncomplete = false })
end

return source
