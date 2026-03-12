local helpers = require("helpers")
local taxi = require("taxi")

describe("taxi status", function()
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

  it("notifies with status output", function()
    local notifications = {}
    stubber.stub_notify_store(notifications)
    stubber.stub_executable(1)
    stubber.stub_system(function(_, _, on_exit)
      on_exit({ code = 0, stdout = "Status OK" })
      return { kill = function() end }
    end)

    taxi.show_status()

    assert.equals("Status OK", notifications[1])
  end)
end)
