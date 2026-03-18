local taxi = require("taxi")
local config = require("taxi.config")

describe("taxi config", function()
  it("normalizes completion.omnifunc from string values", function()
    taxi.setup({ completion = { omnifunc = " TRUE " } })
    assert.equals(true, config.get().completion.omnifunc)

    taxi.setup({ completion = { omnifunc = "false" } })
    assert.equals(false, config.get().completion.omnifunc)

    taxi.setup({ completion = { omnifunc = "AUTO" } })
    assert.equals("auto", config.get().completion.omnifunc)
  end)

  it("rejects unknown top-level keys", function()
    local ok, err = pcall(function()
      taxi.setup({ nope = true })
    end)

    assert.is_false(ok)
    assert.is_true(string.find(err, "invalid option") ~= nil)
  end)

  it("rejects invalid numeric and enum options", function()
    local ok_timeout = pcall(function()
      taxi.setup({ commands = { timeout_ms = -1 } })
    end)
    assert.is_false(ok_timeout)

    local ok_debounce = pcall(function()
      taxi.setup({ aliases = { update_debounce_ms = -10 } })
    end)
    assert.is_false(ok_debounce)

    local ok_mode = pcall(function()
      taxi.setup({ balance = { mode = "popup" } })
    end)
    assert.is_false(ok_mode)
  end)

  it("keeps last valid config when setup validation fails", function()
    taxi.setup({ commands = { timeout_ms = 1234 } })

    local ok = pcall(function()
      taxi.setup({ commands = { timeout_ms = -1 } })
    end)

    assert.is_false(ok)
    assert.equals(1234, config.get().commands.timeout_ms)
  end)
end)
