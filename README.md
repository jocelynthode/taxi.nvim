# taxi.nvim

Neovim-native plugin for the [taxi timesheeting tool](https://github.com/sephii/taxi/)
that makes your life easier. Inspired by and forked from
[schtibe/taxi.vim](https://github.com/schtibe/taxi.vim).

## Features

- Syntax highlighting for `.tks` files
- Alias completion when adding a new line
- Output of the balance every time the timesheet gets saved
- Aligning the timesheet entries on save
- Automatic async update of the aliases

## Requirements

- Neovim 0.10+
- `taxi` CLI in your `PATH`

## Installation

Install with your plugin manager of choice:

```lua
-- lazy.nvim
{
  "jocelynthode/taxi.nvim",
  ft = "taxi",
}
```

```lua
-- packer.nvim
use({ "jocelynthode/taxi.nvim", ft = "taxi" })
```

## Usage

Open a `.tks` file. The plugin:

- Sets `filetype=taxi`
- Runs alias updates in the background
- Formats entries on save
- Shows a balance notification after save (or a scratch window if configured)

### Alias completion

If you use omni completion, press `<c-x><c-o>` to complete aliases. When you
start a new line at column 1, omni completion is triggered automatically.
Omni completion is enabled by default unless `blink.cmp` or `nvim-cmp` is
installed; configure `completion.omnifunc` to override.

## Configuration

Call `require("taxi").setup(...)` once during startup. Options:

```lua
require("taxi").setup({
  balance = {
    enabled = true,
    cmd = { "taxi", "zebra", "balance" },
    mode = "notify", -- "notify" | "scratch"
  },
  cache = {
    path = vim.fn.stdpath("data") .. "/taxi/taxi_aliases",
  },
  aliases = {
    auto_update = true, -- true | false
    update_debounce_ms = 200, -- number (ms)
    notify_on_update = true, -- true | false
  },
  commands = {
    timeout_ms = 10000, -- number (ms), 0 disables
  },
  completion = {
    omnifunc = "auto", -- "auto" | true | false
  },
})
```

## blink-cmp

To use the native blink-cmp source, register it as a provider and enable it
for the `taxi` filetype:

```lua
require("blink.cmp").setup({
  sources = {
    providers = {
      taxi = {
        name = "Taxi",
        module = "taxi.blink",
      },
    },
    per_filetype = {
      taxi = { "taxi" },
    },
  },
})
```

If you're using blink-cmp, disable omnifunc to avoid a second completion path:

```lua
require("taxi").setup({
  completion = {
    omnifunc = false,
  },
})
```

By default, `omnifunc = "auto"` disables omnifunc when `blink.cmp` or `nvim-cmp`
is installed.

## nvim-cmp

Register the taxi source:

```lua
local cmp = require("cmp")

cmp.register_source("taxi", require("taxi.cmp").new())

cmp.setup({
  sources = cmp.config.sources({
    { name = "taxi" },
  }),
})
```

## Commands

- `:TaxiUpdate` to run `taxi update` and refresh alias cache
- `:TaxiBalance` to show the current balance

## Lualine

Example component for showing when the balance command is running:

```lua
local function taxi_balance_status()
  if require("taxi").is_balance_inflight() then
    return "Taxi:bal..."
  end
  return ""
end

require("lualine").setup({
  sections = {
    lualine_x = { taxi_balance_status, "encoding", "fileformat", "filetype" },
  },
})
```

## Tests

Tests are split across `tests/*_spec.lua` and use plenary's busted harness.
If you run tests without devenv, set `PLENARY_PATH` to your `plenary.nvim`
checkout, then run:

```bash
PLENARY_PATH=/path/to/plenary.nvim \
  nvim --headless -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/ { minimal_init = './tests/minimal_init.lua' }" \
  -c "qa"
```

### Devenv

If you use devenv.sh, run tests via:

```bash
devenv test
```

If the TUI hides test output, add `--no-tui`:

```bash
devenv test --no-tui
```

## Cache

Alias data is cached in `stdpath('data') .. '/taxi/taxi_aliases'` for faster
startup and refreshed asynchronously after opening a taxi file.
