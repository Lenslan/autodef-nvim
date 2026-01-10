# autodef-nvim 需求文档

## 1. 项目概述

### 1.1 背景
芯片开发工程师在日常使用Verilog/SystemVerilog编写代码时，代码规范要求所有wire和reg信号的定义都需要放在端口信号定义的下方。由于文件较大，添加信号逻辑与添加信号定义的位置距离较远，频繁跳转影响开发效率。

### 1.2 目标
开发一个Neovim插件，实现信号定义的快速查询与自动添加功能，减少文件跳转，提升开发效率。

## 2. 功能需求

### 2.1 核心功能

#### 2.1.1 信号定义查询（单信号）
- **触发方式**: 光标停留在信号名称上，按下快捷键 `<leader>sd`
- **查询范围**: 当前文件
- **查询目标**:
  - `wire` 信号定义
  - `reg` 信号定义
  - `logic` 信号定义 (SystemVerilog)
  - 端口信号定义（`input`, `output`, `inout`）
- **输出**: 若存在定义，显示消息通知定义所在行号及类型

#### 2.1.2 信号定义添加（单信号）
- **触发条件**: 信号在当前文件中不存在定义
- **交互流程**:
  1. 插件弹出提示，询问信号类型（`reg` / `wire` / `logic`）
  2. 插件弹出提示，询问信号位宽（如 `1`, `8`, `[7:0]`, `[WIDTH-1:0]`）
- **插入位置**: 端口信号定义后的第一行
- **插入格式**: 符合Verilog代码规范，自动缩进

#### 2.1.3 批量信号添加（选中区域）
- **触发方式**: 在Visual模式下选中代码区域，按下快捷键 `<leader>sb`
- **功能**:
  1. 自动扫描选中区域内的所有标识符
  2. 过滤已定义的信号（包括wire/reg/端口/参数/localparam）
  3. 列出未定义的信号供用户选择
  4. 用户可批量选择要添加的信号
  5. 统一询问类型或允许逐个设置
  6. 批量插入信号定义

#### 2.1.4 信号定义自动对齐
- **功能**: 插入信号定义时，自动与相邻的信号定义对齐
- **对齐规则**:
  - 类型关键字对齐（wire/reg/logic）
  - 位宽对齐
  - 信号名对齐
- **示例**:
```verilog
wire [7:0]       data_in;
wire [7:0]       data_out;    // 新插入，自动对齐
wire [31:0]      address;
reg              valid;
reg  [WIDTH-1:0] counter;     // 新插入，自动对齐
```

#### 2.1.5 自定义插入位置规则
- **功能**: 允许用户自定义信号定义的插入位置
- **可配置选项**:
  - `after_port`: 端口定义后第一行（默认）
  - `after_last_wire`: 最后一个wire定义后
  - `after_last_reg`: 最后一个reg定义后
  - `after_last_signal`: 最后一个信号定义后（wire或reg）
  - `grouped`: 按类型分组插入（wire插入到wire区域，reg插入到reg区域）

### 2.2 快捷键

| 快捷键 | 模式 | 功能描述 |
|--------|------|----------|
| `<leader>sd` | Normal | **S**ignal **D**efinition - 查询/添加单个信号定义 |
| `<leader>sb` | Visual | **S**ignal **B**atch - 批量扫描并添加未定义信号 |
| `<leader>sa` | Normal | **S**ignal **A**lign - 对齐当前文件所有信号定义 |

### 2.3 支持的文件类型
- `.v` (Verilog)
- `.sv` (SystemVerilog)
- `.vh` (Verilog Header)
- `.svh` (SystemVerilog Header)

## 3. 技术需求

### 3.1 依赖
- Neovim >= 0.9.0
- Tree-sitter (verilog语法支持)
- Verible LSP (可选，用于增强解析)

### 3.2 兼容性
- 兼容LazyVim配置框架
- 支持lazy.nvim插件管理器

## 4. 用户交互设计

### 4.1 查询成功场景
```
光标位于信号 `data_valid` 上 → 按下 <leader>sd
输出: "Signal 'data_valid' defined at line 25 (wire [7:0])"
```

### 4.2 添加新信号场景
```
光标位于信号 `new_signal` 上 → 按下 <leader>sd
提示: "Signal 'new_signal' not found. Select type:"
      [1] wire (Recommended)
      [2] reg
      [3] logic
用户选择: 1
提示: "Enter bit width (e.g., 1, 8, [7:0], [WIDTH-1:0]):"
用户输入: 8
结果: 在端口定义后第一行插入 "wire [7:0] new_signal;"
输出: "Added 'wire [7:0] new_signal;' at line 30"
```

### 4.3 批量添加场景
```
选中包含 `sig_a`, `sig_b`, `sig_c` 的代码区域 → 按下 <leader>sb
提示: "Found 3 undefined signals. Select signals to add:"
      [x] sig_a
      [x] sig_b
      [ ] sig_c
用户确认选择
提示: "Select type for all signals:"
      [1] wire (Recommended)
      [2] reg
      [3] logic
      [4] Set individually
用户选择: 1
提示: "Enter default bit width:"
用户输入: 1
结果: 批量插入信号定义
输出: "Added 2 signal definitions"
```

### 4.4 对齐场景
```
按下 <leader>sa
输出: "Aligned 15 signal definitions"
```

## 5. 边界情况处理

| 场景 | 处理方式 |
|------|----------|
| 光标不在有效标识符上 | 显示警告消息 |
| 文件不是Verilog/SV类型 | 显示警告消息 |
| 无法找到端口定义区域 | 显示错误消息，不执行插入 |
| 用户取消输入 | 中止操作，无消息 |
| 选中区域无未定义信号 | 显示 "No undefined signals found" |
| 信号名与Verilog关键字冲突 | 显示警告，跳过该信号 |

## 6. 配置选项

```lua
{
  -- 快捷键配置
  keymaps = {
    single = "<leader>sd",      -- 单信号查询/添加
    batch = "<leader>sb",       -- 批量添加
    align = "<leader>sa",       -- 对齐信号定义
  },

  -- 默认值
  default_type = "wire",        -- 默认信号类型
  default_width = "1",          -- 默认位宽

  -- 插入位置策略
  insert_position = "after_port", -- after_port | after_last_wire | after_last_reg | after_last_signal | grouped

  -- 对齐选项
  align = {
    enabled = true,             -- 插入时自动对齐
    type_width = 5,             -- 类型列宽度（wire/reg）
    bit_width = 12,             -- 位宽列宽度
  },

  -- 缩进
  indent = "  ",                -- 缩进字符（2空格）

  -- 通知
  notify_timeout = 3000,        -- 通知显示时间(ms)

  -- 过滤规则（批量模式下忽略的标识符）
  ignore_patterns = {
    "^clk",                     -- 以clk开头的信号
    "^rst",                     -- 以rst开头的信号
  },
}
```
