---
id: nvi-01m1d6hxeg2b
title: Filtro por branch e intervalo de commits
status: open
type: task
priority: 3
mode: afk
created: '2026-09-01T00:40:23.245789612Z'
updated: '2026-09-01T00:40:23.245789612Z'
assignee: grisotto
parent: nvi-01m1d62bd8hq
tags:
- git
- review
acceptance:
- title: Escolher uma branch numa busca reabre o grafo restrito a ela
  done: false
- title: Selecionar um intervalo lista os arquivos do intervalo inteiro
  done: false
- title: O cabeçalho identifica o intervalo em revisão
  done: false
- title: As teclas do painel funcionam igual no modo intervalo
  done: false
deps:
- nvi-01m1d6hxabg5
---

## Description

### O que construir

Escolher uma branch numa busca reabre o grafo restrito a ela, para não procurar o commit no meio de tudo. O filtro é obtido reabrindo o grafo já restrito, e não por uma funcionalidade do plugin de grafo, que não expõe filtro por branch.

Selecionar um intervalo de commits, e não só um, faz o painel listar os arquivos do intervalo inteiro — o gesto de revisar uma feature completa de uma vez. O cabeçalho identifica o intervalo.
