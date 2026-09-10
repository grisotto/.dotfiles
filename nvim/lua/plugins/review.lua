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
-- As duas de anotar (`<Leader>ga` e `<Leader>gA`, no modo normal e no visual)
-- não estão aqui: quem as mapeia é o `setup` do plugin, chamado em
-- `lua/polish.lua`, a partir das opções (`mappings.annotate_line` e
-- `mappings.annotate_line_long`). A winbar do diff escreve essas mesmas teclas,
-- e as duas saírem das opções no mesmo momento é o que as impede de divergir.
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
