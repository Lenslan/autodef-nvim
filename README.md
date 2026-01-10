# autodef-nvim

A Neovim plugin for Verilog/SystemVerilog signal definition management. Quickly check, add, and align signal definitions without jumping around in large files.

## Features

- **Signal Definition Check**: Check if a signal is defined, show its definition location
- **Auto Signal Addition**: Add signal definitions (wire/reg/logic) with type and width prompts
- **Batch Signal Addition**: Select a code region and batch add all undefined signals
- **Signal Alignment**: Automatically align all signal definitions for better readability
- **Customizable Insert Position**: Configure where new signals are inserted

## Requirements

- Neovim >= 0.9.0
- Tree-sitter verilog parser (optional, for enhanced parsing)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-username/autodef-nvim",
  ft = { "verilog", "systemverilog", "verilog_systemverilog" },
  opts = {
    -- your configuration here
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

### Keymaps

| Keymap | Mode | Description |
|--------|------|-------------|
| `<leader>sd` | Normal | Check/Add signal definition under cursor |
| `<leader>sb` | Visual | Batch add undefined signals in selection |
| `<leader>sa` | Normal | Align all signal definitions |

### Commands

- `:AutoDefCheck` - Check or add signal definition under cursor
- `:AutoDefBatch` - Batch add signal definitions (supports range)
- `:AutoDefAlign` - Align all signal definitions

### Examples

#### Check/Add Single Signal

1. Place cursor on an undefined signal name
2. Press `<leader>sd`
3. If signal exists: shows definition location
4. If signal doesn't exist:
   - Select type (wire/reg/logic)
   - Enter bit width (e.g., `1`, `8`, `[7:0]`, `[WIDTH-1:0]`)
   - Signal definition is inserted automatically

#### Batch Add Signals

1. Select a code region in Visual mode
2. Press `<leader>sb`
3. Select which signals to add
4. Choose to apply same type to all or set individually
5. Enter bit width
6. All signals are inserted

#### Align Signals

Press `<leader>sa` to align all signal definitions:

**Before:**
```verilog
wire [7:0] data_in;
wire[31:0]address;
reg valid;
reg [WIDTH-1:0]counter;
```

**After:**
```verilog
wire  [7:0]        data_in;
wire  [31:0]       address;
reg                valid;
reg   [WIDTH-1:0]  counter;
```

## Configuration

```lua
require("autodef").setup({
  -- Keymaps
  keymaps = {
    single = "<leader>sd",  -- Check/add single signal
    batch = "<leader>sb",   -- Batch add signals
    align = "<leader>sa",   -- Align signals
  },

  -- Defaults
  default_type = "wire",    -- Default signal type
  default_width = "1",      -- Default bit width

  -- Insert position strategy
  -- Options: "after_port", "after_last_wire", "after_last_reg",
  --          "after_last_signal", "grouped"
  insert_position = "after_port",

  -- Alignment options
  align = {
    enabled = true,         -- Enable auto-alignment on insert
    type_width = 6,         -- Type column width
    bit_width = 12,         -- Bit width column width
  },

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
| `1` or empty | Single bit: `wire signal;` |
| `8` | 8 bits: `wire [7:0] signal;` |
| `32` | 32 bits: `wire [31:0] signal;` |
| `[7:0]` | Direct: `wire [7:0] signal;` |
| `[WIDTH-1:0]` | Parameterized: `wire [WIDTH-1:0] signal;` |
| `WIDTH` | Auto-expand: `wire [WIDTH-1:0] signal;` |

## License

MIT
