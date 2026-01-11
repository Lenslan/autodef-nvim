-- autodef/config.lua
-- 配置管理模块

local M = {}

-- 默认配置
M.defaults = {
  -- 快捷键配置（Normal和Visual模式使用相同快捷键）
  keymap = "<leader>sd",

  -- 默认值
  default_type = "wire", -- 默认信号类型
  default_width = "1", -- 默认位宽

  -- 插入位置策略
  -- after_port: 端口定义后第一行（默认）
  -- after_last_wire: 最后一个wire定义后
  -- after_last_reg: 最后一个reg定义后
  -- after_last_signal: 最后一个信号定义后
  -- grouped: 按类型分组插入
  insert_position = "after_port",

  -- 缩进
  indent = "  ", -- 缩进字符（2空格）

  -- 通知
  notify_timeout = 3000, -- 通知显示时间(ms)

  -- 过滤规则（批量模式下忽略的标识符模式）
  ignore_patterns = {},

  -- 信号类型选项
  signal_types = { "wire", "reg", "logic" },
}

-- 当前配置
M._config = nil

--- 深度合并表
---@param t1 table 基础表
---@param t2 table 覆盖表
---@return table 合并后的表
local function deep_merge(t1, t2)
  local result = vim.deepcopy(t1)
  for k, v in pairs(t2) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

--- 初始化配置
---@param opts table|nil 用户配置
function M.setup(opts)
  opts = opts or {}
  M._config = deep_merge(M.defaults, opts)
end

--- 获取当前配置
---@return table 配置表
function M.get()
  if not M._config then
    M.setup({})
  end
  return M._config
end

--- 获取特定配置项
---@param key string 配置键名（支持点分隔）
---@return any 配置值
function M.get_option(key)
  local config = M.get()
  local keys = vim.split(key, ".", { plain = true })
  local value = config
  for _, k in ipairs(keys) do
    if type(value) ~= "table" then
      return nil
    end
    value = value[k]
  end
  return value
end

return M
