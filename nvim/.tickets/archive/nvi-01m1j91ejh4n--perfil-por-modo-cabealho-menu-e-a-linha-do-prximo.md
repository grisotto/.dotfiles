---
id: nvi-01m1j91ejh4n
title: 'Perfil por modo: cabeçalho, menu e a linha do próximo passo'
status: closed
type: feature
priority: 2
mode: afk
created: '2026-09-03T00:00:01.616919135Z'
updated: '2026-09-03T11:43:30.336128981Z'
closed: '2026-09-03T11:43:30.336128981Z'
assignee: grisotto
parent: nvi-01m1j8zy1rqj
tags:
- git
- review
- plugin-local
acceptance:
- title: O cabeçalho tem uma segunda linha de informação, esmaecida, em todos os modos
  done: false
- title: No modo commit a segunda linha traz autor e data do commit
  done: false
- title: No modo intervalo a segunda linha traz quantos commits o intervalo tem
  done: false
- title: No modo commit, stage, unstage e descartar não aparecem no menu de contexto nem no which-key
  done: false
- title: Essas três teclas seguem mapeadas e seguem respondendo com a recusa que aponta o w
  done: false
- title: 'Com tudo visto, o painel diz o próximo passo do modo: neogit no working tree, relatório no commit'
  done: false
deps:
- nvi-01m1j92156v3
---

## Description

### Entregável

Revisar o próprio working tree e revisar o commit de outra pessoa são dois trabalhos com fins diferentes: um termina no commit saindo, o outro no relatório saindo. As teclas continuam as mesmas em qualquer modo (ADR-0001); o que muda é o que o painel **informa**.

**1. Cabeçalho em duas linhas.** A primeira segue como é hoje (`Revisão · <título> · N/M vistos`). A segunda é a linha de informação, esmaecida:

- working tree: `+A −D`
- commit: `<autor> · <data> · +A −D`
- intervalo: `<N> commits · +A −D`

Exige `%an` e `%ad --date=short` no `git show` de `commit_status`, e os campos correspondentes em `ReviewStatus`. Os totais vêm da tarefa dos números na linha.

**2. Menu e which-key sabem em que modo estão.** No modo commit, `s`, `u` e `X` **saem do menu de contexto e do which-key** — ficam mapeadas, sem descrição, para que quem apertar por hábito receba a recusa explicativa que já existe e aponta o `w`. Um menu que oferece o que vai ser recusado é pior do que não ter menu.

**3. A linha do próximo passo.** Quando tudo está visto, no lugar onde hoje só apareceria "Nenhuma mudança.", o painel diz o que fazer agora:

- working tree: commitar no neogit (`<Leader>gnc`)
- commit e intervalo: gerar o relatório (`R`)

É o "fim" da revisão sem inventar um estado: nada é iniciado, nada é finalizado, nada é arquivado. O visto continua sendo do conteúdo (ADR-0002) e continua atravessando modos.

## Notes

**2026-09-03T11:43:30.336128981Z**

Absorvido: fatiado em nvi-01m1kh915aem (a linha de informação do cabeçalho) e nvi-01m1kh9b2nak (menu, which-key e a linha do próximo passo).
