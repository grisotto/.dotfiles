-- Minimal Neovim init for the headless test harness.
-- On the runtimepath: this repository, plenary, and astrocore — nothing else.
-- No AstroNvim, no plugin manager, nothing that could make a test depend on
-- the real config.
--
-- astrocore is there because the panel does not detect where a project begins:
-- it asks the root detector of the editor's own configuration, which is
-- astrocore's rooter. Faking it inside the plugin would prove nothing about
-- the answer it gives in a monorepo, which is the behaviour under test.

local this_file = debug.getinfo(1, "S").source:sub(2)
local config_root = vim.fn.fnamemodify(this_file, ":p:h:h")
local lazy = vim.fn.stdpath "data" .. "/lazy"

local plugins = {}
for _, name in ipairs { "plenary.nvim", "astrocore" } do
  local path = lazy .. "/" .. name
  if vim.fn.isdirectory(path) == 0 then
    io.stderr:write(name .. " not found at " .. path .. "\n")
    vim.cmd "cquit 1"
  end
  plugins[#plugins + 1] = path
end

vim.opt.runtimepath = vim.list_extend({ vim.env.VIMRUNTIME, config_root }, plugins)
vim.opt.packpath = {}
vim.opt.swapfile = false

-- Lets specs `require "tests.helpers.fixture"`, which lives outside `lua/`.
package.path = config_root .. "/?.lua;" .. config_root .. "/?/init.lua;" .. package.path

-- Before anything can write to a register: Neovim resolves the clipboard
-- provider once, and the suite must not land in the developer's clipboard.
require("tests.helpers.clipboard").install()

vim.cmd "runtime plugin/plenary.vim"
