-- autodef/parser.lua
-- 信号解析模块（基于正则表达式，可选Tree-sitter增强）

local M = {}

-- Verilog/SystemVerilog 关键字（用于过滤）
M.VERILOG_KEYWORDS = {
  -- 模块相关
  "module",
  "endmodule",
  "input",
  "output",
  "inout",
  "interface",
  "endinterface",
  "modport",
  -- 数据类型
  "wire",
  "reg",
  "logic",
  "integer",
  "real",
  "time",
  "bit",
  "byte",
  "shortint",
  "int",
  "longint",
  "signed",
  "unsigned",
  -- 控制流
  "if",
  "else",
  "case",
  "casex",
  "casez",
  "endcase",
  "for",
  "while",
  "do",
  "forever",
  "repeat",
  "begin",
  "end",
  "fork",
  "join",
  "join_any",
  "join_none",
  -- 赋值和过程块
  "assign",
  "always",
  "always_comb",
  "always_ff",
  "always_latch",
  "initial",
  "final",
  -- 参数
  "parameter",
  "localparam",
  "defparam",
  -- 生成
  "generate",
  "endgenerate",
  "genvar",
  -- 任务和函数
  "task",
  "endtask",
  "function",
  "endfunction",
  "return",
  -- 敏感列表
  "posedge",
  "negedge",
  "edge",
  -- 逻辑运算
  "or",
  "and",
  "not",
  "xor",
  "nand",
  "nor",
  "xnor",
  -- 其他
  "default",
  "disable",
  "wait",
  "force",
  "release",
  "import",
  "export",
  "typedef",
  "struct",
  "union",
  "enum",
  "class",
  "endclass",
  "virtual",
  "static",
  "automatic",
  "const",
  "void",
  "null",
}

-- 将关键字转换为集合以便快速查找
M._keywords_set = nil

local function get_keywords_set()
  if not M._keywords_set then
    M._keywords_set = {}
    for _, kw in ipairs(M.VERILOG_KEYWORDS) do
      M._keywords_set[kw] = true
    end
  end
  return M._keywords_set
end

--- 检查是否为有效的Verilog标识符
---@param word string 要检查的单词
---@return boolean 是否有效
function M.is_valid_identifier(word)
  if not word or word == "" then
    return false
  end

  -- 检查是否为关键字
  if get_keywords_set()[word] then
    return false
  end

  -- 检查是否符合标识符命名规则（字母或下划线开头，后跟字母、数字、下划线）
  if not word:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
    return false
  end

  -- 过滤纯数字（虽然上面的正则已经排除，但双重检查）
  if word:match("^%d+$") then
    return false
  end

  return true
end

--- 获取光标下的单词
---@return string|nil 光标下的单词，如果无效则返回nil
function M.get_word_under_cursor()
  local word = vim.fn.expand("<cword>")
  if M.is_valid_identifier(word) then
    return word
  end
  return nil
end

--- 解析位宽字符串
---@param width_str string|nil 位宽字符串
---@return string|nil 规范化的位宽字符串
function M.parse_width_input(width_str)
  if not width_str or width_str == "" or width_str == "1" then
    return nil -- 单bit
  end

  -- 纯数字转换为 [n-1:0]
  if width_str:match("^%d+$") then
    local n = tonumber(width_str)
    if n and n > 1 then
      return string.format("[%d:0]", n - 1)
    end
    return nil
  end

  -- 已有方括号，直接返回
  if width_str:match("^%[.*%]$") then
    return width_str
  end

  -- 参数名（如 WIDTH），转换为 [WIDTH-1:0]
  if width_str:match("^[%w_]+$") then
    return string.format("[%s-1:0]", width_str)
  end

  -- 其他表达式，添加方括号
  return "[" .. width_str .. "]"
end

--- 获取buffer的所有行
---@param bufnr number buffer编号
---@return table 行列表
local function get_buffer_lines(bufnr)
  bufnr = bufnr or 0
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

--- 解析单行，提取信号定义信息
---@param line string 代码行
---@param line_num number 行号（1-indexed）
---@return table|nil 定义信息 {name, type, width, line, category}
local function parse_signal_line(line, line_num)
  local definitions = {}

  -- 端口定义: input/output/inout [wire/reg/logic] [width] name
  -- Lua模式不支持|，需要分别匹配
  local port_types = { "input", "output", "inout" }
  for _, port_type in ipairs(port_types) do
    -- 匹配带子类型的端口: input wire [7:0] name 或 input logic name
    local pattern1 = "^%s*" .. port_type .. "%s+([%w_]+)%s*(%[.-%])%s*([%w_]+)"
    local subtype, width, name = line:match(pattern1)
    if subtype and name and (subtype == "wire" or subtype == "reg" or subtype == "logic") then
      table.insert(definitions, {
        name = name,
        type = port_type,
        subtype = subtype,
        width = width,
        line = line_num,
        category = "port",
      })
      break
    end

    -- 匹配带位宽但无子类型的端口: input [7:0] name
    local pattern2 = "^%s*" .. port_type .. "%s+(%[.-%])%s*([%w_]+)"
    width, name = line:match(pattern2)
    if width and name then
      table.insert(definitions, {
        name = name,
        type = port_type,
        width = width,
        line = line_num,
        category = "port",
      })
      break
    end

    -- 匹配简单端口: input name 或 input wire name
    local pattern3 = "^%s*" .. port_type .. "%s+([%w_]+)%s*([%w_]*)%s*,?"
    local first, second = line:match(pattern3)
    if first then
      if first == "wire" or first == "reg" or first == "logic" then
        -- input wire name 格式
        if second and second ~= "" and M.is_valid_identifier(second) then
          table.insert(definitions, {
            name = second,
            type = port_type,
            subtype = first,
            line = line_num,
            category = "port",
          })
        end
      elseif M.is_valid_identifier(first) then
        -- input name 格式
        table.insert(definitions, {
          name = first,
          type = port_type,
          line = line_num,
          category = "port",
        })
      end
      break
    end
  end

  -- wire定义: wire [width] name [, name2, ...]
  local wire_match = line:match("^%s*wire%s+(.+);?%s*$")
  if wire_match then
    local width_part = wire_match:match("^(%[.-%])%s*")
    local names_part = width_part and wire_match:sub(#width_part + 1) or wire_match
    -- 提取所有信号名（处理逗号分隔的多个信号）
    for signal_name in names_part:gmatch("([%w_]+)") do
      if M.is_valid_identifier(signal_name) then
        table.insert(definitions, {
          name = signal_name,
          type = "wire",
          width = width_part,
          line = line_num,
          category = "signal",
        })
      end
    end
  end

  -- reg定义: reg [width] name [, name2, ...]
  local reg_match = line:match("^%s*reg%s+(.+);?%s*$")
  if reg_match then
    local width_part = reg_match:match("^(%[.-%])%s*")
    local names_part = width_part and reg_match:sub(#width_part + 1) or reg_match
    for signal_name in names_part:gmatch("([%w_]+)") do
      if M.is_valid_identifier(signal_name) then
        table.insert(definitions, {
          name = signal_name,
          type = "reg",
          width = width_part,
          line = line_num,
          category = "signal",
        })
      end
    end
  end

  -- logic定义: logic [width] name [, name2, ...]
  local logic_match = line:match("^%s*logic%s+(.+);?%s*$")
  if logic_match then
    local width_part = logic_match:match("^(%[.-%])%s*")
    local names_part = width_part and logic_match:sub(#width_part + 1) or logic_match
    for signal_name in names_part:gmatch("([%w_]+)") do
      if M.is_valid_identifier(signal_name) then
        table.insert(definitions, {
          name = signal_name,
          type = "logic",
          width = width_part,
          line = line_num,
          category = "signal",
        })
      end
    end
  end

  -- 参数定义: parameter/localparam [type] name = value
  local param_pattern = "^%s*(parameter|localparam)%s+.-%s*([%w_]+)%s*="
  local param_type, param_name = line:match(param_pattern)
  if param_type and param_name and M.is_valid_identifier(param_name) then
    table.insert(definitions, {
      name = param_name,
      type = param_type,
      line = line_num,
      category = "parameter",
    })
  end

  return #definitions > 0 and definitions or nil
end

--- 获取所有信号定义
---@param bufnr number|nil buffer编号
---@return table 定义列表
function M.get_all_definitions(bufnr)
  bufnr = bufnr or 0
  local lines = get_buffer_lines(bufnr)
  local all_definitions = {}

  for i, line in ipairs(lines) do
    local defs = parse_signal_line(line, i)
    if defs then
      for _, def in ipairs(defs) do
        table.insert(all_definitions, def)
      end
    end
  end

  return all_definitions
end

--- 获取端口定义结束行（); 所在行）
---@param bufnr number|nil buffer编号
---@return number|nil 端口结束行号（1-indexed），未找到返回nil
function M.get_port_end_line(bufnr)
  bufnr = bufnr or 0
  local lines = get_buffer_lines(bufnr)

  local in_module = false
  local paren_depth = 0

  for i, line in ipairs(lines) do
    -- 检测module开始
    if line:match("^%s*module%s+") then
      in_module = true
    end

    if in_module then
      -- 计算括号深度
      for _ in line:gmatch("%(") do
        paren_depth = paren_depth + 1
      end
      for _ in line:gmatch("%)") do
        paren_depth = paren_depth - 1
      end

      -- 检测端口声明结束 );
      if line:match("%);") and paren_depth <= 0 then
        return i
      end
    end
  end

  return nil
end

--- 获取最后一个指定类型信号的行号
---@param bufnr number|nil buffer编号
---@param signal_type string 信号类型 ("wire", "reg", "logic", "any")
---@return number|nil 行号（1-indexed）
function M.get_last_signal_line(bufnr, signal_type)
  bufnr = bufnr or 0
  local definitions = M.get_all_definitions(bufnr)

  local last_line = nil
  for _, def in ipairs(definitions) do
    if def.category == "signal" then
      if signal_type == "any" or def.type == signal_type then
        if not last_line or def.line > last_line then
          last_line = def.line
        end
      end
    end
  end

  -- 如果没找到任何信号定义，返回端口结束行
  if not last_line then
    last_line = M.get_port_end_line(bufnr)
  end

  return last_line
end

--- 获取指定范围内的所有标识符
---@param bufnr number|nil buffer编号
---@param start_line number 起始行（1-indexed）
---@param end_line number 结束行（1-indexed）
---@return table 标识符列表（去重）
function M.get_identifiers_in_range(bufnr, start_line, end_line)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

  local identifiers = {}
  local seen = {}

  for _, line in ipairs(lines) do
    -- 移除注释
    line = line:gsub("//.*$", "")
    line = line:gsub("/%*.-%*/", "")

    -- 提取所有可能的标识符
    for word in line:gmatch("[%w_]+") do
      if M.is_valid_identifier(word) and not seen[word] then
        seen[word] = true
        table.insert(identifiers, word)
      end
    end
  end

  return identifiers
end

--- 解析现有的信号定义行，提取类型、位宽、信号名
---@param line string 代码行
---@return table|nil {type, width, name, indent} 或 nil
function M.parse_existing_signal_line(line)
  -- 匹配 wire/reg/logic [width] name;
  local indent = line:match("^(%s*)")
  local signal_type, rest = line:match("^%s*(wire|reg|logic)%s+(.+);%s*$")

  if not signal_type then
    return nil
  end

  local width = rest:match("^(%[.-%])%s*")
  local name
  if width then
    name = rest:sub(#width + 1):match("^%s*([%w_]+)")
  else
    name = rest:match("^([%w_]+)")
  end

  if name and M.is_valid_identifier(name) then
    return {
      type = signal_type,
      width = width,
      name = name,
      indent = indent or "",
    }
  end

  return nil
end

--- 检查文件类型是否为Verilog/SystemVerilog
---@param bufnr number|nil buffer编号
---@return boolean
function M.is_verilog_file(bufnr)
  bufnr = bufnr or 0
  local ft = vim.bo[bufnr].filetype
  return ft == "verilog" or ft == "systemverilog" or ft == "verilog_systemverilog"
end

return M
