---
id: nvi-01m2723xxhe8
title: Reabrir a última entrega (U)
status: closed
type: task
priority: 2
mode: afk
created: '2026-09-11T01:43:05.896993097Z'
updated: '2026-09-11T23:13:37.268809528Z'
closed: '2026-09-11T23:13:37.268809528Z'
assignee: grisotto
parent: nvi-01m271x0rry4
tags:
- git
- review
acceptance:
- title: U devolve as anotações da última entrega a abertas e tira a entrega do histórico
  done: true
- title: Sem entrega no modo, U avisa
  done: true
- title: Colisão com anotação aberta no mesmo ponto recusa e nomeia o ponto
  done: true
- title: U no menu, no which-key e na ajuda do painel
  done: true
deps:
- nvi-01m2723xn2ga
external_refs:
- git:8eaefe9
---

## Parent

nvi-01m271x0rry4

## What to build

O revisor gerou o relatório, não mandou, e percebeu um erro ou uma anotação esquecida. Ele aperta `U` no painel: a última entrega do modo sai do histórico e as anotações dela voltam a abertas, prontas para editar e gerar de novo. Sem entrega no modo, `U` avisa. Se uma anotação da entrega cai no mesmo ponto de uma anotação aberta escrita depois, a reabertura é recusada com um aviso que nomeia o ponto. `U` aparece no menu de contexto, no which-key e na ajuda do painel. README: tecla e roteiro manual.

Veja a spec: histórias 61 e 67 e a decisão "Reabrir (`U`)"; ADR-0012.

## Blocked by

- nvi-01m2723xn2ga

## Notes

**2026-09-11T20:54:52.559518641Z**

Deixado pela entrega (nvi-01m2723xn2ga): report.generate ainda apaga os .xml/.md do modo e limpa a quickfix quando o modo não tem anotação aberta nem entrega. Com a entrega esse caminho só é alcançado depois de um U que devolve as anotações e o revisor as apaga; o teste que o cobria ("leva embora os relatórios anteriores...") saiu de report_spec porque ficou inalcançável sem U. Decidir aqui se o comportamento fica, e recolocar o teste com U.

**2026-09-11T20:59:23.378587048Z**

Correção da nota anterior (achado da revisão): o caminho sem anotação aberta e sem entrega é alcançável sem U — num modo nunca anotado (esvazia a quickfix) e com relatórios gravados antes das entregas ao lado de um documento sem entrega (apaga os .xml/.md). O teste voltou a report_spec nessa forma (document.without "deliveries" e "annotations"). Com U, decidir se apagar os relatórios do modo continua certo quando a reabertura esvazia a última entrega.

**2026-09-11T23:12:37.041574730Z**

Decisão da nota anterior: apagar os .xml/.md do modo quando ele fica sem anotação aberta e sem entrega continua certo com o U.

A reabertura sozinha não esvazia nada — as anotações voltam a abertas e o R seguinte regrava os arquivos. O caminho só é alcançado quando o revisor apaga as anotações devolvidas, e aí o que os arquivos ainda guardavam era exatamente a entrega que deixou de existir: mantê-los seria entregar ao agente o que a revisão não diz mais.

O teste voltou a report_spec por esse caminho ('leva embora os relatórios do modo quando a reabertura e o apagar esvaziam a revisão'), ao lado do que chega lá pelo documento gravado antes das entregas. A razão ficou no comentário de M.generate, em lua/review/report.lua, que antes justificava a limpeza sem falar em reabertura.

**2026-09-11T23:13:37.268809528Z**

U no painel reabre a última entrega do modo: ela sai do histórico e as anotações dela voltam a abertas, para corrigir o relatório gerado e não mandado. Sem entrega no modo, avisa; colisão com anotação aberta no mesmo ponto recusa inteira, antes de qualquer escrita, nomeando o ponto com a versão em que a linha foi lida. A tecla sai da lista única de ações, então entra no menu, no which-key e na ajuda de uma vez (ADR-0008). README (tecla e roteiro) e docs/agents/testing.md atualizados. make format, make lint (0 erros, 0 avisos) e make test (433 specs, 0 falhas) verdes.
