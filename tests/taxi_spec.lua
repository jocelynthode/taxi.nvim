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

  it("parses alias list output into completion items", function()
    local orig_jobstart = vim.fn.jobstart
    local orig_executable = vim.fn.executable
    local orig_defer_fn = vim.defer_fn

    vim.fn.executable = function()
      return 1
    end
    vim.fn.jobstart = function(cmd, opts)
      if cmd[2] == "alias" then
        opts.on_stdout(nil, {
          "[default] proj_ana_2010 -> 1000/2000 (Client A - Analytics 2026, Product campaign (PROJ-2010))",
          "[default] proj_ana_app -> 1000/2001 (Client A - Analytics 2026, App tracking)",
          "[default] proj_ana_web -> 1000/2002 (Client A - Analytics 2026, Website tracking)",
          "[default] proj_dev -> 1001/2003 (Client A - Development 2026, Dev)",
          "[default] proj_supp -> 1001/2004 (Client A - Development 2026, Support)",
        })
        opts.on_exit(nil, 0)
      else
        opts.on_exit(nil, 0)
      end
      return 1
    end
    vim.defer_fn = function(fn)
      fn()
    end

    taxi.setup({
      aliases = { auto_update = true, update_debounce_ms = 0, notify_on_update = false },
      commands = { timeout_ms = 0 },
    })
    taxi.assemble_aliases()

    local matches = taxi.complete(0, "proj_ana_")
    assert.equals("proj_ana_2010", matches[1].word)
    assert.equals("1000/2000 (Client A - Analytics 2026, Product campaign (PROJ-2010))", matches[1].menu)

    vim.fn.jobstart = orig_jobstart
    vim.fn.executable = orig_executable
    vim.defer_fn = orig_defer_fn
  end)

  it("writes and reads alias cache", function()
    local tmpdir = vim.fn.tempname()
    vim.fn.mkdir(tmpdir, "p")
    local cache_path = tmpdir .. "/taxi_aliases"
    local orig_jobstart = vim.fn.jobstart
    local orig_executable = vim.fn.executable
    local orig_defer_fn = vim.defer_fn

    vim.fn.executable = function()
      return 1
    end
    vim.fn.jobstart = function(cmd, opts)
      if cmd[2] == "alias" then
        opts.on_stdout(nil, { "1 t1 Test One" })
        opts.on_exit(nil, 0)
      else
        opts.on_exit(nil, 0)
      end
      return 1
    end
    vim.defer_fn = function(fn)
      fn()
    end

    taxi.setup({
      cache = { path = cache_path },
      aliases = { auto_update = true, update_debounce_ms = 0, notify_on_update = false },
      commands = { timeout_ms = 0 },
    })

    taxi.assemble_aliases()
    local cached = taxi.get_cached_aliases()
    assert.equals("t1", cached[1][1])

    vim.fn.jobstart = orig_jobstart
    vim.fn.executable = orig_executable
    vim.defer_fn = orig_defer_fn
  end)

  it("uses notify mode for balance", function()
    local notifications = {}
    local orig_notify = vim.notify
    local orig_jobstart = vim.fn.jobstart
    local orig_executable = vim.fn.executable

    vim.notify = function(msg)
      table.insert(notifications, msg)
    end
    vim.fn.executable = function()
      return 1
    end
    vim.fn.jobstart = function(_, opts)
      opts.on_stdout(nil, { "Balance OK" })
      opts.on_exit(nil, 0)
      return 1
    end

    taxi.setup({
      balance = { enabled = true, mode = "notify" },
      commands = { timeout_ms = 0 },
    })
    taxi.show_balance()

    vim.notify = orig_notify
    vim.fn.jobstart = orig_jobstart
    vim.fn.executable = orig_executable

    assert.equals("Balance OK", notifications[1])
  end)

  it("disables omnifunc when blink.cmp is present", function()
    local orig_pcall = pcall
    local orig_create_buf = vim.api.nvim_create_buf
    local orig_set_current = vim.api.nvim_set_current_buf

    _G.pcall = function(_, _)
      return true
    end

    taxi.setup({ completion = { omnifunc = "auto" } })

    local buf = orig_create_buf(false, true)
    orig_set_current(buf)
    taxi.setup_buffer()

    assert.is_true(vim.bo[buf].omnifunc == "")

    _G.pcall = orig_pcall
  end)
end)
