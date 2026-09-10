---
id: nvi-01m1d6hwxd9p
title: Anotar linha e arquivo
status: closed
type: task
priority: 2
mode: afk
created: '2026-09-01T00:40:22.698783996Z'
updated: '2026-09-01T17:49:20.784078150Z'
closed: '2026-09-01T17:49:20.784078150Z'
assignee: grisotto
parent: nvi-01m1d6216yyq
tags:
- git
- review
acceptance:
- title: Uma tecla no código cria anotação presa à linha atual
  done: true
- title: Uma tecla no painel cria anotação de arquivo, sem linha
  done: true
- title: A entrada é de uma linha por padrão e uma segunda tecla abre a entrada longa
  done: true
- title: Anotar linha já anotada edita a anotação existente
  done: true
- title: O painel mostra a contagem de anotações na linha do arquivo
  done: true
- title: Cada anotação grava caminho, modo, linha quando houver, âncora, texto e instante
  done: true
- title: As anotações sobrevivem a reabrir o editor e ficam fora do repositório
  done: true
- title: A mesma tecla no modo visual cria anotação presa ao trecho selecionado, citado inteiro no relatório
  done: true
- title: A winbar do diff escreve as teclas de anotar quando o lado da direita é o arquivo do revisor
  done: true
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

## Notes

**2026-09-01T17:49:20.652707928Z**

Anotação de linha com `<Leader>ga` no código e de arquivo com `a` no painel; a tecla shifted abre a entrada longa. Anotar de novo o mesmo ponto edita o que está lá, com a entrada chegando preenchida. Contagem `✎ N` na linha do arquivo. Cada anotação grava caminho, modo, linha, âncora (ADR-0003), texto e instante, no documento do visto fora do repositório (ADR-0004). Três decisões fora da spec, registradas no commit: esvaziar o texto apaga a anotação; anotação que não cabe numa linha é sempre editada na entrada longa; a forma da entrada não virou opção, foi pelo caminho do ADR-0006 (as duas ligadas, cada uma na sua tecla). Anotar linha só vale no arquivo em si — num diff de staged os dois lados são revs. 20 testes em tests/review/annotation_spec.lua.
