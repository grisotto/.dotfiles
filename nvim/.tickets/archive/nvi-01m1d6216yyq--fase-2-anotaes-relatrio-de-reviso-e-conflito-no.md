---
id: nvi-01m1d6216yyq
title: 'Fase 2: anotações, relatório de revisão e conflito no painel'
status: closed
type: feature
priority: 2
mode: afk
created: '2026-09-01T00:31:42.813747076Z'
updated: '2026-09-03T20:05:53.184373011Z'
closed: '2026-09-03T20:05:53.184373011Z'
assignee: grisotto
parent: nvi-01m1d6164sz2
tags:
- git
- review
acceptance:
- title: Anotação de linha e anotação de arquivo são criadas do painel e do arquivo aberto
  done: true
- title: Anotar linha já anotada edita a anotação existente em vez de empilhar
  done: true
- title: Contagem de anotações aparece na linha do arquivo no painel
  done: true
- title: Anotação sobrevive a edições acima dela no arquivo, via reancoragem por âncora
  done: true
- title: Anotação cuja âncora não é encontrada sai no relatório marcada como deslocada
  done: true
- title: Relatório agrupa por arquivo, cita o trecho e é gravado fora do repositório
  done: true
- title: Gerar o relatório popula a quickfix com os pontos anotados
  done: true
- title: Relatório contém apenas as anotações do modo atual
  done: true
- title: Terceiro modo de conflito abre na aba do painel a partir dos três estágios do índice
  done: true
deps:
- nvi-01m1d61ppxj1
---

## Description

Cobre as user stories 36-48 da spec do épico, mais a 14.

### Entregável

Anotação presa a arquivo e linha, e anotação de arquivo criada do painel. Entrada de uma linha por padrão, com uma tecla alternativa para o texto longo em várias linhas. Anotar uma linha que já tem anotação edita a existente. Contagem de anotações visível na linha do arquivo no painel. Âncora por texto da linha, com reancoragem por busca e marcação de anotação deslocada quando não encontrada. Geração do relatório de revisão agrupado por arquivo, com trecho citado, gravado fora do repositório, populando a quickfix em paralelo. Escopo do relatório é o modo atual.

Inclui também o terceiro modo de visualização de conflito, construído na aba do painel a partir dos três estágios do índice, para comparar com os dois layouts do diffview.

### Fora desta fase

Modo commit e tudo da fase 3.

## Notes

**2026-09-03T20:05:53.184373011Z**

Fase 2 entregue pelos tickets filhos; suíte verde (317 testes) e os 9 critérios verificados.
