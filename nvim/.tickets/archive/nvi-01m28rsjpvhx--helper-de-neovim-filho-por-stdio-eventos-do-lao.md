---
id: nvi-01m28rsjpvhx
title: 'Helper de Neovim filho por stdio: eventos do laço com tecla de verdade'
status: closed
type: task
priority: 2
mode: afk
created: '2026-09-11T17:38:38.427222444Z'
updated: '2026-09-11T18:25:24.987817791Z'
closed: '2026-09-11T18:25:24.987817791Z'
assignee: grisotto
tags:
- testing
- review
acceptance:
- title: child.lua sobe o filho com o minimal_init, manda teclas por nvim_input, lê o estado e o encerra
  done: true
- title: O preview segue o cursor da lista por tecla no filho, sem disparar CursorMoved à mão, em ao menos um teste
  done: true
- title: A largura adotada do painel vem de WinResized disparado por tecla no filho, em ao menos um teste
  done: true
- title: 'testing.md atualizado: os eventos do laço saem do que fica sem teste'
  done: true
- title: make format, make lint sem avisos e make test verdes
  done: true
---

## Description

Um helper `tests/helpers/child.lua` que sobe um Neovim filho com `jobstart({nvim, '--embed', '--headless', '--noplugin', '-u', 'tests/minimal_init.lua'}, {rpc = true})`, manda teclas por `nvim_input`, lê o estado por `nvim_exec_lua` e encerra o filho no `after_each`. Fala por stdin/stdout, sem socket.

Hoje os eventos que só o laço principal dispara são disparados à mão na suíte: `CursorMoved` por `panel.move`/`panel.cursor_moved` e `WinResized` por `doautocmd` (veja "O que fica sem teste, deliberadamente" em `docs/agents/testing.md`). No filho, tecla mandada por `nvim_input` disparou `CursorMoved` e `WinResized` (experimento E9), e a mesma tecla por `nvim_feedkeys(…, 'x')` não disparou.

Cuidados, da pesquisa:
- `<` solto em `nvim_input` deixa o filho esperando tecla; é `<LT>` (E10).
- Consultar `nvim_get_mode().blocking` antes de pedidos deferred, que travam com o editor esperando entrada modal.
- Não chamar `vim.rpcrequest` dentro do callback de `vim.wait`: consultar num laço de `vim.wait(20)`.
- O filho herda o ambiente do processo: conferir que o `XDG_DATA_HOME` e o `XDG_CONFIG_HOME` do fixture chegam a ele, ou passá-los em `env`.
- `VimResized` pede uma UI que muda de tamanho (`nvim_ui_try_resize`) e fica fora deste ticket.

Veja `docs/research/rodar-o-neovim-como-agente.md`, §2.3 e §5.1 item 2.
