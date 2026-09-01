---
id: nvi-01m1d6hws3y2
title: Mouse e descoberta das ações
status: open
type: task
priority: 1
mode: afk
created: '2026-09-01T00:40:22.557537908Z'
updated: '2026-09-01T00:40:22.557537908Z'
assignee: grisotto
parent: nvi-01m1d61ppxj1
tags:
- git
- review
acceptance:
- title: Clique esquerdo numa linha abre o diff daquele arquivo
  done: false
- title: Clique direito abre um menu de contexto com as ações do painel
  done: false
- title: Cada entrada do menu mostra a ação e o atalho correspondente
  done: false
- title: O menu some ao sair do painel e não polui o menu de contexto de outros buffers
  done: false
- title: As teclas do painel aparecem no which-key com descrição
  done: false
deps:
- nvi-01m1d6hw839c
- nvi-01m1d6hwc7f9
- nvi-01m1d6hwge5g
- nvi-01m1d6hwmyc2
---

## Description

### O que construir

Clique esquerdo numa linha do painel abre o diff daquele arquivo. Clique direito abre um menu de contexto cujas entradas mostram a ação e, ao lado, o atalho de teclado correspondente — que é como o revisor descobre o que dá para fazer sem consultar documentação.

O modelo de mouse passa a ser o de menu de contexto globalmente, e não só dentro do painel. É uma decisão consciente: o botão direito passa a ter o mesmo comportamento em todo o editor, como em qualquer outro editor.

As descrições das teclas do painel alimentam o which-key, para a descoberta pelo teclado sair de graça.

### Por que depende das outras quatro

O menu enumera as ações das fatias de diff, visto, caminhos e staged/unstaged. Feito antes delas, nasceria incompleto e precisaria ser reaberto a cada fatia.
