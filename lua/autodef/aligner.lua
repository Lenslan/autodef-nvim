-- autodef/aligner.lua
-- 信号定义对齐模块

local M = {}

local parser = require("autodef.parser")
local config = require("autodef.config")

--- 解析信号定义行
---@param line string 代码行
---@return table|nil 解析结果 {indent, type, width, name}
local function parse_signal_line(line)
  -- 匹配 wire/reg/logic [width] name;
  local indent, signal_type, rest = line:match("^(%s*)(wire|reg|logic)%s+(.+);%s*$")

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

  if name and parser.is_valid_identifier(name) then
    return {
      indent = indent or "",
      type = signal_type,
      width = width or "",
      name = name,
    }
  end

  return nil
end

--- 格式化对齐后的信号定义行
---@param indent string 缩进
---@param signal_type string 信号类型
---@param width string 位宽
---@param name string 信号名
---@param type_width number 类型列宽度
---@param bit_width number 位宽列宽度
---@return string 格式化后的行
local function format_aligned_line(indent, signal_type, width, name, type_width, bit_width)
  -- 类型列（左对齐）
  local type_str = signal_type .. string.rep(" ", math.max(0, type_width - #signal_type))

  -- 位宽列（左对齐）
  local width_str
  if width and width ~= "" then
    width_str = width .. string.rep(" ", math.max(0, bit_width - #width))
  else
    width_str = string.rep(" ", bit_width)
  end

  return indent .. type_str .. width_str .. name .. ";"
end

--- 对齐buffer中的所有信号定义
---@param bufnr number|nil buffer编号
---@return number 对齐的行数
function M.align_buffer(bufnr)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cfg = config.get()

  -- 收集所有信号定义行
  local signal_lines = {}
  for i, line in ipairs(lines) do
    local parsed = parse_signal_line(line)
    if parsed then
      table.insert(signal_lines, {
        line_num = i,
        parsed = parsed,
        original = line,
      })
    end
  end

  if #signal_lines == 0 then
    return 0
  end

  -- 计算最大宽度（如果需要动态对齐）
  local max_type_width = cfg.align.type_width or 6
  local max_bit_width = cfg.align.bit_width or 12

  -- 可选：根据实际内容计算最大宽度
  -- for _, sl in ipairs(signal_lines) do
  --   max_type_width = math.max(max_type_width, #sl.parsed.type)
  --   if sl.parsed.width then
  --     max_bit_width = math.max(max_bit_width, #sl.parsed.width)
  --   end
  -- end

  -- 格式化并更新每一行
  local count = 0
  for _, sl in ipairs(signal_lines) do
    local new_line = format_aligned_line(
      sl.parsed.indent,
      sl.parsed.type,
      sl.parsed.width,
      sl.parsed.name,
      max_type_width,
      max_bit_width
    )

    if new_line ~= sl.original then
      vim.api.nvim_buf_set_lines(bufnr, sl.line_num - 1, sl.line_num, false, { new_line })
      count = count + 1
    end
  end

  return count
end

--- 对齐指定范围内的信号定义
---@param bufnr number|nil buffer编号
---@param start_line number 起始行（1-indexed）
---@param end_line number 结束行（1-indexed）
---@return number 对齐的行数
function M.align_range(bufnr, start_line, end_line)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local cfg = config.get()

  -- 收集范围内的信号定义行
  local signal_lines = {}
  for i, line in ipairs(lines) do
    local parsed = parse_signal_line(line)
    if parsed then
      table.insert(signal_lines, {
        line_num = start_line + i - 1,
        parsed = parsed,
        original = line,
      })
    end
  end

  if #signal_lines == 0 then
    return 0
  end

  local max_type_width = cfg.align.type_width or 6
  local max_bit_width = cfg.align.bit_width or 12

  -- 格式化并更新每一行
  local count = 0
  for _, sl in ipairs(signal_lines) do
    local new_line = format_aligned_line(
      sl.parsed.indent,
      sl.parsed.type,
      sl.parsed.width,
      sl.parsed.name,
      max_type_width,
      max_bit_width
    )

    if new_line ~= sl.original then
      vim.api.nvim_buf_set_lines(bufnr, sl.line_num - 1, sl.line_num, false, { new_line })
      count = count + 1
    end
  end

  return count
end

--- 检查行是否为信号定义行
---@param line string 代码行
---@return boolean
function M.is_signal_line(line)
  return parse_signal_line(line) ~= nil
end

return M
