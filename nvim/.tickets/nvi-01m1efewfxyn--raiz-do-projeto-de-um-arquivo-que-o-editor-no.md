---
id: nvi-01m1efewfxyn
title: Raiz do projeto de um arquivo que o editor não abriu
status: open
type: task
priority: 3
mode: hitl
created: '2026-09-01T12:35:15.581738391Z'
updated: '2026-09-01T12:35:15.581738391Z'
assignee: grisotto
parent: nvi-01m1d61ppxj1
---

## Description

Descoberto ao implementar a cópia de caminhos (nvi-01m1d6hwge5g).

O caminho relativo sai da raiz do projeto resolvida pelo detector desta configuração. Esse detector só sabe o módulo de um arquivo que o editor abriu: a resposta vem do servidor de linguagem preso ao buffer, e um arquivo que ninguém abriu não tem servidor nenhum (nem dá para prender um a tempo — eles se prendem ao carregar o arquivo e respondem depois disso).

Para esse arquivo, a lista de detectores responde a raiz do repositório, porque `{ ".git", ... }` vem antes de `{ "lua", "Makefile", "package.json" }`. Num monorepo, copiar o caminho de um arquivo ainda não aberto dá o caminho a partir da raiz do repositório, não do módulo.

A decisão é do revisor e é sobre a configuração, não sobre o painel: pôr marcadores de módulo antes do `.git` na lista do rooter muda também para onde o editor enraíza o cwd, o session e tudo mais que usa o rooter. A alternativa — o painel detectar por conta própria — está descartada na spec do épico ("Nenhuma detecção própria é escrita").

O comportamento de hoje está fixado por teste em tests/review/paths_spec.lua.
