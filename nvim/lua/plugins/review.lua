-- Atalhos do painel de revisão (o plugin em si vive em `lua/review/`).
--
-- `<Leader>r` é o atalho curto de abertura. Ele está livre nesta configuração
-- hoje, mas é reivindicado pelo `astrocommunity.editing-support.refactoring-nvim`,
-- que não está importado: se ele entrar um dia, os dois colidem.
--
-- Não há atalho de revisão dentro do grupo `<Leader>g`: o gitsigns já ocupa as
-- letras óbvias com mapeamentos *locais ao buffer*, que ganham do global em
-- qualquer arquivo rastreado — `<Leader>gr` é "Reset Git hunk" e `<Leader>gR`
-- é "Reset Git buffer". Um mapa global nesses lhs não abriria o painel; ele
-- ficaria inerte justamente onde a revisão acontece, e o revisor descartaria
-- um hunk achando que estava abrindo o painel. O grupo de revisão entra quando
-- houver um conjunto de ações para pendurar nele, num lhs verificado com
-- `nvim_buf_get_keymap` (o `nvim_get_keymap` só enxerga os globais).
--
-- As opções do painel ficam em `lua/polish.lua`.

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    mappings = {
      n = {
        ["<Leader>r"] = { function() require("review").toggle() end, desc = "Painel de revisão" },
      },
    },
  },
}
