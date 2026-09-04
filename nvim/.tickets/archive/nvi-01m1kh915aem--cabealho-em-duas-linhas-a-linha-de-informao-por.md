---
id: nvi-01m1kh915aem
title: 'Cabeçalho em duas linhas: a linha de informação por modo'
status: closed
type: feature
priority: 2
mode: afk
created: '2026-09-03T11:43:13.060744085Z'
updated: '2026-09-03T19:11:37.977766922Z'
closed: '2026-09-03T19:11:37.977766922Z'
assignee: grisotto
parent: nvi-01m1j8zy1rqj
tags:
- git
- review
- plugin-local
acceptance:
- title: O cabeçalho tem uma segunda linha de informação, esmaecida, em todos os modos
  done: true
- title: No working tree a segunda linha traz os totais de linhas adicionadas e removidas
  done: true
- title: No modo commit a segunda linha traz autor e data do commit
  done: true
- title: No modo intervalo a segunda linha traz quantos commits o intervalo tem
  done: true
- title: commit_status lê %an e %ad --date=short, e os campos correspondentes entram no ReviewStatus
  done: true
deps:
- nvi-01m1kh8sfb0z
external_refs:
- git:77bceb7
---

## Description

Revisar o próprio working tree e revisar o commit de outra pessoa são dois trabalhos com fins diferentes. As teclas continuam as mesmas em qualquer modo (ADR-0001); o que muda é o que o painel **informa**.

A primeira linha segue como é hoje (`Revisão · <título> · N/M vistos`). A segunda é a linha de informação, esmaecida:

- working tree: `+A −D`
- commit: `<autor> · <data> · +A −D`
- intervalo: `<N> commits · +A −D`

Exige `%an` e `%ad --date=short` no `git show` de `commit_status`, e os campos correspondentes em `ReviewStatus`. Os totais vêm do ticket dos números na linha.

## Notes

**2026-09-03T19:11:37.977766922Z**

Segunda linha do cabeçalho, esmaecida: +A −D no working tree, autor · data · totais no commit, N commits · totais no intervalo. %an e %ad --date=short entraram no git show do commit_status, e author/date/commits no ReviewStatus. 4 testes novos (panel_spec e commit_spec) e o termo Linha de informação no CONTEXT.md.
