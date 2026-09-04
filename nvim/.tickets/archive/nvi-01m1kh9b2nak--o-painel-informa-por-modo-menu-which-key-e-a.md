---
id: nvi-01m1kh9b2nak
title: 'O painel informa por modo: menu, which-key e a linha do próximo passo'
status: closed
type: feature
priority: 2
mode: afk
created: '2026-09-03T11:43:23.221833517Z'
updated: '2026-09-03T19:16:54.963103728Z'
closed: '2026-09-03T19:16:54.963103728Z'
assignee: grisotto
parent: nvi-01m1j8zy1rqj
tags:
- git
- review
- plugin-local
acceptance:
- title: No modo commit, stage, unstage e descartar não aparecem no menu de contexto nem no which-key
  done: true
- title: Essas três teclas seguem mapeadas e seguem respondendo com a recusa que aponta o w
  done: true
- title: No working tree as três seguem no menu e no which-key como hoje
  done: true
- title: 'Com tudo visto, o painel diz o próximo passo do modo: neogit no working tree, relatório no commit'
  done: true
- title: A linha do próximo passo aparece no lugar onde hoje só apareceria Nenhuma mudança.
  done: true
external_refs:
- git:249c3ef
---

## Description

As duas metades do "o painel informa por modo" que não tocam o cabeçalho.

### 1. Menu e which-key sabem em que modo estão

No modo commit, `s`, `u` e `X` **saem do menu de contexto e do which-key** — ficam mapeadas, sem descrição, para que quem apertar por hábito receba a recusa explicativa que já existe e aponta o `w`. Um menu que oferece o que vai ser recusado é pior do que não ter menu.

O filtro é do modo, e sai da mesma lista de sempre (`panel_actions`, ADR-0008): menu e teclas continuam saindo de uma lista só, e o que muda é quais entradas dela carregam descrição.

### 2. A linha do próximo passo

Quando tudo está visto, no lugar onde hoje só apareceria "Nenhuma mudança.", o painel diz o que fazer agora:

- working tree: commitar no neogit (`<Leader>gnc`)
- commit e intervalo: gerar o relatório (`R`)

É o "fim" da revisão sem inventar um estado: nada é iniciado, nada é finalizado, nada é arquivado. O visto continua sendo do conteúdo (ADR-0002) e continua atravessando modos.

## Notes

**2026-09-03T19:16:54.963103728Z**

No modo commit, s/u/X saem do menu e do which-key e seguem mapeadas com a recusa que aponta o w; o filtro sai do próprio panel_actions. As ações passaram a ser repostas a cada draw, e o menu global só pelo painel focado. Linha do próximo passo com tudo visto: neogit no working tree, relatório no commit. 6 testes novos em commit_spec e seen_spec.
