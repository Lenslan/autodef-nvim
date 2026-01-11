-- autodef/init.lua
-- 插件入口模块

local M = {}

local config = require("autodef.config")
local parser = require("autodef.parser")
local finder = require("autodef.finder")
local inserter = require("autodef.inserter")
local aligner = require("autodef.aligner")
local ui = require("autodef.ui")

--- 检查或添加单个信号定义
--- 如果信号已定义，显示定义位置；否则引导用户添加
function M.check_or_add_signal()
  local bufnr = vim.api.nvim_get_current_buf()

  -- 检查文件类型
  if not parser.is_verilog_file(bufnr) then
    ui.warn("Not a Verilog/SystemVerilog file")
    return
  end

  -- 获取光标下的单词
  local word = parser.get_word_under_cursor()
  if not word then
    ui.warn("No valid identifier under cursor")
    return
  end

  -- 查找信号定义
  local def = finder.find_signal_in_buffer(word, bufnr)

  if def then
    -- 信号已定义，显示位置
    local info = finder.format_definition_info(def)
    ui.info(string.format("Signal '%s' defined at line %d (%s)", word, def.line, info))

    -- 可选：跳转到定义位置
    -- vim.api.nvim_win_set_cursor(0, {def.line, 0})
  else
    -- 信号未定义，引导用户添加
    ui.info(string.format("Signal '%s' not found. Adding...", word))

    -- 选择类型
    ui.select_type(function(signal_type)
      -- 输入位宽
      ui.input_width(function(width)
        -- 插入信号定义
        local line = inserter.insert_signal(bufnr, signal_type, word, width)
        if line then
          local def_str = inserter.generate_signal_definition(signal_type, word, width)
          ui.info(string.format("Added '%s' at line %d", def_str:gsub("^%s+", ""), line))
        else
          ui.error("Failed to insert signal definition. Cannot find port declaration.")
        end
      end)
    end)
  end
end

--- 批量添加信号定义（Visual模式）
function M.batch_add_signals()
  local bufnr = vim.api.nvim_get_current_buf()

  -- 检查文件类型
  if not parser.is_verilog_file(bufnr) then
    ui.warn("Not a Verilog/SystemVerilog file")
    return
  end

  -- 获取Visual选择范围
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local end_line = end_pos[2]

  if start_line == 0 or end_line == 0 then
    ui.warn("No visual selection")
    return
  end

  -- 查找未定义的信号
  local undefined = finder.find_undefined_in_range(bufnr, start_line, end_line)

  if #undefined == 0 then
    ui.info("No undefined signals found in selection")
    return
  end

  ui.info(string.format("Found %d undefined signals", #undefined))

  -- 多选要添加的信号
  ui.multi_select_signals(undefined, function(selected)
    if #selected == 0 then
      return
    end

    -- 选择批量模式
    ui.select_batch_mode(#selected, function(mode)
      if mode == "unified" then
        -- 统一类型和位宽
        ui.select_type(function(signal_type)
          ui.input_width(function(width)
            local signals = {}
            for _, name in ipairs(selected) do
              table.insert(signals, {
                type = signal_type,
                name = name,
                width = width,
              })
            end

            local result = inserter.insert_signals_batch(bufnr, signals)
            ui.info(string.format("Added %d signal definitions", result.count))
          end)
        end)
      else
        -- 逐个设置
        M._add_signals_individually(bufnr, selected, 1, {})
      end
    end)
  end)
end

--- 逐个添加信号（内部函数）
---@param bufnr number buffer编号
---@param signals table 信号名列表
---@param index number 当前索引
---@param collected table 已收集的信号定义
function M._add_signals_individually(bufnr, signals, index, collected)
  if index > #signals then
    -- 所有信号都已配置，批量插入
    if #collected > 0 then
      local result = inserter.insert_signals_batch(bufnr, collected)
      ui.info(string.format("Added %d signal definitions", result.count))
    end
    return
  end

  local name = signals[index]
  ui.info(string.format("Configuring signal '%s' (%d/%d)", name, index, #signals))

  ui.select_type(function(signal_type)
    ui.input_width(function(width)
      table.insert(collected, {
        type = signal_type,
        name = name,
        width = width,
      })
      M._add_signals_individually(bufnr, signals, index + 1, collected)
    end)
  end)
end

--- 对齐所有信号定义
function M.align_signals()
  local bufnr = vim.api.nvim_get_current_buf()

  -- 检查文件类型
  if not parser.is_verilog_file(bufnr) then
    ui.warn("Not a Verilog/SystemVerilog file")
    return
  end

  local count = aligner.align_buffer(bufnr)

  if count > 0 then
    ui.info(string.format("Aligned %d signal definitions", count))
  else
    ui.info("No signal definitions to align")
  end
end

--- 设置快捷键
local function setup_keymaps()
  local cfg = config.get()
  local keymaps = cfg.keymaps

  -- Normal模式：单信号查询/添加
  if keymaps.single then
    vim.keymap.set("n", keymaps.single, function()
      M.check_or_add_signal()
    end, { desc = "AutoDef: Check/Add signal definition" })
  end

  -- Visual模式：批量添加
  if keymaps.batch then
    vim.keymap.set("v", keymaps.batch, function()
      -- 先退出Visual模式以获取正确的选择范围（'< 和 '> 标记）
      local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
      vim.api.nvim_feedkeys(esc, "x", false)
      vim.schedule(function()
        M.batch_add_signals()
      end)
    end, { desc = "AutoDef: Batch add signal definitions" })
  end

  -- Normal模式：对齐
  if keymaps.align then
    vim.keymap.set("n", keymaps.align, function()
      M.align_signals()
    end, { desc = "AutoDef: Align signal definitions" })
  end
end

--- 设置命令
local function setup_commands()
  -- 单信号查询/添加命令
  vim.api.nvim_create_user_command("AutoDefCheck", function()
    M.check_or_add_signal()
  end, { desc = "Check or add signal definition under cursor" })

  -- 批量添加命令（支持range）
  vim.api.nvim_create_user_command("AutoDefBatch", function(opts)
    if opts.range == 2 then
      -- 有范围选择
      vim.fn.setpos("'<", { 0, opts.line1, 1, 0 })
      vim.fn.setpos("'>", { 0, opts.line2, 1, 0 })
    end
    M.batch_add_signals()
  end, { range = true, desc = "Batch add signal definitions in range" })

  -- 对齐命令
  vim.api.nvim_create_user_command("AutoDefAlign", function()
    M.align_signals()
  end, { desc = "Align all signal definitions" })
end

--- 初始化插件
---@param opts table|nil 用户配置
function M.setup(opts)
  -- 初始化配置
  config.setup(opts)

  -- 设置快捷键
  setup_keymaps()

  -- 设置命令
  setup_commands()
end

-- 导出子模块（供高级用户使用）
M.config = config
M.parser = parser
M.finder = finder
M.inserter = inserter
M.aligner = aligner
M.ui = ui

return M
