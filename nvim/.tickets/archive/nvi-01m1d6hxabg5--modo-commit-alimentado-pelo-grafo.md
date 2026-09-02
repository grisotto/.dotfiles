---
id: nvi-01m1d6hxabg5
title: Modo commit alimentado pelo grafo
status: closed
type: task
priority: 3
mode: afk
created: '2026-09-01T00:40:23.110946420Z'
updated: '2026-09-01T19:58:05.288951733Z'
closed: '2026-09-01T19:58:05.288951733Z'
assignee: grisotto
parent: nvi-01m1d62bd8hq
tags:
- git
- review
acceptance:
- title: O grafo mostra os commits de todas as branches
  done: true
- title: Escolher um commit troca o modo do painel mantendo seções e teclas
  done: true
- title: O cabeçalho identifica o commit em revisão
  done: true
- title: Uma tecla volta do modo commit para o working tree
  done: true
- title: O diff das linhas funciona no modo commit
  done: true
- title: Conteúdo visto no modo commit aparece visto no working tree quando o texto é o mesmo
  done: true
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

## Notes

**2026-09-01T19:46:18.432331470Z**

Dois grafos, e não um: o desenhado pelo painel (git log --graph --all, ao lado da lista, tecla c) e o do gitgraph (tecla C). A épica previa só o plugin; a decisão de ligar os dois é o padrão do ADR-0006, e foi do revisor. Os dois terminam em review.commit(sha), então o modo commit tem um caminho só.

Os arquivos de um commit vêm de git diff-tree -r --raw, e não de --name-status: o formato raw nomeia o objeto de cada lado, e o objeto da direita é a chave do visto (ADR-0002). É isso que faz o visto atravessar os modos sem nenhum hash-object a mais.

--diff-merges=first-parent para os merges: sem isso um merge lista vazio, e com -m --first-parent lista cada arquivo duas vezes (uma por pai).

O modo deixou de ser a constante "worktree" dentro de annotation.lua e passou a ser um valor que viaja (lua/review/mode.lua), como o próprio módulo já previa: anotação, contagem na linha e relatório são de um modo só.

**2026-09-01T19:58:05.288951733Z**

Modo commit no painel, alimentado por dois grafos (o nosso e o do gitgraph) que terminam na mesma chamada. Os seis critérios de aceite estão cobertos por tests/review/commit_spec.lua; a delegação ao gitgraph fica sem teste, como a do diffview (ADR-0005). O plugin novo só existe depois de um :Lazy sync — até lá a tecla C avisa.
