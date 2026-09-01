---
id: nvi-01m1d6hx1mma
title: Relatório de revisão e quickfix
status: open
type: task
priority: 2
mode: afk
created: '2026-09-01T00:40:22.834763965Z'
updated: '2026-09-01T00:40:22.834763965Z'
assignee: grisotto
parent: nvi-01m1d6216yyq
tags:
- git
- review
acceptance:
- title: Um atalho gera o documento agrupado por arquivo
  done: false
- title: Cada anotação sai com caminho, linha e o trecho de código citado
  done: false
- title: O documento é gravado fora do repositório revisado
  done: false
- title: O relatório contém apenas as anotações do modo atual
  done: false
- title: A geração popula a quickfix com os pontos anotados
  done: false
- title: Anotação cuja linha mudou é reancorada pela âncora
  done: false
- title: Anotação cuja âncora não é encontrada sai marcada como deslocada, em seção própria
  done: false
deps:
- nvi-01m1d6hwxd9p
---

## Description

### O que construir

Um atalho gera o relatório de revisão: um documento markdown com as anotações agrupadas por arquivo, cada uma com o caminho, a linha e o trecho de código citado, para quem lê entender sem abrir o repositório. É gravado fora do repositório revisado, e contém apenas as anotações do modo atual — o documento é sobre a revisão que está acontecendo agora.

Ao mesmo tempo, a geração popula a quickfix com os pontos anotados, para o revisor percorrer as próprias observações dentro do editor sem reabrir nada.

### Reancoragem

É aqui que a âncora é usada (ADR-0003). Se o texto da linha guardada não bate mais com o que está no arquivo, a âncora é procurada e a anotação é reancorada na linha onde for encontrada. Não sendo encontrada, a anotação não é descartada nem apontada para a linha errada: sai no relatório numa seção própria, marcada como deslocada, para o revisor decidir.
