---
id: nvi-01m1d6hx62xh
title: Terceiro modo de visualização de conflito, no painel
status: open
type: task
priority: 2
mode: afk
created: '2026-09-01T00:40:22.975626480Z'
updated: '2026-09-01T00:40:22.975626480Z'
assignee: grisotto
parent: nvi-01m1d6216yyq
tags:
- git
- review
acceptance:
- title: Uma tecla abre o conflito na aba do painel, a partir dos três estágios do índice
  done: false
- title: As três versões aparecem simultaneamente e a lista do painel continua visível
  done: false
- title: As outras duas apresentações de conflito continuam funcionando, inalteradas
  done: false
deps:
- nvi-01m1d6hw839c
---

## Description

### O que construir

Uma terceira apresentação de conflito, construída na própria aba do painel a partir dos três estágios do índice — base, nossa versão e a que está entrando — para o revisor comparar com os dois layouts do merge tool do diffview antes de fixar um padrão (ADR-0006).

Diferente das outras duas, esta não troca de aba: a lista continua visível ao lado.

### Fronteira

Esta fatia entrega visualização. Escolher lado e navegar entre conflitos continuam sendo do diffview (ADR-0005) — reimplementá-los está fora de escopo na spec.

### Nota

As três teclas de conflito são propositalmente redundantes e temporárias. Apagar as perdedoras depois é uma linha cada, mas é decisão do revisor, não limpeza automática.
