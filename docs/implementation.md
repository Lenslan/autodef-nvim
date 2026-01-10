# autodef-nvim 实现文档

## 1. 项目结构

```
autodef-nvim/
├── lua/
│   └── autodef/
│       ├── init.lua          # 插件入口，setup函数
│       ├── config.lua        # 配置管理
│       ├── parser.lua        # 信号解析（基于treesitter + 正则）
│       ├── finder.lua        # 信号定义查找
│       ├── inserter.lua      # 信号定义插入
│       ├── aligner.lua       # 信号定义对齐
│       └── ui.lua            # 用户交互界面
├── plugin/
│   └── autodef.lua           # 插件自动加载
├── docs/
│   ├── requirements.md       # 需求文档
│   └── implementation.md     # 实现文档（本文档）
└── README.md
```

## 2. 模块设计

### 2.1 init.lua - 插件入口

**职责**:
- 提供 `setup()` 函数供用户配置
- 注册命令和快捷键
- 协调各模块工作

**主要接口**:
```lua
M.setup(opts)                 -- 初始化插件
M.check_or_add_signal()       -- 主函数：查询或添加单个信号
M.batch_add_signals()         -- 批量添加信号（Visual模式）
M.align_signals()             -- 对齐所有信号定义
```

### 2.2 config.lua - 配置管理

**职责**: 管理插件默认配置和用户配置

**默认配置**:
```lua
{
  keymaps = {
    single = "<leader>sd",
    batch = "<leader>sb",
    align = "<leader>sa",
  },
  default_type = "wire",
  default_width = "1",
  insert_position = "after_port",
  align = {
    enabled = true,
    type_width = 5,
    bit_width = 12,
  },
  indent = "  ",
  notify_timeout = 3000,
  ignore_patterns = {},
}
```

### 2.3 parser.lua - 信号解析

**职责**: 解析Verilog/SV代码，提取信号信息

**主要接口**:
```lua
M.get_word_under_cursor()           -- 获取光标下的标识符
M.get_identifiers_in_range(s, e)    -- 获取范围内的所有标识符
M.get_all_definitions(bufnr)        -- 获取所有信号/参数定义
M.get_port_end_line(bufnr)          -- 获取端口定义结束行
M.get_last_signal_line(bufnr, type) -- 获取最后一个指定类型信号的行号
M.is_valid_identifier(word)         -- 检查是否为有效标识符
```

**解析策略**:
1. 优先使用Tree-sitter（如果可用）
2. 备用：使用正则表达式匹配

**正则匹配模式**:
```lua
-- 端口定义结束
PORT_END_PATTERN = "^%s*%)%s*;"

-- wire定义
WIRE_PATTERN = "^%s*(wire)%s*(%[.-%])?%s*([%w_]+)"

-- reg定义
REG_PATTERN = "^%s*(reg)%s*(%[.-%])?%s*([%w_]+)"

-- logic定义 (SystemVerilog)
LOGIC_PATTERN = "^%s*(logic)%s*(%[.-%])?%s*([%w_]+)"

-- 端口定义
PORT_PATTERN = "^%s*(input|output|inout)%s*(wire|reg|logic)?%s*(%[.-%])?%s*([%w_]+)"

-- 参数定义
PARAM_PATTERN = "^%s*(parameter|localparam)%s+.*%s*([%w_]+)%s*="
```

### 2.4 finder.lua - 信号定义查找

**职责**: 在已解析的定义中查找目标信号

**主要接口**:
```lua
M.find_signal(signal_name, definitions)
-- 返回: { found = bool, line = number, type = string, width = string } | nil

M.find_undefined_signals(identifiers, definitions)
-- 返回: { name1, name2, ... } 未定义的信号列表
```

### 2.5 inserter.lua - 信号定义插入

**职责**: 在指定位置插入格式化的信号定义

**主要接口**:
```lua
M.insert_signal(bufnr, signal_type, signal_name, width)
-- 根据配置的insert_position策略插入信号

M.insert_signals_batch(bufnr, signals)
-- 批量插入信号定义
-- signals: { {type="wire", name="sig1", width="8"}, ... }

M.get_insert_line(bufnr, signal_type)
-- 根据insert_position配置获取插入行号
```

**插入位置策略**:
```lua
function M.get_insert_line(bufnr, signal_type)
  local config = require("autodef.config").get()
  local parser = require("autodef.parser")

  if config.insert_position == "after_port" then
    return parser.get_port_end_line(bufnr) + 1

  elseif config.insert_position == "after_last_wire" then
    return parser.get_last_signal_line(bufnr, "wire") + 1

  elseif config.insert_position == "after_last_reg" then
    return parser.get_last_signal_line(bufnr, "reg") + 1

  elseif config.insert_position == "after_last_signal" then
    return parser.get_last_signal_line(bufnr, "any") + 1

  elseif config.insert_position == "grouped" then
    return parser.get_last_signal_line(bufnr, signal_type) + 1
  end
end
```

### 2.6 aligner.lua - 信号定义对齐

**职责**: 对齐文件中的信号定义

**主要接口**:
```lua
M.align_buffer(bufnr)
-- 对齐整个buffer中的信号定义

M.format_signal_line(signal_type, width, name, config)
-- 格式化单行信号定义
```

**对齐算法**:
```lua
function M.format_signal_line(signal_type, width, name, cfg)
  local type_col = cfg.align.type_width
  local width_col = cfg.align.bit_width

  -- 类型列（左对齐）
  local type_str = signal_type .. string.rep(" ", type_col - #signal_type)

  -- 位宽列（左对齐）
  local width_str = ""
  if width and width ~= "" then
    width_str = width .. string.rep(" ", width_col - #width)
  else
    width_str = string.rep(" ", width_col)
  end

  return cfg.indent .. type_str .. width_str .. name .. ";"
end
```

**对齐示例**:
```
输入:
  wire [7:0] data_in;
  wire[31:0]address;
  reg valid;
  reg [WIDTH-1:0]counter;

输出（type_width=5, bit_width=12）:
  wire [7:0]       data_in;
  wire [31:0]      address;
  reg              valid;
  reg  [WIDTH-1:0] counter;
```

### 2.7 ui.lua - 用户交互

**职责**: 处理用户输入和消息显示

**主要接口**:
```lua
M.notify(msg, level)                    -- 显示通知
M.select_type(callback)                 -- 选择信号类型
M.input_width(callback)                 -- 输入位宽
M.multi_select(items, opts, callback)   -- 多选（用于批量添加）
```

## 3. 核心流程

### 3.1 单信号查询/添加流程

```
用户按下 <leader>sd
       ↓
获取光标下的单词 (parser.get_word_under_cursor)
       ↓
    是否有效？ ─── 否 ──→ 显示警告，结束
       │
       是
       ↓
获取所有定义 (parser.get_all_definitions)
       ↓
查找信号 (finder.find_signal)
       ↓
   已定义？ ─── 是 ──→ 显示定义位置，结束
       │
       否
       ↓
选择类型 (ui.select_type)
       ↓
输入位宽 (ui.input_width)
       ↓
计算插入位置 (inserter.get_insert_line)
       ↓
插入信号定义 (inserter.insert_signal)
       ↓
显示成功消息
```

### 3.2 批量添加流程

```
用户在Visual模式选中区域，按下 <leader>sb
       ↓
获取选中范围
       ↓
提取所有标识符 (parser.get_identifiers_in_range)
       ↓
获取所有定义 (parser.get_all_definitions)
       ↓
过滤未定义信号 (finder.find_undefined_signals)
       ↓
   有未定义？ ─── 否 ──→ 显示 "No undefined signals"，结束
       │
       是
       ↓
显示多选菜单 (ui.multi_select)
       ↓
用户选择要添加的信号
       ↓
选择类型（统一或逐个）
       ↓
输入位宽（统一或逐个）
       ↓
批量插入 (inserter.insert_signals_batch)
       ↓
显示成功消息
```

### 3.3 对齐流程

```
用户按下 <leader>sa
       ↓
扫描所有信号定义行
       ↓
计算最大列宽
       ↓
逐行重新格式化
       ↓
更新buffer
       ↓
显示对齐数量
```

## 4. 位宽解析

**输入格式支持**:

| 用户输入 | 解析结果 | 生成代码 |
|----------|----------|----------|
| `1` 或空 | 单bit | `wire signal;` |
| `8` | 8位 | `wire [7:0] signal;` |
| `32` | 32位 | `wire [31:0] signal;` |
| `[7:0]` | 直接使用 | `wire [7:0] signal;` |
| `[WIDTH-1:0]` | 直接使用 | `wire [WIDTH-1:0] signal;` |
| `WIDTH` | 参数化 | `wire [WIDTH-1:0] signal;` |

**解析函数**:
```lua
function parse_width(input)
  if not input or input == "" or input == "1" then
    return nil  -- 单bit
  end

  -- 纯数字
  if input:match("^%d+$") then
    local n = tonumber(input)
    return string.format("[%d:0]", n - 1)
  end

  -- 已有方括号
  if input:match("^%[.*%]$") then
    return input
  end

  -- 参数名（如 WIDTH）
  if input:match("^[%w_]+$") then
    return string.format("[%s-1:0]", input)
  end

  -- 其他表达式
  return "[" .. input .. "]"
end
```

## 5. Verilog关键字过滤

批量模式下需要过滤的关键字：

```lua
VERILOG_KEYWORDS = {
  -- 模块相关
  "module", "endmodule", "input", "output", "inout",
  -- 数据类型
  "wire", "reg", "logic", "integer", "real", "time",
  -- 控制流
  "if", "else", "case", "endcase", "for", "while",
  "begin", "end", "fork", "join",
  -- 赋值
  "assign", "always", "initial",
  -- 其他
  "parameter", "localparam", "generate", "endgenerate",
  "posedge", "negedge", "or", "and", "not",
}
```

## 6. 错误处理

| 错误场景 | 处理方式 |
|----------|----------|
| Tree-sitter不可用 | 自动降级到正则匹配 |
| 非Verilog文件 | `vim.notify("Not a Verilog/SV file", vim.log.levels.WARN)` |
| 光标下无有效单词 | `vim.notify("No valid identifier under cursor", vim.log.levels.WARN)` |
| 找不到端口定义 | `vim.notify("Cannot find port declaration", vim.log.levels.ERROR)` |
| 用户取消输入 | 静默返回 |

## 7. LazyVim 集成配置

```lua
-- ~/.config/nvim/lua/plugins/autodef.lua
return {
  "your-username/autodef-nvim",
  ft = { "verilog", "systemverilog", "verilog_systemverilog" },
  opts = {
    keymaps = {
      single = "<leader>sd",
      batch = "<leader>sb",
      align = "<leader>sa",
    },
    default_type = "wire",
    insert_position = "after_port",
    align = {
      enabled = true,
      type_width = 5,
      bit_width = 12,
    },
  },
}
```
