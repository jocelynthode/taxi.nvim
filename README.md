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

- Neovim
- `taxi` CLI in your `PATH`

## Installation

Install with your plugin manager of choice:

```lua
-- lazy.nvim
{
  "yourname/taxi.nvim",
  ft = "taxi",
}
```

```lua
-- packer.nvim
use({ "yourname/taxi.nvim", ft = "taxi" })
```

## Usage

Open a `.tks` file. The plugin:

- Sets `filetype=taxi`
- Runs alias updates in the background
- Formats entries on save
- Shows the balance in a scratch window after save

### Alias completion

Use omni completion (`<c-x><c-o>`) to complete aliases. When you start a
new line at column 1, omni completion is triggered automatically.

## Configuration

Call `require("taxi").setup(...)` once during startup. Options:

```lua
require("taxi").setup({
  balance = {
    enabled = true,
    cmd = { "taxi", "zebra", "balance" },
    mode = "notify",
  },
  cache = {
    path = vim.fn.stdpath("data") .. "/taxi/taxi_aliases",
  },
  aliases = {
    auto_update = true,
    update_debounce_ms = 200,
  },
  commands = {
    timeout_ms = 10000,
  },
  completion = {
    omnifunc = "auto",
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

By default, `omnifunc = "auto"` disables omnifunc when `blink.cmp` is installed.

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

## Cache

Alias data is cached in `stdpath('data') .. '/taxi/taxi_aliases'` for faster
startup and refreshed asynchronously after opening a taxi file.
