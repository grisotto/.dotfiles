---
id: nvi-01m2723wke2n
title: Tipo da anotação pelo prefixo
status: closed
type: task
priority: 2
mode: afk
created: '2026-09-11T01:43:04.550645444Z'
updated: '2026-09-11T13:00:09.804195302Z'
closed: '2026-09-11T13:00:09.804195302Z'
assignee: grisotto
parent: nvi-01m271x0rry4
tags:
- git
- review
acceptance:
- title: 'Com prefix, nenhum seletor aparece e name: define o tipo e sai do texto'
  done: true
- title: Prefixo desconhecido ou ausente mantém o texto e grava issue
  done: true
- title: Edição vem preenchida com o prefixo do tipo, exceto issue, e trocar o prefixo troca o tipo
  done: true
deps:
- nvi-01m2723wb1g7
---

## Parent

nvi-01m271x0rry4

## What to build

Com a opção `annotation_type_entry = "prefix"`, o seletor de tipo não aparece: o revisor escreve `question: por que isto?` e a anotação é gravada com o tipo `question` e o texto sem o prefixo. Só um prefixo que casa exatamente o nome de um tipo configurado define o tipo, sem abreviações; sem prefixo, ou com um prefixo desconhecido (`nota: …`), o tipo é `issue` e o texto fica intacto. Ao editar, a entrada vem preenchida com `nome: ` na frente para qualquer tipo que não seja `issue`, e trocar o prefixo troca o tipo. O padrão continua `select`. README atualizado com a opção.

Veja a spec: histórias 37–39 e a decisão "Entrada do tipo"; ADR-0006 (tipo como opção).

## Blocked by

- nvi-01m2723wb1g7