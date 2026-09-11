---
id: nvi-01m2723x3vz0
title: Anotar no diff de staged
status: closed
type: task
priority: 2
mode: afk
created: '2026-09-11T01:43:05.075930885Z'
updated: '2026-09-11T13:34:07.969672753Z'
closed: '2026-09-11T13:34:07.969672753Z'
assignee: grisotto
parent: nvi-01m271x0rry4
tags:
- git
- review
acceptance:
- title: Lado de depois do diff de staged aceita anotação de linha e de trecho
  done: true
- title: Ponto guarda a versão; mesma linha no índice e no disco são pontos diferentes
  done: true
- title: Anotação do índice é reancorada no disco na geração
  done: true
- title: Lado de antes de qualquer diff recusa com aviso; conflito e vista em outro rev continuam recusando
  done: true
- title: Ajuda do diff de staged lista as teclas de anotar
  done: true
deps:
- nvi-01m2723w2zb5
---

## Parent

nvi-01m271x0rry4

## What to build

Com o diff de uma entrada staged aberto, o revisor anota uma linha ou um trecho no lado de depois — o índice — com as teclas globais de anotar. O ponto passa a guardar a versão em que a linha foi lida (disco ou índice), e a linha 5 do índice e a linha 5 do disco são pontos diferentes. A âncora é lida do buffer do lado anotado. Na geração do relatório, a anotação do índice é reancorada no disco, como a do unstaged, e sai deslocada quando o texto não está lá.

O lado de antes de qualquer diff recusa a anotação com um aviso, e as três versões de um conflito e a vista em outro rev continuam recusando. A ajuda do diff (`g?`) passa a listar as teclas de anotar também no diff de staged. Anotações já gravadas sem versão, no working tree, são versão disco. README: seção do diff e roteiro manual.

Veja a spec: "Onde se anota" (43–46, 48, 49, 51) e as decisões "Ponto e versão", "Onde a anotação de linha é aceita" e "Reancoragem na geração"; `CONTEXT.md`: Ponto, Anotação.

## Blocked by

- nvi-01m2723w2zb5

## Notes

**2026-09-11T13:34:07.969672753Z**

Lado de depois do diff de staged anota o índice (versão index, âncora lida do lado); ponto compara a versão, legado do working tree é disco; lado de antes recusa com aviso; ajuda do staged lista as teclas; relatório reancora no disco (já reancorava tudo).
