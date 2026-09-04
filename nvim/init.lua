-- This file simply bootstraps the installation of Lazy.nvim and then calls other files for execution
-- This file doesn't necessarily need to be touched, BE CAUTIOUS editing this file and proceed at your own risk.
local lazypath = vim.env.LAZY or vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not (vim.env.LAZY or (vim.uv or vim.loop).fs_stat(lazypath)) then
  -- stylua: ignore
  local result = vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
  if vim.v.shell_error ~= 0 then
    -- stylua: ignore
    vim.api.nvim_echo({ { ("Error cloning lazy.nvim:\n%s\n"):format(result), "ErrorMsg" }, { "Press any key to exit...", "MoreMsg" } }, true, {})
    vim.fn.getchar()
    vim.cmd.quit()
  end
end

vim.opt.rtp:prepend(lazypath)

-- validate that lazy is available
if not pcall(require, "lazy") then
  -- stylua: ignore
  vim.api.nvim_echo({ { ("Unable to load lazy from: %s\n"):format(lazypath), "ErrorMsg" }, { "Press any key to exit...", "MoreMsg" } }, true, {})
  vim.fn.getchar()
  vim.cmd.quit()
end

require "lazy_setup"
require "polish"
vim.opt.spelllang = { "pt_br", "en_us" }

-- O `spellfile.vim` pergunta se quer baixar o dicionário que falta, e pergunta
-- de dentro do buffer em que o `spell` acabou de ser ligado — que é o editor de
-- mensagem do neogit, que abre com ele ligado. Com o noice e o snacks por cima,
-- esse prompt não tem como ser respondido e volta a cada redesenho, bem no
-- momento de escrever o commit. Os dicionários se instalam à mão (veja o
-- README); o que falta fica sem correção ortográfica, que é o pior que pode
-- acontecer aqui.
vim.g.loaded_spellfile_plugin = 1
