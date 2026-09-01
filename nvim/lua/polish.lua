-- This will run last in the setup process.
-- This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

-- dedicated venv for the Python3 provider (pynvim), managed with uv
vim.g.python3_host_prog = vim.fn.expand "~/.local/share/nvim-venv/bin/python"

-- Painel de revisão (lua/review/). Atalhos em lua/plugins/review.lua.
require("review").setup {
  position = "left",
  width = 40,
  -- "section" põe os vistos numa seção recolhida no fim; "dimmed" deixa cada um
  -- esmaecido onde ele está. As duas existem para serem comparadas no uso.
  seen_display = "section",
  neo_tree = "close", -- fecha o neo-tree ao abrir, para não disputarem o espaço
}
