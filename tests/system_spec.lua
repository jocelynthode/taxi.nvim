local helpers = require("helpers")
local taxi = require("taxi")
local system = require("taxi.system")

describe("taxi system", function()
  local stubber

  before_each(function()
    stubber = helpers.new_stubber()
    stubber.stub_executable(1)
  end)

  after_each(function()
    stubber.revert_all()
  end)

  it("schedules timeout on_exit callback", function()
    local scheduled = 0

    stubber.stub_schedule(function(fn)
      scheduled = scheduled + 1
      fn()
    end)
    stubber.stub_defer_immediate()
    stubber.stub_system(function(_, _, _)
      return { kill = function() end }
    end)

    taxi.setup({ commands = { timeout_ms = 1 } })

    local timed_out = nil
    system.start_job({ "taxi", "status" }, {
      on_exit = function(_, _, timeout)
        timed_out = timeout
      end,
    })

    assert.equals(true, timed_out)
    assert.equals(1, scheduled)
  end)

  it("runs on_exit once when timeout fires before process exit", function()
    local scheduled = 0
    local process_exit_callback

    stubber.stub_schedule(function(fn)
      scheduled = scheduled + 1
      fn()
    end)
    stubber.stub_defer_immediate()
    stubber.stub_system(function(_, _, on_exit)
      process_exit_callback = on_exit
      return { kill = function() end }
    end)

    taxi.setup({ commands = { timeout_ms = 1 } })

    local on_exit_calls = 0
    local timed_out = nil
    system.start_job({ "taxi", "status" }, {
      on_exit = function(_, _, timeout)
        on_exit_calls = on_exit_calls + 1
        timed_out = timeout
      end,
    })

    process_exit_callback({ code = 0, stdout = "Status OK" })

    assert.equals(1, on_exit_calls)
    assert.equals(true, timed_out)
    assert.equals(1, scheduled)
  end)
end)
