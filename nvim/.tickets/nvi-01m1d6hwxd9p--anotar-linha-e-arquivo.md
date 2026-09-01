---
id: nvi-01m1d6hwxd9p
title: Anotar linha e arquivo
status: open
type: task
priority: 2
mode: afk
created: '2026-09-01T00:40:22.698783996Z'
updated: '2026-09-01T00:40:22.698783996Z'
assignee: grisotto
parent: nvi-01m1d6216yyq
tags:
- git
- review
acceptance:
- title: Uma tecla no código cria anotação presa à linha atual
  done: false
- title: Uma tecla no painel cria anotação de arquivo, sem linha
  done: false
- title: A entrada é de uma linha por padrão e uma segunda tecla abre a entrada longa
  done: false
- title: Anotar linha já anotada edita a anotação existente
  done: false
- title: O painel mostra a contagem de anotações na linha do arquivo
  done: false
- title: Cada anotação grava caminho, modo, linha quando houver, âncora, texto e instante
  done: false
- title: As anotações sobrevivem a reabrir o editor e ficam fora do repositório
  done: false
deps:
- nvi-01m1d6hwc7f9
---

## Description

### O que construir

O revisor escreve uma anotação presa a uma linha do código, e uma anotação de arquivo — sem linha — a partir do painel.

A entrada é de uma linha por padrão, porque quase toda observação de revisão é uma frase; uma segunda tecla abre a entrada em várias linhas para quando não couber. Anotar uma linha que já tem anotação edita a existente, em vez de empilhar duas observações no mesmo ponto.

O painel mostra, na linha de cada arquivo, quantas anotações ele tem.

Junto com o texto, cada anotação guarda a âncora: o texto da linha no momento em que foi escrita (ADR-0003). Ela é gravada aqui; quem a usa para reencontrar a linha é a fatia do relatório.

As anotações ficam no mesmo documento de estado do visto, fora do repositório revisado (ADR-0004). Cada uma guarda o caminho, o modo em que foi escrita, a linha quando houver, a âncora, o texto e o instante.
