---
id: nvi-01m1kh8f4v67
title: Ícone e cor na linha do painel
status: closed
type: feature
priority: 2
mode: afk
created: '2026-09-03T11:42:54.619830950Z'
updated: '2026-09-03T19:02:01.398541670Z'
closed: '2026-09-03T19:02:01.398541670Z'
assignee: grisotto
parent: nvi-01m1j8zy1rqj
tags:
- git
- review
- plugin-local
acceptance:
- title: Cada linha do painel mostra o ícone do arquivo, e a ausência do mini.icons não quebra o painel
  done: true
- title: O código de status do porcelain continua na linha, colorido por tipo de mudança
  done: true
- title: mini.icons entra no runtimepath do harness e o helper de teste tira a coluna do ícone
  done: true
- title: O ícone é asserido contra o que MiniIcons.get responde, e não contra um glifo escrito à mão
  done: true
external_refs:
- git:6b66707
---

## Description

Hoje a linha é `  M  lua/review/panel.lua  ✎ 2`: código do porcelain de duas letras, sem cor e sem ícone, com Nerd Font ligado na configuração e não usado. A linha passa a ser **ícone do arquivo + código de status colorido + caminho + anotações**; os números vêm no ticket seguinte.

- **Ícone do arquivo** pelo `mini.icons`, que é o que está instalado (não há `nvim-web-devicons` aqui). Faz o painel ser lido pelos mesmos olhos que leem o neo-tree. Degrada para nada quando ausente — o painel não ganha dependência dura por causa de um glifo.
- **Código do porcelain mantido e colorido**: `A`/`?` em `Added`, `M`/`R` em `Changed`, `D` em `Removed`, o código de duas letras de um conflito em erro. As letras não saem: `R `, `MM` e `??` dizem coisas que um ícone sozinho não diz.

### Testes

Este é o ticket de raio largo da fase: a coluna nova entra na frente de todas as linhas, e dezenas de asserções existentes são sobre o começo delas.

- `mini.icons` entra na lista de plugins do `tests/minimal_init.lua`: a renderização passa a depender dele, e um teste que roda sem ele afirma sobre uma tela que o revisor nunca vê.
- O helper `panel.section` passa a tirar a coluna do ícone, para as asserções existentes seguirem sendo sobre status e caminho. É o que mantém a suíte verde sem reescrever cada spec.
- O ícone ganha asserção própria, comparando com o que o `MiniIcons.get` responde para aquele caminho — e não com um glifo escrito à mão, que muda quando o mini.icons muda.
- A cor ganha asserção própria, lida dos highlights da linha.

## Notes

**2026-09-03T19:02:01.398541670Z**

Ícone do mini.icons e código do porcelain colorido por tipo de mudança na linha do painel. mini.icons no runtimepath do harness (com setup), helper tirando a coluna do ícone, e 6 testes novos em tests/review/line_spec.lua.
