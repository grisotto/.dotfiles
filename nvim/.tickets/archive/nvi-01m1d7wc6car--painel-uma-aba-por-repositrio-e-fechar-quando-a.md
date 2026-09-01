---
id: nvi-01m1d7wc6car
title: 'Painel: uma aba por repositório e fechar quando é a única janela'
status: closed
type: bug
priority: 3
mode: afk
created: '2026-09-01T01:03:34.604766731Z'
updated: '2026-09-01T11:53:56.080087050Z'
closed: '2026-09-01T11:53:56.080087050Z'
assignee: grisotto
parent: nvi-01m1d61ppxj1
tags:
- git
- review
---

## Description

Dois achados de baixa severidade da revisão de código da primeira fatia (nvi-01m1d6hw44g6), deixados fora dela de propósito.

**Buffer único entre abas.** `state.bufnr` é global ao módulo, mas `M.win()` procura a janela só na aba atual. Com duas abas em repositórios diferentes (`:tcd` por aba), abrir ou atualizar o painel na aba 2 reescreve o mesmo buffer e o painel da aba 1 passa a mostrar o repositório da aba 2 — inclusive o mapa de linha para entrada, que vai apontar para as entradas do repositório errado quando as ações de linha existirem. O painel único é decisão de desenho (ADR-0001), mas o painel único *por aba* mostrando conteúdo de outra aba não é.

**Fechar quando é a única janela.** `M.close()` engole a falha do `nvim_win_close` num `pcall`. Quando o painel é a única janela da aba o fechamento falha, `M.is_open()` continua dizendo que está aberto, e tanto o `q` de dentro do painel quanto o `<Leader>r` viram no-op silencioso — o `toggle()` fica preso no ramo de fechar.
