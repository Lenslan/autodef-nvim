# autodef-nvim

A Neovim plugin for Verilog/SystemVerilog signal definition management. Quickly check and add signal definitions without jumping around in large files.

## Features

- **Signal Definition Check**: Check if a signal is defined (including port signals), show its definition location
- **Auto Signal Addition**: Add signal definitions (wire/reg/logic) with type and width prompts
- **Batch Signal Addition**: Select a code region and batch add all undefined signals
- **Same Keymap for Both Modes**: Use the same keymap in Normal and Visual mode

## Requirements

- Neovim >= 0.9.0

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "Lenslan/autodef-nvim",
  ft = { "verilog", "systemverilog", "verilog_systemverilog" },
  opts = {
    -- Keymap (same for Normal and Visual mode)
    keymap = "<leader>sd",

    -- Insert position strategy
    -- Options: "after_port", "after_last_wire", "after_last_reg",
    --          "after_last_signal", "grouped"
    insert_position = "after_port",

    -- Indentation
    indent = "  ",

    -- Ignore patterns for batch mode (Lua patterns)
    ignore_patterns = {
      -- "^clk",   -- Ignore signals starting with "clk"
      -- "^rst",   -- Ignore signals starting with "rst"
    },

    -- Available signal types
    signal_types = { "wire", "reg", "logic" },
  },
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "your-username/autodef-nvim",
  ft = { "verilog", "systemverilog" },
  config = function()
    require("autodef").setup({
      -- your configuration here
    })
  end
}
```

## Usage

### Keymap

| Keymap | Mode | Description |
|--------|------|-------------|
| `<leader>sd` | Normal | Check/Add signal definition under cursor |
| `<leader>sd` | Visual | Batch add undefined signals in selection |

### Commands

- `:AutoDefCheck` - Check or add signal definition under cursor
- `:AutoDefBatch` - Batch add signal definitions (supports range)

### Examples

#### Check/Add Single Signal (Normal Mode)

1. Place cursor on a signal name
2. Press `<leader>sd`
3. If signal exists: shows definition location (including port signals)
4. If signal doesn't exist:
   - Select type (wire/reg/logic)
   - Enter bit width (empty for 1-bit)
   - Signal definition is inserted automatically

#### Batch Add Signals (Visual Mode)

1. Select a code region in Visual mode
2. Press `<leader>sd`
3. Select which signals to add
4. Choose to apply same type to all or set individually
5. Enter bit width
6. All signals are inserted after port declaration

## Configuration

```lua
require("autodef").setup({
  -- Keymap (same for Normal and Visual mode)
  keymap = "<leader>sd",

  -- Defaults
  default_type = "wire",    -- Default signal type
  default_width = "1",      -- Default bit width

  -- Insert position strategy
  -- Options: "after_port", "after_last_wire", "after_last_reg",
  --          "after_last_signal", "grouped"
  insert_position = "after_port",

  -- Indentation
  indent = "  ",            -- Indent string (2 spaces)

  -- Notification timeout
  notify_timeout = 3000,    -- Notification display time (ms)

  -- Ignore patterns for batch mode
  ignore_patterns = {
    -- "^clk",              -- Ignore signals starting with "clk"
    -- "^rst",              -- Ignore signals starting with "rst"
  },

  -- Available signal types
  signal_types = { "wire", "reg", "logic" },
})
```

### Customizing Keymap

You can customize the keymap by setting the `keymap` option:

```lua
-- Example 1: Use <leader>ad instead
require("autodef").setup({
  keymap = "<leader>ad",
})

-- Example 2: Use F5 key
require("autodef").setup({
  keymap = "<F5>",
})

-- Example 3: Disable default keymap and set your own
require("autodef").setup({
  keymap = nil,  -- Disable default keymap
})

-- Then set your own keymaps manually
vim.keymap.set("n", "<leader>sd", require("autodef").check_or_add_signal, { desc = "AutoDef" })
vim.keymap.set("v", "<leader>sd", function()
  vim.cmd("normal! <Esc>")
  vim.schedule(require("autodef").batch_add_signals)
end, { desc = "AutoDef Batch" })
```

### LazyVim Example

```lua
-- ~/.config/nvim/lua/plugins/autodef.lua
return {
  dir = "~/path/to/autodef-nvim",  -- or use git url
  ft = { "verilog", "systemverilog", "verilog_systemverilog" },
  opts = {
    keymap = "<leader>sd",
    insert_position = "after_port",
  },
}
```

### Insert Position Strategies

| Strategy | Description |
|----------|-------------|
| `after_port` | Insert after port declaration (default) |
| `after_last_wire` | Insert after the last wire definition |
| `after_last_reg` | Insert after the last reg definition |
| `after_last_signal` | Insert after the last signal definition |
| `grouped` | Insert with same type signals grouped together |

## Bit Width Input Formats

| Input | Result |
|-------|--------|
| (empty) | Single bit: `wire signal;` |
| `8` | 8 bits: `wire [7:0] signal;` |
| `32` | 32 bits: `wire [31:0] signal;` |
| `[7:0]` | Direct: `wire [7:0] signal;` |
| `[WIDTH-1:0]` | Parameterized: `wire [WIDTH-1:0] signal;` |
| `WIDTH` | Auto-expand: `wire [WIDTH-1:0] signal;` |

## License

MIT
