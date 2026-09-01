---
id: nvi-01m1d6hwge5g
title: Copiar caminhos do arquivo em revisão
status: closed
type: task
priority: 1
mode: afk
created: '2026-09-01T00:40:22.284816144Z'
updated: '2026-09-01T12:35:32.601838761Z'
closed: '2026-09-01T12:35:32.601838761Z'
assignee: grisotto
parent: nvi-01m1d61ppxj1
tags:
- git
- review
acceptance:
- title: Uma tecla copia o caminho absoluto do arquivo da linha
  done: true
- title: Outra tecla copia o caminho relativo à raiz do projeto
  done: true
- title: A raiz vem do detector existente na configuração, sem detecção própria
  done: true
- title: Em repositório com mais de um módulo, o caminho sai relativo ao módulo do arquivo
  done: true
deps:
- nvi-01m1d6hw44g6
---

## Description

### O que construir

Duas teclas no painel copiam o caminho do arquivo da linha atual: uma o caminho absoluto, outra o caminho relativo à raiz do projeto.

A raiz do projeto é resolvida pelo detector de raiz já existente nesta configuração, que consulta o LSP e cai para marcadores de projeto. Nenhuma detecção própria é escrita.

Em monorepo isso importa: o caminho relativo sai relativo ao módulo daquele arquivo, e não à raiz do repositório, que são coisas diferentes no glossário e no disco.

## Notes

**2026-09-01T12:35:05.948847338Z**

Duas teclas no painel: `y` copia o caminho a partir da raiz do projeto do arquivo, `Y` copia o caminho absoluto. Os dois vão para a área de transferência e para o registrador sem nome, com notificação do que foi copiado.

A raiz do projeto vem do rooter do astrocore (lua/review/root.lua só pergunta): LSP primeiro, marcadores de projeto depois. Nenhuma detecção nossa.

Limite descoberto na revisão, e agora fixado por teste: o detector só sabe o módulo de um arquivo que o editor abriu, porque é do servidor de linguagem preso ao buffer que vem essa resposta. Para um arquivo que ninguém abriu, a lista de detectores desta configuração responde a raiz do repositório — `{ ".git", ... }` vem antes de `{ "lua", "Makefile", "package.json" }`. Mudar isso é mudar o rooter da configuração inteira (ele também manda no cwd), então virou ticket à parte.

A suíte ganhou o astrocore no runtimepath, um provedor de clipboard de mentira (para não escrever na área de transferência de quem roda os testes) e um servidor de linguagem de mentira enraizado num módulo. `make test-file` também foi corrigido: o `PlenaryBustedFile` abria outro editor sem `-u`, e as specs rodavam contra a configuração real.

**2026-09-01T12:35:32.601838761Z**

Teclas y (relativo à raiz do projeto) e Y (absoluto) no painel, com a raiz vindo do rooter do astrocore. Implementado em f2514cb; o limite do detector para arquivo não aberto virou o nvi-01m1efewfxyn.
