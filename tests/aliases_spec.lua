local helpers = require("helpers")
local taxi = require("taxi")

describe("taxi aliases", function()
  local stubber

  before_each(function()
    stubber = helpers.new_stubber()
    stubber.stub_schedule(function(fn)
      fn()
    end)
  end)

  after_each(function()
    stubber.revert_all()
  end)

  it("notifies on alias update timeout", function()
    local notifications = {}
    stubber.stub_notify_store(notifications)
    stubber.stub_executable(1)
    stubber.stub_defer_immediate()
    stubber.stub_system(function(_, _, _)
      return { kill = function() end }
    end)

    taxi.setup({
      aliases = { auto_update = true, update_debounce_ms = 0 },
      commands = { timeout_ms = 1 },
    })

    taxi.update_now()

    assert.is_true(#notifications > 0)
    assert.is_true(string.find(notifications[1], "taxi command timed out") ~= nil)
  end)

  it("parses alias list output into completion items", function()
    stubber.stub_executable(1)
    stubber.stub_defer_immediate()
    stubber.stub_system(function(cmd, _, on_exit)
      local stdout = ""
      if cmd[2] == "alias" then
        stdout = table.concat({
          "[default] proj_ana_2010 -> 1000/2000 (Client A - Analytics 2026, Product campaign (PROJ-2010))",
          "[default] proj_ana_app -> 1000/2001 (Client A - Analytics 2026, App tracking)",
          "[default] proj_ana_web -> 1000/2002 (Client A - Analytics 2026, Website tracking)",
          "[default] proj_dev -> 1001/2003 (Client A - Development 2026, Dev)",
          "[default] proj_supp -> 1001/2004 (Client A - Development 2026, Support)",
        }, "\n")
      end
      on_exit({ code = 0, stdout = stdout })
      return { kill = function() end }
    end)

    taxi.setup({
      aliases = { auto_update = true, update_debounce_ms = 0, notify_on_update = false },
      commands = { timeout_ms = 0 },
    })
    taxi.update_now()

    local matches = taxi.complete(0, "proj_ana_")
    assert.equals("proj_ana_2010", matches[1].word)
    assert.equals("1000/2000 (Client A - Analytics 2026, Product campaign (PROJ-2010))", matches[1].menu)
  end)

  it("writes and reads alias cache", function()
    local tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
    local cache_path = tmpdir .. "/taxi_aliases"
    stubber.stub_executable(1)
    stubber.stub_defer_immediate()
    stubber.stub_system(function(cmd, _, on_exit)
      local stdout = ""
      if cmd[2] == "alias" then
        stdout = "1 t1 Test One"
      end
      on_exit({ code = 0, stdout = stdout })
      return { kill = function() end }
    end)

    taxi.setup({
      cache = { path = cache_path },
      aliases = { auto_update = true, update_debounce_ms = 0, notify_on_update = false },
      commands = { timeout_ms = 0 },
    })

    taxi.assemble_aliases()
    local cached = taxi.get_cached_aliases()
    assert.equals("t1", cached[1][1])
  end)

  it("notifies on update success when enabled", function()
    local notifications = {}
    stubber.stub_notify_store(notifications)
    stubber.stub_executable(1)
    stubber.stub_defer_immediate()
    stubber.stub_system(function(cmd, _, on_exit)
      local stdout = ""
      if cmd[2] == "update" then
        stdout = "updated"
      end
      on_exit({ code = 0, stdout = stdout })
      return { kill = function() end }
    end)
    taxi.setup({
      aliases = { auto_update = true, update_debounce_ms = 0, notify_on_update = true },
      commands = { timeout_ms = 0 },
    })

    taxi.update_now()

    assert.is_true(#notifications > 0)
    assert.equals("updated", notifications[1])
  end)

  it("skips update notify when disabled", function()
    local notifications = {}
    stubber.stub_notify_store(notifications)
    stubber.stub_executable(1)
    stubber.stub_defer_immediate()
    stubber.stub_system(function(cmd, _, on_exit)
      local stdout = ""
      if cmd[2] == "update" then
        stdout = "updated"
      end
      on_exit({ code = 0, stdout = stdout })
      return { kill = function() end }
    end)
    taxi.setup({
      aliases = { auto_update = true, update_debounce_ms = 0, notify_on_update = false },
      commands = { timeout_ms = 0 },
    })

    taxi.update_now()

    assert.equals(0, #notifications)
  end)

  it("marks alias update inflight during alias list", function()
    stubber.stub_executable(1)
    stubber.stub_defer_immediate()
    stubber.stub_system(function(cmd, _, on_exit)
      if cmd[2] == "alias" then
        assert.is_true(taxi.is_alias_update_inflight())
      end
      on_exit({ code = 0, stdout = "" })
      return { kill = function() end }
    end)

    taxi.setup({
      aliases = { auto_update = true, update_debounce_ms = 0, notify_on_update = false },
      commands = { timeout_ms = 0 },
    })

    taxi.assemble_aliases()

    assert.is_false(taxi.is_alias_update_inflight())
  end)

  it("schedules alias callbacks outside fast events", function()
    local scheduled = 0
    local tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
    local cache_path = tmpdir .. "/taxi_aliases"

    stubber.stub_executable(1)
    stubber.stub_defer_immediate()
    stubber.stub_schedule(function(fn)
      scheduled = scheduled + 1
      fn()
    end)
    stubber.stub_system(function(cmd, _, on_exit)
      local stdout = ""
      if cmd[2] == "update" then
        stdout = "updated"
      end
      if cmd[2] == "alias" then
        stdout = "1 t1 Test One"
      end
      on_exit({ code = 0, stdout = stdout })
      return { kill = function() end }
    end)

    taxi.setup({
      cache = { path = cache_path },
      aliases = { auto_update = true, update_debounce_ms = 0, notify_on_update = false },
      commands = { timeout_ms = 0 },
    })

    taxi.update_now()

    assert.is_true(scheduled > 0)
  end)
end)
