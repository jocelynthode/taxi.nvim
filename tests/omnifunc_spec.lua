local helpers = require("helpers")
local taxi = require("taxi")
local commands = require("taxi.commands")

describe("taxi omnifunc", function()
  local stubber

  before_each(function()
    stubber = helpers.new_stubber()
  end)

  after_each(function()
    stubber.revert_all()
  end)

  it("disables omnifunc when blink.cmp is present", function()
    local orig_create_buf = vim.api.nvim_create_buf
    local orig_set_current = vim.api.nvim_set_current_buf

    stubber.stub_pcall(function(_, _)
      return true
    end)

    taxi.setup({ completion = { omnifunc = "auto" } })

    local buf = orig_create_buf(false, true)
    orig_set_current(buf)
    commands.setup_buffer()

    assert.is_true(vim.bo[buf].omnifunc == "")
  end)

  it("disables omnifunc when nvim-cmp is present", function()
    local orig_create_buf = vim.api.nvim_create_buf
    local orig_set_current = vim.api.nvim_set_current_buf

    stubber.stub_pcall(function(_, module)
      if module == "cmp" then
        return true
      end
      return false
    end)

    taxi.setup({ completion = { omnifunc = "auto" } })

    local buf = orig_create_buf(false, true)
    orig_set_current(buf)
    commands.setup_buffer()

    assert.is_true(vim.bo[buf].omnifunc == "")
  end)
end)
