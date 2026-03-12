local source = {}

function source.new(opts)
  local self = setmetatable({}, { __index = source })
  self.opts = opts or {}
  return self
end

function source:enabled()
  return vim.bo.filetype == "taxi"
end

function source:get_completions(_, callback)
  local aliases = require("taxi").get_cached_aliases()
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
