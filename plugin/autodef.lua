-- plugin/autodef.lua
-- 插件自动加载文件

-- 防止重复加载
if vim.g.loaded_autodef then
  return
end
vim.g.loaded_autodef = true

-- 检查Neovim版本
if vim.fn.has("nvim-0.9.0") == 0 then
  vim.api.nvim_err_writeln("autodef.nvim requires Neovim >= 0.9.0")
  return
end

-- 延迟加载：仅在打开Verilog文件时加载
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "verilog", "systemverilog", "verilog_systemverilog" },
  callback = function()
    -- 如果用户没有手动调用setup，使用默认配置
    local autodef = require("autodef")
    if not require("autodef.config")._config then
      autodef.setup({})
    end
  end,
  once = false,
})
