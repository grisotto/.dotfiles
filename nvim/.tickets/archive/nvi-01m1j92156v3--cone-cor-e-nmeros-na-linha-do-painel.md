---
id: nvi-01m1j92156v3
title: Ícone, cor e números na linha do painel
status: closed
type: feature
priority: 2
mode: afk
created: '2026-09-03T00:00:20.646699950Z'
updated: '2026-09-03T11:43:30.472208358Z'
closed: '2026-09-03T11:43:30.472208358Z'
assignee: grisotto
parent: nvi-01m1j8zy1rqj
tags:
- git
- review
- plugin-local
acceptance:
- title: Cada linha do painel mostra o ícone do arquivo, e a ausência do mini.icons não quebra o painel
  done: false
- title: O código de status do porcelain continua na linha, colorido por tipo de mudança
  done: false
- title: Cada linha traz +N −M alinhado à direita, sem empurrar o caminho
  done: false
- title: Untracked e conflito aparecem sem números, deliberadamente
  done: false
- title: Renomeação e binário no numstat -z são consumidos sem corromper a linha
  done: false
- title: O cabeçalho traz os totais de linhas adicionadas e removidas
  done: false
- title: mini.icons entra no runtimepath do harness e o helper de teste tira a coluna do ícone
  done: false
---

## Description

### Entregável

Hoje a linha é `  M  lua/review/panel.lua  ✎ 2`: código do porcelain de duas letras, sem cor e sem ícone, com Nerd Font ligado na configuração e não usado. A linha passa a ser **ícone do arquivo + código de status colorido + caminho + anotações + `+12 −3`**.

- **Ícone do arquivo** pelo `mini.icons`, que é o que está instalado (não há `nvim-web-devicons` aqui). Faz o painel ser lido pelos mesmos olhos que leem o neo-tree. Degrada para nada quando ausente — o painel não ganha dependência dura por causa de um glifo.
- **Código do porcelain mantido e colorido**: `A`/`?` em `Added`, `M`/`R` em `Changed`, `D` em `Removed`, o código de duas letras de um conflito em erro. As letras não saem: `R `, `MM` e `??` dizem coisas que um ícone sozinho não diz.
- **`+12 −3` por linha**, como **virtual text alinhado à direita**, para que um caminho longo empurre os números para fora em vez de empurrar o nome do arquivo. É a informação que decide em que ordem revisar, e é o que a lista do GitHub e a do IntelliJ mostram.
- **Totais no cabeçalho**, na linha de informação da tarefa de perfil.

### De onde vêm os números

- working tree: um `git diff --numstat -z --cached` (staged) e um `git diff --numstat -z` (unstaged).
- commit: `--numstat` no `diff-tree` que já é feito; intervalo, o mesmo.
- **Untracked e conflito ficam sem números**: contar as linhas de um arquivo untracked custaria um processo por arquivo, e um conflito não tem duas vias para comparar. Ausência é honesta; número inventado não.
- `-z` no numstat: registro normal é `add\tdel\tcaminho\0`; renomeação é `add\tdel\t\0antigo\0novo\0` e precisa ser consumida como tal, pelo mesmo motivo que o `porcelain=v2` precisa. Binário vem como `-\t-` e fica sem números.

### Testes

- `mini.icons` entra na lista de plugins do `tests/minimal_init.lua`: a renderização passa a depender dele, e um teste que roda sem ele afirma sobre uma tela que o revisor nunca vê.
- O helper `panel.section` passa a tirar a coluna do ícone, para as dezenas de asserções existentes seguirem sendo sobre status e caminho.
- O ícone ganha asserção própria, comparando com o que o `MiniIcons.get` responde para aquele caminho — e não com um glifo escrito à mão, que muda quando o mini.icons muda.
- Os números ganham asserção própria, lida das extmarks de virtual text.

## Notes

**2026-09-03T11:43:30.472208358Z**

Absorvido: fatiado em nvi-01m1kh8f4v67 (ícone e cor) e nvi-01m1kh8sfb0z (os números do numstat).
