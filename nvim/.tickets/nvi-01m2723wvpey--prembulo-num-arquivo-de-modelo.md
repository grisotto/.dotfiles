---
id: nvi-01m2723wvpey
title: Preâmbulo num arquivo de modelo
status: open
type: task
priority: 2
mode: afk
created: '2026-09-11T01:43:04.814925062Z'
updated: '2026-09-11T01:43:04.945635752Z'
assignee: grisotto
parent: nvi-01m271x0rry4
tags:
- git
- review
acceptance:
- title: Opção com o caminho do modelo, padrão sob o diretório de configuração
  done: false
- title: '{types}, {reference} e {not_found} são substituídos nos dois formatos'
  done: false
- title: Marcador desconhecido fica literal e sem arquivo vale o preâmbulo embutido
  done: false
deps:
- nvi-01m2723w2zb5
---

## Parent

nvi-01m271x0rry4

## What to build

O revisor muda o texto do preâmbulo do relatório editando um arquivo de modelo, sem mexer no plugin. Uma opção dá o caminho do modelo, com padrão sob o diretório de configuração do editor (`review/preamble.md`). O modelo tem os marcadores `{types}` (as instruções dos tipos usados), `{reference}` (de qual versão são as linhas citadas) e `{not_found}` (a regra das anotações não encontradas, vazia quando não há). Marcador desconhecido fica no texto como está; marcador omitido simplesmente não aparece; sem arquivo, vale o preâmbulo padrão embutido. Os dois formatos usam o mesmo preâmbulo renderizado. README: a opção, o arquivo e os marcadores.

Veja a spec: histórias 21–24 e a decisão "Preâmbulo".

## Blocked by

- nvi-01m2723w2zb5