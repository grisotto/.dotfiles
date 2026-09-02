---
id: nvi-01m1d6hxjmxm
title: Ver e comparar um arquivo em outro rev
status: closed
type: task
priority: 3
mode: afk
created: '2026-09-01T00:40:23.378325040Z'
updated: '2026-09-02T01:23:59.421124420Z'
closed: '2026-09-02T01:23:59.421124420Z'
assignee: grisotto
parent: nvi-01m1d62bd8hq
tags:
- git
- review
acceptance:
- title: Uma tecla abre o arquivo no rev escolhido, somente leitura e identificado pelo rev
  done: true
- title: Uma volta simples retorna ao que estava sendo feito antes
  done: true
- title: Outra tecla compara o arquivo atual com a versão daquele rev
  done: true
- title: O rev é escolhido numa busca que lista branches e os commits daquele arquivo
  done: true
deps:
- nvi-01m1d6hw839c
---

## Description

### O que construir

Dois gestos diferentes sobre o arquivo da linha atual, em teclas separadas.

Ver: abre o arquivo como ele está em outro commit ou branch, num buffer somente leitura identificado pelo rev, com uma volta fácil para o que o revisor estava fazendo — a consulta não pode custar a navegação.

Comparar: abre o diff do arquivo atual contra a versão dele naquele rev.

Nos dois casos o rev sai de uma busca que lista as branches e os commits daquele arquivo, para não ser preciso digitar sha.

### Nota de sequência

Esta fatia está na fase 3 por afinidade de tema, mas tecnicamente só depende da fatia de diff: pode ser antecipada se for útil antes do modo commit.

## Notes

**2026-09-02T01:23:59.421124420Z**

Duas teclas do painel sobre a linha: e abre o arquivo no rev escolhido, somente leitura e nomeado pelo rev, com q devolvendo o que estava ao lado do painel e o cursor à lista; E compara aquela versão com o que o painel está revisando. O rev sai sempre de uma busca com as branches e os commits daquele arquivo, pelos dois nomes quando ele foi renomeado. 31 testes em tests/review/rev_spec.lua; suíte inteira verde.
