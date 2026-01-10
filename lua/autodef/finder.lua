-- autodef/finder.lua
-- 信号定义查找模块

local M = {}

local parser = require("autodef.parser")
local config = require("autodef.config")

--- 在定义列表中查找指定信号
---@param signal_name string 信号名
---@param definitions table 定义列表
---@return table|nil 找到的定义信息 {found, line, type, width, category}
function M.find_signal(signal_name, definitions)
  for _, def in ipairs(definitions) do
    if def.name == signal_name then
      return {
        found = true,
        line = def.line,
        type = def.type,
        width = def.width,
        category = def.category,
        subtype = def.subtype,
      }
    end
  end
  return nil
end

--- 查找并返回信号定义（直接从buffer查找）
---@param signal_name string 信号名
---@param bufnr number|nil buffer编号
---@return table|nil 找到的定义信息
function M.find_signal_in_buffer(signal_name, bufnr)
  bufnr = bufnr or 0
  local definitions = parser.get_all_definitions(bufnr)
  return M.find_signal(signal_name, definitions)
end

--- 查找未定义的信号
---@param identifiers table 标识符列表
---@param definitions table 定义列表
---@return table 未定义的信号名列表
function M.find_undefined_signals(identifiers, definitions)
  -- 构建已定义信号的集合
  local defined_set = {}
  for _, def in ipairs(definitions) do
    defined_set[def.name] = true
  end

  -- 获取配置的忽略模式
  local cfg = config.get()
  local ignore_patterns = cfg.ignore_patterns or {}

  -- 过滤未定义的信号
  local undefined = {}
  local seen = {}

  for _, name in ipairs(identifiers) do
    if not seen[name] and not defined_set[name] then
      -- 检查是否匹配忽略模式
      local should_ignore = false
      for _, pattern in ipairs(ignore_patterns) do
        if name:match(pattern) then
          should_ignore = true
          break
        end
      end

      if not should_ignore then
        seen[name] = true
        table.insert(undefined, name)
      end
    end
  end

  return undefined
end

--- 从buffer的选中区域查找未定义信号
---@param bufnr number|nil buffer编号
---@param start_line number 起始行（1-indexed）
---@param end_line number 结束行（1-indexed）
---@return table 未定义的信号名列表
function M.find_undefined_in_range(bufnr, start_line, end_line)
  bufnr = bufnr or 0

  -- 获取选中区域的所有标识符
  local identifiers = parser.get_identifiers_in_range(bufnr, start_line, end_line)

  -- 获取所有已定义的信号
  local definitions = parser.get_all_definitions(bufnr)

  -- 查找未定义的信号
  return M.find_undefined_signals(identifiers, definitions)
end

--- 格式化定义信息用于显示
---@param def table 定义信息
---@return string 格式化的字符串
function M.format_definition_info(def)
  if not def then
    return "Not found"
  end

  local parts = { def.type }

  if def.subtype then
    table.insert(parts, def.subtype)
  end

  if def.width then
    table.insert(parts, def.width)
  end

  return table.concat(parts, " ")
end

return M
