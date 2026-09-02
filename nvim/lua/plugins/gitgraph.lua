-- O grafo de commits alternativo (o painel de revisão vive em `lua/review/`).
--
-- São dois grafos ligados ao mesmo tempo, em teclas diferentes, pelo mesmo
-- motivo que o diff tem duas apresentações e o conflito três (ADR-0006): o
-- painel desenha o seu, ao lado da lista, com `C` este aqui desenha o mesmo
-- histórico do jeito dele, e os dois terminam no mesmo lugar — `review.commit`,
-- que troca o modo do painel. O que está sendo comparado é o desenho e o gesto,
-- não duas revisões diferentes.
--
-- O plugin ainda está em desenvolvimento e não expõe filtro por branch: o
-- filtro sai de reabrir o grafo já restrito à branch, e por isso ele existe só
-- no grafo do painel — este aqui é desenhado por uma chamada nossa, mas quem o
-- reabre é ele mesmo.
--
-- O hook fica aqui, e não em `lua/review/graph.lua`, porque quem o recebe é o
-- `setup` do plugin: o grafo é desenhado por uma chamada e responde por outra.

-- Sem o `keys` que o README dele sugere (`<Leader>gl`): a porta de entrada
-- aqui é a tecla do painel, e `gl` é do gitsigns ("Blame line"), local ao
-- buffer de qualquer arquivo rastreado — um mapa global nesse lhs ficaria
-- inerte justamente onde a revisão acontece.

---@type LazySpec
return {
  "isakbm/gitgraph.nvim",
  -- Carregado quando o painel pede, e não na abertura do editor: quem abre o
  -- grafo é uma tecla dentro da revisão.
  lazy = true,
  opts = {
    format = {
      timestamp = "%d/%m/%Y",
      fields = { "hash", "timestamp", "author", "branch_name", "tag" },
    },
    hooks = {
      ---Escolher um commit aqui é o mesmo que escolhê-lo no grafo do painel.
      ---@param commit { hash: string }
      on_select_commit = function(commit) require("review").commit(commit.hash) end,
      ---Selecionar um intervalo aqui é o mesmo que selecioná-lo no grafo do
      ---painel. O plugin entrega as pontas na ordem em que a revisão as espera:
      ---ele lê a seleção pelas marcas `'<` e `'>`, então `from` é sempre a linha
      ---de baixo — o commit mais antigo, porque o grafo é desenhado do mais novo
      ---para o mais velho — seja qual for o sentido em que a seleção foi feita.
      ---@param from { hash: string } o commit mais antigo do intervalo
      ---@param to { hash: string } o mais novo
      on_select_range_commit = function(from, to) require("review").range(from.hash, to.hash) end,
    },
  },
}
