local helpers = require("helpers")
local taxi = require("taxi")

describe("taxi balance", function()
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

  it("notifies on balance timeout", function()
    local notifications = {}
    stubber.stub_notify_store(notifications)
    stubber.stub_executable(1)
    stubber.stub_defer_immediate()
    stubber.stub_system(function(_, _, _)
      return { kill = function() end }
    end)

    taxi.setup({
      balance = { enabled = true, mode = "notify", cmd = { "taxi", "zebra", "balance" } },
      commands = { timeout_ms = 1 },
    })

    taxi.show_balance()

    assert.is_true(#notifications > 0)
    assert.is_true(string.find(notifications[1], "taxi command timed out") ~= nil)
  end)

  it("uses notify mode for balance", function()
    local notifications = {}
    stubber.stub_notify_store(notifications)
    stubber.stub_executable(1)
    stubber.stub_system(function(_, _, on_exit)
      on_exit({ code = 0, stdout = "Balance OK" })
      return { kill = function() end }
    end)

    taxi.setup({
      balance = { enabled = true, mode = "notify" },
      commands = { timeout_ms = 0 },
    })
    taxi.show_balance()

    assert.equals("Balance OK", notifications[1])
  end)

  it("creates scratch buffer in balance scratch mode", function()
    stubber.stub_executable(1)
    stubber.stub_system(function(_, _, on_exit)
      on_exit({ code = 0, stdout = "Balance OK" })
      return { kill = function() end }
    end)

    taxi.setup({
      balance = { enabled = true, mode = "scratch" },
      commands = { timeout_ms = 0 },
    })
    taxi.show_balance()

    local buf = vim.fn.bufnr("^_taxibalance$")
    assert.is_true(buf > 0)
  end)

  it("runs status when balance fails", function()
    local notifications = {}
    local levels = {}
    stubber.stub_notify_store(notifications, levels)
    stubber.stub_executable(1)
    stubber.stub_system(function(cmd, _, on_exit)
      if cmd[2] == "zebra" then
        on_exit({ code = 1, stdout = "" })
        return { kill = function() end }
      end
      if cmd[2] == "status" then
        on_exit({ code = 0, stdout = "Status OK" })
        return { kill = function() end }
      end
      return { kill = function() end }
    end)

    taxi.setup({
      balance = { enabled = true, mode = "notify" },
      commands = { timeout_ms = 0 },
    })

    taxi.show_balance()

    assert.equals("Could not read the balance", notifications[1])
    assert.equals("Status OK", notifications[2])
    assert.equals(vim.log.levels.ERROR, levels[2])
  end)
end)
