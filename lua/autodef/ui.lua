-- autodef/ui.lua
-- 用户交互界面模块

local M = {}

local config = require("autodef.config")

--- 显示通知消息
---@param msg string 消息内容
---@param level number|nil 消息级别 (vim.log.levels.*)
function M.notify(msg, level)
  level = level or vim.log.levels.INFO
  vim.notify(msg, level, { title = "AutoDef" })
end

--- 显示信息消息
---@param msg string 消息内容
function M.info(msg)
  M.notify(msg, vim.log.levels.INFO)
end

--- 显示警告消息
---@param msg string 消息内容
function M.warn(msg)
  M.notify(msg, vim.log.levels.WARN)
end

--- 显示错误消息
---@param msg string 消息内容
function M.error(msg)
  M.notify(msg, vim.log.levels.ERROR)
end

--- 选择信号类型
---@param callback function 回调函数，接收选择的类型
function M.select_type(callback)
  local cfg = config.get()
  local types = cfg.signal_types or { "wire", "reg", "logic" }

  -- 添加推荐标记到默认类型
  local items = {}
  for _, t in ipairs(types) do
    if t == cfg.default_type then
      table.insert(items, t .. " (Recommended)")
    else
      table.insert(items, t)
    end
  end

  vim.ui.select(items, {
    prompt = "Select signal type:",
    format_item = function(item)
      return item
    end,
  }, function(choice)
    if choice then
      -- 移除 " (Recommended)" 后缀
      local selected = choice:gsub(" %(Recommended%)", "")
      callback(selected)
    end
  end)
end

--- 输入位宽
---@param callback function 回调函数，接收输入的位宽
---@param default string|nil 默认值
function M.input_width(callback, default)
  local cfg = config.get()
  default = default or cfg.default_width or "1"

  vim.ui.input({
    prompt = "Enter bit width (e.g., 1, 8, [7:0], [WIDTH-1:0]): ",
    default = default,
  }, function(input)
    if input then
      callback(input)
    end
  end)
end

--- 多选信号（用于批量添加）
---@param signals table 信号列表
---@param callback function 回调函数，接收选中的信号列表
function M.multi_select_signals(signals, callback)
  if #signals == 0 then
    M.warn("No undefined signals found")
    return
  end

  -- 使用telescope如果可用，否则使用简单的vim.ui.select
  local has_telescope, telescope = pcall(require, "telescope.pickers")

  if has_telescope then
    M._telescope_multi_select(signals, callback)
  else
    M._simple_multi_select(signals, callback)
  end
end

--- 简单的多选实现（无telescope时使用）
---@param signals table 信号列表
---@param callback function 回调函数
function M._simple_multi_select(signals, callback)
  -- 由于vim.ui.select不支持多选，使用逐个确认的方式
  local selected = {}
  local index = 1

  local function ask_next()
    if index > #signals then
      if #selected > 0 then
        callback(selected)
      else
        M.info("No signals selected")
      end
      return
    end

    local sig = signals[index]
    vim.ui.select({ "Yes", "No", "Yes to all remaining", "Cancel" }, {
      prompt = string.format("Add signal '%s'? (%d/%d)", sig, index, #signals),
    }, function(choice)
      if choice == "Yes" then
        table.insert(selected, sig)
        index = index + 1
        ask_next()
      elseif choice == "No" then
        index = index + 1
        ask_next()
      elseif choice == "Yes to all remaining" then
        table.insert(selected, sig)
        for i = index + 1, #signals do
          table.insert(selected, signals[i])
        end
        callback(selected)
      else
        -- Cancel
        if #selected > 0 then
          vim.ui.select({ "Yes", "No" }, {
            prompt = string.format("Add %d already selected signals?", #selected),
          }, function(confirm)
            if confirm == "Yes" then
              callback(selected)
            end
          end)
        end
      end
    end)
  end

  ask_next()
end

--- Telescope多选实现
---@param signals table 信号列表
---@param callback function 回调函数
function M._telescope_multi_select(signals, callback)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local selected = {}
  for _, sig in ipairs(signals) do
    selected[sig] = true -- 默认全选
  end

  pickers
    .new({}, {
      prompt_title = "Select signals to add (Tab to toggle, Enter to confirm)",
      finder = finders.new_table({
        results = signals,
        entry_maker = function(entry)
          return {
            value = entry,
            display = function(e)
              local prefix = selected[e.value] and "[x] " or "[ ] "
              return prefix .. e.value
            end,
            ordinal = entry,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        -- Toggle selection with Tab
        map("i", "<Tab>", function()
          local entry = action_state.get_selected_entry()
          if entry then
            selected[entry.value] = not selected[entry.value]
            -- Refresh picker
            local picker = action_state.get_current_picker(prompt_bufnr)
            picker:refresh(
              finders.new_table({
                results = signals,
                entry_maker = function(e)
                  return {
                    value = e,
                    display = function(en)
                      local prefix = selected[en.value] and "[x] " or "[ ] "
                      return prefix .. en.value
                    end,
                    ordinal = e,
                  }
                end,
              }),
              { reset_prompt = false }
            )
          end
        end)

        -- Confirm selection with Enter
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local result = {}
          for sig, is_selected in pairs(selected) do
            if is_selected then
              table.insert(result, sig)
            end
          end
          if #result > 0 then
            callback(result)
          else
            M.info("No signals selected")
          end
        end)

        return true
      end,
    })
    :find()
end

--- 选择批量添加的类型模式
---@param count number 信号数量
---@param callback function 回调函数，接收模式 ("unified" 或 "individual")
function M.select_batch_mode(count, callback)
  vim.ui.select({
    "Apply same type to all (Recommended)",
    "Set type individually",
  }, {
    prompt = string.format("How to set type for %d signals?", count),
  }, function(choice)
    if choice then
      if choice:match("^Apply same") then
        callback("unified")
      else
        callback("individual")
      end
    end
  end)
end

--- 确认操作
---@param msg string 确认消息
---@param callback function 回调函数，接收确认结果 (boolean)
function M.confirm(msg, callback)
  vim.ui.select({ "Yes", "No" }, {
    prompt = msg,
  }, function(choice)
    callback(choice == "Yes")
  end)
end

return M
