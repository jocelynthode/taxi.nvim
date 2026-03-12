local ok, stub = pcall(require, "luassert.stub")
if not ok then
  stub = function(target, key, value)
    local orig = target[key]
    target[key] = value
    return {
      revert = function()
        target[key] = orig
      end,
    }
  end
end

local M = {}

function M.new_stubber()
  local stubs = {}

  local function add_stub(target, key, value)
    local handle = stub(target, key, value)
    table.insert(stubs, handle)
    return handle
  end

  local function revert_all()
    for _, handle in ipairs(stubs) do
      handle:revert()
    end
    stubs = {}
  end

  local function stub_executable(value)
    add_stub(vim.fn, "executable", function()
      return value
    end)
  end

  local function stub_defer_immediate()
    add_stub(vim, "defer_fn", function(fn)
      fn()
    end)
  end

  local function stub_notify_store(messages, levels)
    add_stub(vim, "notify", function(msg, level)
      table.insert(messages, msg)
      if levels then
        table.insert(levels, level)
      end
    end)
  end

  local function stub_system(handler)
    add_stub(vim, "system", function(cmd, opts, on_exit)
      return handler(cmd, opts, on_exit)
    end)
  end

  local function stub_pcall(handler)
    add_stub(_G, "pcall", handler)
  end

  local function stub_schedule(handler)
    add_stub(vim, "schedule", function(fn)
      return handler(fn)
    end)
  end

  return {
    add_stub = add_stub,
    revert_all = revert_all,
    stub_executable = stub_executable,
    stub_defer_immediate = stub_defer_immediate,
    stub_notify_store = stub_notify_store,
    stub_system = stub_system,
    stub_pcall = stub_pcall,
    stub_schedule = stub_schedule,
  }
end

return M
