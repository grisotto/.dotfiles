---
id: nvi-01m1kh8sfb0z
title: +N −M por linha, vindos do numstat
status: closed
type: feature
priority: 2
mode: afk
created: '2026-09-03T11:43:05.190904471Z'
updated: '2026-09-03T19:07:53.029579983Z'
closed: '2026-09-03T19:07:53.029579983Z'
assignee: grisotto
parent: nvi-01m1j8zy1rqj
tags:
- git
- review
- plugin-local
acceptance:
- title: Cada linha traz +N −M alinhado à direita, sem empurrar o caminho
  done: true
- title: Os números aparecem no working tree, no modo commit e no intervalo
  done: true
- title: Untracked e conflito aparecem sem números, deliberadamente
  done: true
- title: Renomeação e binário no numstat -z são consumidos sem corromper a linha
  done: true
- title: Os totais de linhas adicionadas e removidas ficam disponíveis no ReviewStatus
  done: true
- title: Os números ganham asserção própria, lida das extmarks de virtual text
  done: true
deps:
- nvi-01m1kh8f4v67
external_refs:
- git:75e8e90
---

## Description

**`+12 −3` por linha**, como **virtual text alinhado à direita**, para que um caminho longo empurre os números para fora em vez de empurrar o nome do arquivo. É a informação que decide em que ordem revisar, e é o que a lista do GitHub e a do IntelliJ mostram.

### De onde vêm os números

- working tree: um `git diff --numstat -z --cached` (staged) e um `git diff --numstat -z` (unstaged).
- commit: `--numstat` no `diff-tree` que já é feito; intervalo, o mesmo.
- **Untracked e conflito ficam sem números**: contar as linhas de um arquivo untracked custaria um processo por arquivo, e um conflito não tem duas vias para comparar. Ausência é honesta; número inventado não.
- `-z` no numstat: registro normal é `add\tdel\tcaminho\0`; renomeação é `add\tdel\t\0antigo\0novo\0` e precisa ser consumida como tal, pelo mesmo motivo que o `porcelain=v2` precisa. Binário vem como `-\t-` e fica sem números.

Os totais da revisão saem daqui e ficam no `ReviewStatus`; quem os desenha no cabeçalho é o ticket da linha de informação.

## Notes

**2026-09-03T19:07:53.029579983Z**

+N −M por linha em virtual text alinhado à direita, do numstat: dois processos no working tree, --raw --numstat no diff-tree do commit e do intervalo. Untracked, conflito e binário sem números. Totais no ReviewStatus, cuja tela é a linha de informação do cabeçalho (nvi-01m1kh915aem). 7 testes novos em tests/review/line_spec.lua.
