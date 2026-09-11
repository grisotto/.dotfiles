---
id: nvi-01m2723xn2ga
title: Gerar o relatório é entregar
status: open
type: task
priority: 2
mode: afk
created: '2026-09-11T01:43:05.625295942Z'
updated: '2026-09-11T13:15:04.860234298Z'
assignee: grisotto
parent: nvi-01m271x0rry4
tags:
- git
- review
acceptance:
- title: Gerar entrega as abertas do modo e o relatório seguinte só traz as anotadas depois
  done: false
- title: Gerar sem abertas refaz a última entrega congelada, idêntica em qualquer formato, e a notificação diz isso
  done: false
- title: Sem abertas e sem entrega, nada é copiado e a mensagem continua a de hoje
  done: false
- title: Contagem do painel conta só abertas; anotar ponto entregue começa anotação nova
  done: false
- title: Estado ganha entregas por acréscimo, sem perder vistos e anotações existentes
  done: false
deps:
- nvi-01m2723w2zb5
---

## Parent

nvi-01m271x0rry4

## What to build

O revisor anota, aperta `R` (ou `M`) e cola na conversa com o agente. Essas anotações passam a entregues: depois que o agente ajusta e o revisor anota de novo no mesmo modo, o próximo relatório só leva as novas.

Gerar com anotações abertas monta os itens, congela a entrega no documento de estado (id, modo, instante, cabeçalho e itens com as linhas e o código do momento), marca as anotações com a entrega e produz o documento. Gerar sem abertas e com entrega anterior no modo refaz a última entrega a partir dos itens congelados, no formato pedido, idêntica ao que o agente recebeu, e a notificação diz `relatório da última entrega (N anotações) copiado`; a quickfix é reancorada na hora. Sem abertas e sem entrega, a mensagem de hoje, sem tocar na área de transferência. Todas as entregas ficam guardadas.

A contagem `✎ N` do painel conta só as abertas. Anotar um ponto que tem anotação entregue abre a entrada vazia e grava uma anotação nova. Entregas e anotações continuam separadas por modo. O esquema do estado muda só por acréscimo e a versão do documento não sobe, para não descartar vistos e anotações. README: "Depois de `R`", anotações, roteiro manual.

Veja a spec: "Entrega" (57–60, 62–66) e as decisões "Documento de estado", "Entrega" e "Existência de anotação no ponto"; ADR-0012; `CONTEXT.md`: Anotação aberta, Anotação entregue, Entrega.

## Blocked by

- nvi-01m2723w2zb5

## Notes

**2026-09-11T13:12:58.649633955Z**

Decidir junto com a entrega: o modelo do preâmbulo (nvi-01m2723wvpey) é lido do arquivo a cada geração, em generate, e passado ao render como argumento. Se o revisor editar review/preamble.md entre uma entrega e o refazer dela, o preâmbulo refeito sai com o texto novo, enquanto cabeçalho e itens saem congelados. A história 59 fala das linhas e dos trechos do momento da geração; congelar também o preâmbulo renderizado (ou o texto do modelo) na entrega é a alternativa, se refazer tiver de reproduzir o documento byte a byte.

**2026-09-11T13:15:04.860234298Z**

Correção da nota anterior: o texto do modelo do preâmbulo agora é lido em build e viaja no próprio relatório (ReviewReport.template), e o render lê só o relatório. Congelar o relatório inteiro na entrega congela também o modelo, e o refazer reproduz o preâmbulo do momento da geração; deixar o template de fora do congelado é o que faria o refazer seguir o arquivo atual.
