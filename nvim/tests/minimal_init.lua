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
-- Where the plugins are is decided once, by the editor the suite starts in, and
-- left in the environment for the editors started from it: the one per spec
-- file, and the child a test starts (`tests/helpers/child.lua`). A child
-- inherits the environment of that test, and a test that moved the data
-- directory (`fixture.data_dir`) would send it looking for the plugins under an
-- empty one.
vim.env.REVIEW_SUITE_PLUGINS = vim.env.REVIEW_SUITE_PLUGINS or vim.fn.stdpath "data" .. "/lazy"
local lazy = vim.env.REVIEW_SUITE_PLUGINS

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

-- The size of the screen the specs read (`tests/helpers/screen.lua`), and the
-- one every width in the panel is taken from. Fixed so that neither depends on
-- the machine the suite runs on; 24×80 is what mini.test fixes too.
vim.o.lines = 24
vim.o.columns = 80

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
