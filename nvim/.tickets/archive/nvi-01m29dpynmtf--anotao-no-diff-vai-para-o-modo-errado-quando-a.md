---
id: nvi-01m29dpynmtf
title: Anotação no diff vai para o modo errado quando a lista sai da tela
status: closed
type: bug
priority: 1
mode: afk
created: '2026-09-11T23:44:12.468702503Z'
updated: '2026-09-12T00:18:08.187415168Z'
closed: '2026-09-12T00:18:08.187415168Z'
assignee: grisotto
tags:
- git
acceptance:
- title: Anotar o lado de depois do diff de um commit com close_on_diff ligado grava a anotação no modo do commit, e o R a leva no relatório
  done: true
- title: 'O mesmo no intervalo: a anotação fica no modo do intervalo'
  done: true
- title: <Leader>gv de dentro do diff, com a lista fora da tela, marca como visto e abre a próxima
  done: true
- title: Anotar o arquivo de hoje, aberto com go em modo commit, continua recusado apontando o <C-o>, com a lista fora da tela
  done: true
- title: A lista fechada pelo revisor, sem diff na tela, continua não respondendo pelo modo nem pelo repositório
  done: true
- title: make lint com 0 erros e 0 avisos, e make test sem spec falha ou com erro
  done: true
links:
- nvi-01m1d6164sz2
external_refs:
- git:fb972f08191cc1361e157dafd54faa249f88892f
---

## Description

Com `close_on_diff = true` (a configuração deste revisor, `lua/polish.lua:27`), entrar no diff de uma linha tira o painel da tela. `panel.mode()` e `panel.repository()` só respondem enquanto a lista está na tela (`panel.lua:704-707` e `177-180`: `local panel = M.win() and current()`), então a tecla global de anotar, apertada dentro do diff, recebe `WORKTREE`.

A anotação é gravada com `mode = "worktree"` e `version` = o sha do commit, que veio do lado do diff: um registro contraditório. Para apertar `R` o painel volta e o modo volta a ser `commit-<sha>`; `state.deliver` filtra por `annotation.mode == mode` e não acha nada — "review: nenhuma anotação nesta revisão para relatar".

Reproduzido headless com a configuração real (docs/agents/debugging.md):

    == depois de entrar no diff (close_on_diff) ==
      painel na tela: false
      panel.mode(): worktree    <-- o modo que a anotação vai receber
      panel.repository(): nil
    == o que ficou gravado ==
      path=a.txt mode=worktree line=2 version=9b6d12bd7efe...
      commit esperado: commit-9b6d12bd7efe...
    == de volta ao painel, e o R ==
      R disse: review: nenhuma anotação nesta revisão para relatar.

Duas outras faces da mesma raiz:

- `<Leader>gv` de dentro do diff, com a lista fora da tela, responde "a revisão não está em nenhuma linha do painel": `target_under_cursor` exige `M.win()` (`panel.lua:711-718`). É a falha que o `]f`/`[f` já teve e que virou a atualização do ADR-0009; lá o conserto existe (`place_of_the_diff`), aqui ficou de fora.
- Anotar o arquivo de hoje (aberto com `go`) em modo commit deveria ser recusado apontando o `<C-o>`; com a lista fora da tela o modo lido é `worktree` e a anotação é aceita, virando uma anotação de working tree sobre um arquivo que o revisor está lendo no commit.

Conserto: o painel passa a responder pelo modo e pelo repositório também quando a lista saiu da tela mas a revisão está na tela — a lista que o diff de uma linha dela tirou dali (ADR-0009: a revisão anda com a lista fechada). A lista que o revisor fechou por conta própria, sem diff nenhum na tela, continua não respondendo: é a razão pela qual a restrição existe (`:tcd` noutro repositório com o painel fechado).

Por que a suíte está verde: `annotation_spec.lua:412-457` anota no diff de commit com `close_on_diff` desligado, e `close_on_diff_spec.lua` nunca anota nem aperta `<Leader>gv`. Nenhum teste cruza os dois.

## Notes

**2026-09-11T23:51:17.713511549Z**

Conserto aplicado e confirmado no ambiente do revisor, com a reprodução headless da configuração real (docs/agents/debugging.md).

Antes:

    == depois de entrar no diff (close_on_diff) ==
      panel.mode(): worktree
      panel.repository(): nil
      gravado: mode=worktree version=9b6d12bd7efe...
    == <Leader>gv ==
      disse: review: a revisão não está em nenhuma linha do painel; escolha uma para marcar.
    == R ==
      disse: review: nenhuma anotação nesta revisão para relatar.

Depois:

    == depois de entrar no diff (close_on_diff) ==
      panel.mode(): commit-9b6d12bd7efe...
      panel.repository(): /.../repo
      gravado: mode=commit-9b6d12bd7efe... version=9b6d12bd7efe...
    == <Leader>gv ==
      disse: (nada) — marcou e abriu a próxima
    == R ==
      disse: review: relatório com 1 anotação copiado; gravado em ...-commit-9b6d12bd7efe....xml

O que mudou, em `lua/review/panel.lua`: um `reviewing()` responde qual painel desta aba responde pela revisão — o que está na tela, e o que teve a tela tomada pelo diff de uma linha sua (`hidden_for_diff` ou `diff.showing()`); `mode()` e `repository()` passam a sair dele. E `target_under_cursor` cai para a entrada de que o diff foi montado quando não há lista na tela, que é o mesmo que `step` já fazia, o que conserta o `<Leader>gv`.

Uma armadilha no caminho, que a suíte pegou: escrever esse fallback como `win and entry_by_line[...] or diff.showing()` quebra 38 specs — num cabeçalho o índice é nil e a expressão cai no `or`, fazendo a tecla agir sobre o arquivo ao lado a partir de uma linha de que o revisor saiu de propósito. Ficou um `if` escrito por extenso, com o comentário do porquê.

Suíte em 439 specs (eram 433; 6 novos em tests/review/close_on_diff_spec.lua), make lint 0 erros e 0 avisos. ADR-0009 ganhou a atualização "o modo e o repositório também são do painel que saiu da tela".

**2026-09-12T00:18:08.187415168Z**

O modo e o repositório passam a vir do painel que o diff tirou da tela: a anotação escrita no lado de depois do diff de um commit fica no modo daquele commit, e o R a leva no relatório. O <Leader>gv volta a marcar como visto e abrir a próxima com a lista fora da tela, e o arquivo de hoje aberto com go continua recusado. A lista fechada sem diff na tela segue não respondendo, que é a razão da restrição. Confirmado com a reprodução headless da configuração real, além dos seis testes novos.
