---
id: nvi-01m28rs8h77r
title: 'Helper de tela na suíte: afirmar sobre o que só aparece composto'
status: open
type: task
priority: 2
mode: afk
created: '2026-09-11T17:38:28.006981632Z'
updated: '2026-09-11T17:38:28.006981632Z'
assignee: grisotto
tags:
- testing
- review
acceptance:
- title: screen.lua devolve as linhas da tela depois de um giro do laço e de um redraw, flutuantes incluídas
  done: false
- title: lines e columns fixos no minimal_init
  done: false
- title: Ao menos um spec afirma sobre algo composto que a leitura de buffer não mostra
  done: false
- title: testing.md descreve a tela como observável da costura
  done: false
- title: make format, make lint sem avisos e make test verdes
  done: false
---

## Description

Um helper `tests/helpers/screen.lua` que lê a tela do editor de teste como o revisor a vê: dá um giro do laço (`vim.wait`), faz `vim.cmd.redraw()`, devolve as linhas da tela por `screenstring()` e compara células por `screenattr()`. É a técnica do `child.get_screenshot` do mini.test, sem dependência nova e dentro da costura que a suíte já tem.

Serve para o que nenhuma leitura de buffer mostra: a janela de ajuda por cima do painel, a borda e o título da entrada longa, a winbar truncada numa janela estreita, o `+N −M` como ele cai na célula.

Cuidados, da pesquisa:
- `lines` e `columns` fixos no `tests/minimal_init.lua`, para a tela não depender da máquina (o mini.test fixa 24×80).
- Os specs rodam de dentro de `-c`, antes do `VimEnter`, e lá o primeiro `:redraw` desenhou uma flutuante no lugar errado; giro do laço e redraw sempre (experimento E1).
- `screenattr()` só diz se duas células têm o mesmo atributo; o grupo de destaque continua lido pelos helpers de hoje (`panel.highlights`).

Veja `docs/research/rodar-o-neovim-como-agente.md`, §2.1 e §5.1 item 1.
