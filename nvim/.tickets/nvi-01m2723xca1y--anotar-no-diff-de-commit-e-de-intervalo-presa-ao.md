---
id: nvi-01m2723xca1y
title: Anotar no diff de commit e de intervalo, presa ao commit
status: open
type: task
priority: 2
mode: afk
created: '2026-09-11T01:43:05.346070071Z'
updated: '2026-09-11T01:43:05.483874119Z'
assignee: grisotto
parent: nvi-01m271x0rry4
tags:
- git
- review
acceptance:
- title: Lado de depois do diff de commit e de intervalo aceita anotação de linha e de trecho
  done: false
- title: Relatório cita a linha e o código do commit, sem reancorar, e o preâmbulo aponta git show
  done: false
- title: Quickfix reancorada no disco; item sem linha e marcado quando não está no disco
  done: false
- title: No modo commit, o arquivo de hoje recusa a anotação com aviso apontando <C-o>
  done: false
- title: Anotações antigas de modo commit sem versão são reancoradas contra o conteúdo do commit
  done: false
deps:
- nvi-01m2723x3vz0
---

## Parent

nvi-01m271x0rry4

## What to build

O revisor abre o painel, aperta `c`, escolhe um commit (ou um intervalo) no grafo, abre o diff de um arquivo e anota linhas e trechos no lado de depois — o conteúdo do commit, o mais novo num intervalo. A anotação guarda o sha como versão e fica presa ao commit: na geração, não é reancorada; a linha e o código citados saem do conteúdo daquele commit, e ela nunca sai como não encontrada. O preâmbulo diz que as linhas são do commit e como ver o conteúdo exato (`git show <sha>:<arquivo>`).

A quickfix do relatório de commit é reancorada no disco na hora, a partir do código do item; quando o trecho não está no disco, ou o arquivo não existe mais, o item vai sem linha com `não está no disco · `.

No modo commit ou intervalo, anotar o arquivo de hoje (depois do `go`) é recusado com um aviso que aponta o `<C-o>` de volta ao diff. Anotações de modo commit ou intervalo já gravadas sem versão (feitas no arquivo de hoje) são reancoradas contra o conteúdo do commit do modo: achadas, viram anotações do commit; não achadas, saem não encontradas. A ajuda do diff de commit lista as teclas de anotar. README: modo commit, anotações e reancoragem, roteiro manual.

Veja a spec: histórias 41, 42, 47, 50, 52, 53, 55, 56; ADR-0011; atualização do ADR-0003.

## Blocked by

- nvi-01m2723x3vz0