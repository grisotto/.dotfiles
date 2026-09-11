-- Minimal Neovim init for the headless test harness.
-- On the runtimepath: this repository, plenary, astrocore and mini.icons —
-- nothing else. No AstroNvim, no plugin manager, nothing that could make a test
-- depend on the real config.
--
-- astrocore is there because the panel does not detect where a project begins:
-- it asks the root detector of the editor's own configuration, which is
-- astrocore's rooter. Faking it inside the plugin would prove nothing about
-- the answer it gives in a monorepo, which is the behaviour under test.
--
-- mini.icons is there because every line of the panel starts with the icon it
-- gives: a suite running without it would be asserting about a screen the
-- reviewer never sees.

local this_file = debug.getinfo(1, "S").source:sub(2)
local config_root = vim.fn.fnamemodify(this_file, ":p:h:h")
local lazy = vim.fn.stdpath "data" .. "/lazy"

local plugins = {}
for _, name in ipairs { "plenary.nvim", "astrocore", "mini.icons" } do
  local path = lazy .. "/" .. name
  if vim.fn.isdirectory(path) == 0 then
    io.stderr:write(name .. " not found at " .. path .. "\n")
    vim.cmd "cquit 1"
  end
  plugins[#plugins + 1] = path
end

-- The configuration directory of the editor is where the template of the
-- report's preamble is read from by default, and the real one is this very
-- repository. A template the reviewer keeps there would change what every
-- report of the suite says. Nothing is created in it; a test that wants a
-- template there asks for a directory of its own (`fixture.config_dir`).
vim.env.XDG_CONFIG_HOME = vim.fn.tempname() .. "-config"

vim.opt.runtimepath = vim.list_extend({ vim.env.VIMRUNTIME, config_root }, plugins)
vim.opt.packpath = {}
vim.opt.swapfile = false

-- Lets specs `require "tests.helpers.fixture"`, which lives outside `lua/`.
package.path = config_root .. "/?.lua;" .. config_root .. "/?/init.lua;" .. package.path

-- Before anything can write to a register: Neovim resolves the clipboard
-- provider once, and the suite must not land in the developer's clipboard.
require("tests.helpers.clipboard").install()

-- The icons only answer once the module has been set up: it is there that the
-- cache they come out of is built, and it is there that `MiniIcons` becomes a
-- global — which is how the panel asks whether there are icons at all.
require("mini.icons").setup()

vim.cmd "runtime plugin/plenary.vim"
