local source = {}

function source.new()
  return setmetatable({}, { __index = source })
end

function source:is_available()
  return vim.bo.filetype == "taxi"
end

function source:get_debug_name()
  return "taxi"
end

function source:complete(params, callback)
  local aliases = require("taxi").get_cached_aliases()
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
