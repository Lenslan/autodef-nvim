-- autodef/inserter.lua
-- 信号定义插入模块

local M = {}

local parser = require("autodef.parser")
local config = require("autodef.config")

--- 格式化信号定义行
---@param signal_type string 信号类型 (wire/reg/logic)
---@param signal_name string 信号名
---@param width string|nil 位宽
---@param cfg table|nil 配置
---@return string 格式化的信号定义行
function M.format_signal_line(signal_type, signal_name, width, cfg)
  cfg = cfg or config.get()

  local indent = cfg.indent or "  "

  if cfg.align and cfg.align.enabled then
    local type_width = cfg.align.type_width or 6
    local bit_width = cfg.align.bit_width or 12

    -- 类型列（左对齐）
    local type_str = signal_type .. string.rep(" ", math.max(0, type_width - #signal_type))

    -- 位宽列（左对齐）
    local width_str
    if width and width ~= "" then
      width_str = width .. string.rep(" ", math.max(0, bit_width - #width))
    else
      width_str = string.rep(" ", bit_width)
    end

    return indent .. type_str .. width_str .. signal_name .. ";"
  else
    -- 不对齐，简单格式
    if width and width ~= "" then
      return indent .. signal_type .. " " .. width .. " " .. signal_name .. ";"
    else
      return indent .. signal_type .. " " .. signal_name .. ";"
    end
  end
end

--- 根据配置策略获取插入行号
---@param bufnr number buffer编号
---@param signal_type string 信号类型
---@return number|nil 插入行号（0-indexed for API）
function M.get_insert_line(bufnr, signal_type)
  local cfg = config.get()
  local position = cfg.insert_position or "after_port"

  local line = nil

  if position == "after_port" then
    line = parser.get_port_end_line(bufnr)
  elseif position == "after_last_wire" then
    line = parser.get_last_signal_line(bufnr, "wire")
  elseif position == "after_last_reg" then
    line = parser.get_last_signal_line(bufnr, "reg")
  elseif position == "after_last_signal" then
    line = parser.get_last_signal_line(bufnr, "any")
  elseif position == "grouped" then
    -- 按类型分组：先找同类型的最后一行，找不到则用端口结束行
    local same_type_line = parser.get_last_signal_line(bufnr, signal_type)
    if same_type_line then
      line = same_type_line
    else
      line = parser.get_port_end_line(bufnr)
    end
  else
    -- 默认：端口定义后
    line = parser.get_port_end_line(bufnr)
  end

  return line
end

--- 插入单个信号定义
---@param bufnr number buffer编号
---@param signal_type string 信号类型
---@param signal_name string 信号名
---@param width string|nil 位宽（用户输入，会被解析）
---@return number|nil 插入的行号（1-indexed），失败返回nil
function M.insert_signal(bufnr, signal_type, signal_name, width)
  bufnr = bufnr or 0

  -- 解析位宽输入
  local parsed_width = parser.parse_width_input(width)

  -- 获取插入位置
  local insert_after = M.get_insert_line(bufnr, signal_type)
  if not insert_after then
    return nil
  end

  -- 格式化信号定义行
  local line_content = M.format_signal_line(signal_type, signal_name, parsed_width)

  -- 插入行（nvim API使用0-indexed）
  vim.api.nvim_buf_set_lines(bufnr, insert_after, insert_after, false, { line_content })

  -- 返回实际插入的行号（1-indexed）
  return insert_after + 1
end

--- 批量插入信号定义
---@param bufnr number buffer编号
---@param signals table 信号列表 { {type, name, width}, ... }
---@return table 插入结果 { count, start_line }
function M.insert_signals_batch(bufnr, signals)
  bufnr = bufnr or 0

  if #signals == 0 then
    return { count = 0, start_line = nil }
  end

  local cfg = config.get()

  -- 按类型分组（如果配置为grouped）
  local grouped_signals = {}
  if cfg.insert_position == "grouped" then
    for _, sig in ipairs(signals) do
      local t = sig.type or "wire"
      if not grouped_signals[t] then
        grouped_signals[t] = {}
      end
      table.insert(grouped_signals[t], sig)
    end
  else
    -- 不分组，统一处理
    grouped_signals["_all"] = signals
  end

  local total_count = 0
  local first_line = nil

  -- 处理每个分组
  for group_type, group_signals in pairs(grouped_signals) do
    -- 获取该组的插入位置
    local insert_type = group_type == "_all" and signals[1].type or group_type
    local insert_after = M.get_insert_line(bufnr, insert_type)

    if insert_after then
      -- 生成所有行
      local lines = {}
      for _, sig in ipairs(group_signals) do
        local parsed_width = parser.parse_width_input(sig.width)
        local line_content = M.format_signal_line(sig.type, sig.name, parsed_width)
        table.insert(lines, line_content)
      end

      -- 批量插入
      vim.api.nvim_buf_set_lines(bufnr, insert_after, insert_after, false, lines)

      total_count = total_count + #lines

      if not first_line or insert_after + 1 < first_line then
        first_line = insert_after + 1
      end
    end
  end

  return { count = total_count, start_line = first_line }
end

--- 生成信号定义字符串（不插入，仅生成）
---@param signal_type string 信号类型
---@param signal_name string 信号名
---@param width string|nil 位宽
---@return string 信号定义字符串
function M.generate_signal_definition(signal_type, signal_name, width)
  local parsed_width = parser.parse_width_input(width)
  return M.format_signal_line(signal_type, signal_name, parsed_width)
end

return M
