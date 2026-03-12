local taxi = require("taxi")

describe("taxi", function()
  it("formats entries with aligned columns", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "a 1 Task",
      "longalias 12:30 Another task",
      "note line",
    })

    taxi.format_file()

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    assert.equals("a            1        Task", lines[1])
    assert.equals("longalias    12:30    Another task", lines[2])
    assert.equals("note line", lines[3])
  end)

  it("notifies on alias update timeout", function()
    local notifications = {}
    local orig_notify = vim.notify
    local orig_jobstart = vim.fn.jobstart
    local orig_jobstop = vim.fn.jobstop
    local orig_defer_fn = vim.defer_fn
    local orig_executable = vim.fn.executable

    vim.notify = function(msg)
      table.insert(notifications, msg)
    end
    vim.fn.executable = function()
      return 1
    end
    vim.fn.jobstart = function()
      return 1
    end
    vim.fn.jobstop = function()
      return 1
    end
    vim.defer_fn = function(fn)
      fn()
    end

    taxi.setup({
      aliases = { auto_update = true, update_debounce_ms = 0 },
      commands = { timeout_ms = 1 },
    })

    taxi.assemble_aliases()

    vim.notify = orig_notify
    vim.fn.jobstart = orig_jobstart
    vim.fn.jobstop = orig_jobstop
    vim.defer_fn = orig_defer_fn
    vim.fn.executable = orig_executable

    assert.is_true(#notifications > 0)
    assert.is_true(string.find(notifications[1], "taxi command timed out") ~= nil)
  end)

  it("notifies on balance timeout", function()
    local notifications = {}
    local orig_notify = vim.notify
    local orig_jobstart = vim.fn.jobstart
    local orig_jobstop = vim.fn.jobstop
    local orig_defer_fn = vim.defer_fn
    local orig_executable = vim.fn.executable

    vim.notify = function(msg)
      table.insert(notifications, msg)
    end
    vim.fn.executable = function()
      return 1
    end
    vim.fn.jobstart = function()
      return 1
    end
    vim.fn.jobstop = function()
      return 1
    end
    vim.defer_fn = function(fn)
      fn()
    end

    taxi.setup({
      balance = { enabled = true, mode = "notify", cmd = { "taxi", "zebra", "balance" } },
      commands = { timeout_ms = 1 },
    })

    taxi.show_balance()

    vim.notify = orig_notify
    vim.fn.jobstart = orig_jobstart
    vim.fn.jobstop = orig_jobstop
    vim.defer_fn = orig_defer_fn
    vim.fn.executable = orig_executable

    assert.is_true(#notifications > 0)
    assert.is_true(string.find(notifications[1], "taxi command timed out") ~= nil)
  end)
end)
