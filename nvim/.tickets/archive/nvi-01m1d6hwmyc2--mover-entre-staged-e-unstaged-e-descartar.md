---
id: nvi-01m1d6hwmyc2
title: Mover entre staged e unstaged, e descartar
status: closed
type: task
priority: 1
mode: afk
created: '2026-09-01T00:40:22.428507823Z'
updated: '2026-09-01T13:01:02.328562614Z'
closed: '2026-09-01T13:01:02.328562614Z'
assignee: grisotto
parent: nvi-01m1d61ppxj1
tags:
- git
- review
acceptance:
- title: Uma tecla move o arquivo para staged e o painel reflete
  done: true
- title: Uma tecla tira o arquivo de staged e o painel reflete
  done: true
- title: Descartar pede confirmação antes e só age depois dela
  done: true
- title: Descartar trata untracked, unstaged e staged de forma correta para cada caso
  done: true
- title: O painel se atualiza sozinho ao salvar um arquivo e ao o editor voltar ao foco
  done: true
- title: As ações refletem no estado real do repositório, verificado pela saída do git
  done: true
deps:
- nvi-01m1d6hw44g6
---

## Description

### O que construir

Três teclas no painel: uma move o arquivo para staged, outra tira de staged, e a terceira descarta as mudanças do arquivo — esta com confirmação antes, porque perde trabalho.

Depois de cada uma, o painel se atualiza e passa a mostrar o novo estado. O painel também se atualiza sozinho quando um arquivo é salvo ou quando o editor volta ao foco, para nunca mostrar uma lista velha.

### Fronteira

O commit em si continua no neogit (ADR-0005): mensagem, amend, hooks e rebase não entram aqui. O painel implementa apenas mover arquivo entre staged e unstaged e descartar, que é o gesto central da revisão e são chamadas diretas ao git.
