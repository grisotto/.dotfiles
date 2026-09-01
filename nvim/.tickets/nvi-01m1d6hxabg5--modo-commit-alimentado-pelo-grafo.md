---
id: nvi-01m1d6hxabg5
title: Modo commit alimentado pelo grafo
status: open
type: task
priority: 3
mode: afk
created: '2026-09-01T00:40:23.110946420Z'
updated: '2026-09-01T00:40:23.110946420Z'
assignee: grisotto
parent: nvi-01m1d62bd8hq
tags:
- git
- review
acceptance:
- title: O grafo mostra os commits de todas as branches
  done: false
- title: Escolher um commit troca o modo do painel mantendo seções e teclas
  done: false
- title: O cabeçalho identifica o commit em revisão
  done: false
- title: Uma tecla volta do modo commit para o working tree
  done: false
- title: O diff das linhas funciona no modo commit
  done: false
- title: Conteúdo visto no modo commit aparece visto no working tree quando o texto é o mesmo
  done: false
deps:
- nvi-01m1d6hw839c
- nvi-01m1d6hwc7f9
---

## Description

### O que construir

Um grafo com os commits de todas as branches. Escolher um commit ali troca o modo do painel: em vez do working tree, ele passa a listar os arquivos daquele commit, com as mesmas seções e exatamente as mesmas teclas. O cabeçalho identifica o commit em revisão, e uma tecla volta ao working tree.

É o painel único com modo (ADR-0001): não abre um segundo painel nem uma aba dedicada.

### O que se verifica de graça aqui

Como o visto é chaveado pelo conteúdo (ADR-0002), um conteúdo já visto revisando um commit aparece visto no working tree quando for o mesmo texto. Esta fatia é onde esse comportamento se torna observável.
