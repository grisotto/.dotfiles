vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
vim.g.mapleader = " "
vim.g.maplocalleader = ","

local utils = require("utils.git_utils")

-- bootstrap lazy and all plugins
local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  vim.fn.system { "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath }
end

vim.opt.rtp:prepend(lazypath)

local lazy_config = require "configs.lazy"

-- load plugins
require("lazy").setup({
  {
    "NvChad/NvChad",
    lazy = false,
    branch = "v2.5",
    import = "nvchad.plugins",
  },

  { import = "plugins" },
}, lazy_config)

-- load theme
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")

require "options"
require "nvchad.autocmds"

vim.schedule(function()
  require "mappings"
end)

vim.api.nvim_create_autocmd({ 'BufEnter' }, {
  pattern = 'NvimTree*',
  callback = function()
    local api = require('nvim-tree.api')
    local view = require('nvim-tree.view')

    if not view.is_visible() then
      api.tree.open()
    end
  end,
})
-- Get git link for current line (BETA)
vim.keymap.set("n", "<localleader>gl", function()
  local link = utils.get_github_link()
  vim.fn.setreg("+", link)
  print(link)
end, { noremap = true, desc = "Get github/bitbucket link" })


local harpoon = require("harpoon")
-- REQUIRED
harpoon:setup()
vim.keymap.set("n", "<leader>a", function() harpoon:list():add() end, {desc = "Add mark to file"})
vim.keymap.set("n", "<leader>sss", function() harpoon:list():remove() end, {desc = "Remove mark to file"})
vim.keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, {desc = "Arquivos marcados", noremap = true})

vim.g["conjure#mapping#doc_word"] = "gk"

require'cmp'.setup{
  sources = {
    {name = 'conjure'},
  }
}
require('neoscroll').setup({})
