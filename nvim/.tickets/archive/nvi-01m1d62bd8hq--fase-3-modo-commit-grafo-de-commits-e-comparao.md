---
id: nvi-01m1d62bd8hq
title: 'Fase 3: modo commit, grafo de commits e comparação com outro rev'
status: closed
type: feature
priority: 3
mode: afk
created: '2026-09-01T00:31:53.255613349Z'
updated: '2026-09-03T20:17:05.165782539Z'
closed: '2026-09-03T20:17:05.165782539Z'
assignee: grisotto
parent: nvi-01m1d6164sz2
tags:
- git
- review
acceptance:
- title: Grafo mostra commits de todas as branches e aceita filtro por branch
  done: true
- title: Selecionar um commit troca o modo do painel mantendo seções e teclas
  done: true
- title: Cabeçalho identifica o commit ou intervalo em revisão
  done: true
- title: Seleção de intervalo lista os arquivos do intervalo
  done: true
- title: Uma tecla volta do modo commit para o working tree
  done: true
- title: Ver arquivo em outro rev abre em buffer somente leitura e volta facilmente
  done: true
- title: Comparar com outro rev abre o diff contra a versão escolhida
  done: true
- title: O rev é escolhido numa busca que lista branches e commits daquele arquivo
  done: true
- title: Visto marcado no modo commit vale no working tree quando o conteúdo é o mesmo
  done: true
deps:
- nvi-01m1d6216yyq
---

## Description

Cobre as user stories 49-58 da spec do épico.

### Entregável

Grafo com os commits de todas as branches, e filtro por branch escolhido numa busca — obtido reabrindo o grafo restrito à branch, já que o plugin de grafo não expõe filtro próprio. Selecionar um commit troca o modo do painel: mesmas seções, mesmas teclas, cabeçalho identificando o commit; seleção de intervalo lista os arquivos do intervalo. Voltar ao working tree com uma tecla. Ver um arquivo como ele está em outro commit ou branch, e comparar o arquivo atual com a versão de outro rev, com o rev escolhido numa busca que lista branches e os commits daquele arquivo.

### Nota

O visto atravessa os modos por construção, já que é chaveado pelo conteúdo (ADR-0002): conteúdo visto num commit aparece visto no working tree.

## Notes

**2026-09-03T20:17:05.165782539Z**

Fase 3 entregue pelos tickets filhos; suíte verde (317 testes) e os 9 critérios verificados.
