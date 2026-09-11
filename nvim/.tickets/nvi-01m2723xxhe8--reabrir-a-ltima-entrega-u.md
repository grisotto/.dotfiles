---
id: nvi-01m2723xxhe8
title: Reabrir a última entrega (U)
status: open
type: task
priority: 2
mode: afk
created: '2026-09-11T01:43:05.896993097Z'
updated: '2026-09-11T01:43:06.025892388Z'
assignee: grisotto
parent: nvi-01m271x0rry4
tags:
- git
- review
acceptance:
- title: U devolve as anotações da última entrega a abertas e tira a entrega do histórico
  done: false
- title: Sem entrega no modo, U avisa
  done: false
- title: Colisão com anotação aberta no mesmo ponto recusa e nomeia o ponto
  done: false
- title: U no menu, no which-key e na ajuda do painel
  done: false
deps:
- nvi-01m2723xn2ga
---

## Parent

nvi-01m271x0rry4

## What to build

O revisor gerou o relatório, não mandou, e percebeu um erro ou uma anotação esquecida. Ele aperta `U` no painel: a última entrega do modo sai do histórico e as anotações dela voltam a abertas, prontas para editar e gerar de novo. Sem entrega no modo, `U` avisa. Se uma anotação da entrega cai no mesmo ponto de uma anotação aberta escrita depois, a reabertura é recusada com um aviso que nomeia o ponto. `U` aparece no menu de contexto, no which-key e na ajuda do painel. README: tecla e roteiro manual.

Veja a spec: histórias 61 e 67 e a decisão "Reabrir (`U`)"; ADR-0012.

## Blocked by

- nvi-01m2723xn2ga