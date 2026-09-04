-- Atalhos do painel de revisão (o plugin em si vive em `lua/review/`).
--
-- `<Leader>r` é o atalho curto de abertura. Ele está livre nesta configuração
-- hoje, mas é reivindicado pelo `astrocommunity.editing-support.refactoring-nvim`,
-- que não está importado: se ele entrar um dia, os dois colidem.
--
-- Dentro do grupo `<Leader>g` ficam as ações de revisão que não são de uma
-- linha do painel: anotar a linha que está sendo lida e marcar como visto o
-- arquivo que está sendo lido. Elas são globais, e no grupo `<Leader>g` há
-- letras que *parecem* livres e não estão: o gitsigns ocupa as óbvias com
-- mapeamentos locais ao buffer, que ganham do global em qualquer arquivo
-- rastreado — `<Leader>gr` é "Reset Git hunk" e `<Leader>gR`
-- é "Reset Git buffer". Um mapa global nesses lhs ficaria inerte justamente
-- onde a revisão acontece, e o revisor descartaria um hunk achando que estava
-- anotando.
--
-- `<Leader>ga`, `<Leader>gA` e `<Leader>gv` foram conferidos com
-- `nvim_buf_get_keymap` num arquivo rastreado desta configuração (o
-- `nvim_get_keymap` só enxerga os globais): livres nos dois lados. Ocupados hoje
-- estão `gg`, `gb`, `gc`, `gC`, `gt`, `gT`, `go` e o grupo `gn` do neogit, mais
-- os locais do gitsigns (`gl`, `gL`, `gp`, `gr`, `gR`, `gs`, `gS`, `gd`).
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
        -- A tecla simples é a anotação de uma frase, que é quase toda anotação
        -- de revisão; a shifted abre a entrada de várias linhas. O mesmo par
        -- que o painel tem em `a` e `A` para a anotação de arquivo.
        ["<Leader>ga"] = { function() require("review").annotate() end, desc = "Anotar a linha" },
        ["<Leader>gA"] = {
          function() require("review").annotate { long = true } end,
          desc = "Anotar a linha em várias linhas",
        },
        -- O `<Space>` do painel, de dentro do arquivo que está sendo lido: `v`
        -- é a letra do visto, como no painel, e não pode ser a tecla solta aqui
        -- — dentro de um arquivo ela é o modo visual.
        ["<Leader>gv"] = {
          function() require("review").seen_and_next() end,
          desc = "Marcar como visto e abrir a próxima não vista",
        },
      },
    },
  },
}
