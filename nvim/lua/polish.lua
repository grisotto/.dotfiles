-- This will run last in the setup process.
-- This is just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

-- dedicated venv for the Python3 provider (pynvim), managed with uv
vim.g.python3_host_prog = vim.fn.expand "~/.local/share/nvim-venv/bin/python"

-- Painel de revisão (lua/review/). O setup também mapeia as teclas de anotar
-- (`<Leader>ga`/`<Leader>gA`, trocáveis em `mappings.annotate_line` e
-- `mappings.annotate_line_long`); os outros atalhos globais estão em
-- lua/plugins/review.lua.
require("review").setup {
  position = "left",
  width = 40,
  -- "section" põe os vistos numa seção recolhida no fim; "dimmed" deixa cada um
  -- esmaecido onde ele está. As duas existem para serem comparadas no uso.
  seen_display = "section",
  -- O estado em que o painel abre: ligado, que é escolha deste revisor. O padrão
  -- do plugin é desligado — quem desce a lista está quase sempre a caminho de um
  -- arquivo só, e a varredura paga a leitura de todos por onde passa. Aqui a
  -- lista abre já mostrando o diff da linha, e `p` desliga quando começa a
  -- leitura de verdade.
  preview = true,
  neo_tree = "close", -- fecha o neo-tree ao abrir, para não disputarem o espaço
}
