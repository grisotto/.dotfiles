---
id: nvi-01m1d6hx62xh
title: Terceiro modo de visualização de conflito, no painel
status: closed
type: task
priority: 2
mode: afk
created: '2026-09-01T00:40:22.975626480Z'
updated: '2026-09-01T19:09:21.818135904Z'
closed: '2026-09-01T19:09:21.818135904Z'
assignee: grisotto
parent: nvi-01m1d6216yyq
tags:
- git
- review
acceptance:
- title: Uma tecla abre o conflito na aba do painel, a partir dos três estágios do índice
  done: true
- title: As três versões aparecem simultaneamente e a lista do painel continua visível
  done: true
- title: As outras duas apresentações de conflito continuam funcionando, inalteradas
  done: true
deps:
- nvi-01m1d6hw839c
---

## Description

### O que construir

Uma terceira apresentação de conflito, construída na própria aba do painel a partir dos três estágios do índice — base, nossa versão e a que está entrando — para o revisor comparar com os dois layouts do merge tool do diffview antes de fixar um padrão (ADR-0006).

Diferente das outras duas, esta não troca de aba: a lista continua visível ao lado.

### Fronteira

Esta fatia entrega visualização. Escolher lado e navegar entre conflitos continuam sendo do diffview (ADR-0005) — reimplementá-los está fora de escopo na spec.

### Nota

As três teclas de conflito são propositalmente redundantes e temporárias. Apagar as perdedoras depois é uma linha cada, mas é decisão do revisor, não limpeza automática.

## Notes

**2026-09-01T19:09:01.297769562Z**

`D` numa linha de conflito monta as três versões que o git guarda no índice — a
atual (`:2`), a base (`:1`) e a que está entrando (`:3`) — lado a lado na aba do
painel, com a lista ainda visível. É a única das três apresentações de conflito
que não troca de aba, e só mostra: escolher lado e navegar entre conflitos
continuam no merge tool (ADR-0005). Fora de um conflito, `D` avisa em vez de
abrir. As outras duas teclas ficaram como estavam (ADR-0006).

A ordem na tela é atual, base, entrando: os dois layouts do diffview põem a
nossa versão à esquerda e a que entra à direita, e comparar as três
apresentações exige não ter que reaprender qual lado é qual a cada tecla. A base
fica no meio, onde o merge tool desenha o merge. O ticket enumera "base, nossa
versão e a que está entrando", que é a ordem dos estágios no índice, não a da
tela.

O `diff.lua` passou a montar N lados em vez de dois (`build`), e o diff de duas
vias virou uma chamada dele com dois — mesmas janelas, mesmo foco de antes.

Revisão de código: a revisão de spec achou um defeito que já existia no diff de
duas vias e que com três lados apagava toda a identidade da tela — os buffers
novos eram criados antes de os antigos saírem, e o nome de um buffer é único no
editor, então abrir o mesmo conflito duas vezes deixava as três versões sem
nome, em silêncio (nomear buffer pode falhar). Agora o diff anterior é desmontado
antes de os lados novos serem lidos, com teste para os dois casos. A revisão de
padrões pediu nomes menos opacos no `build` e um comentário do `window.lua` que
o terceiro lado tinha deixado desatualizado.

8 testes novos em tests/review/open_spec.lua, 153 na suíte. Fixture novo:
`repo:conflict_without_base`, o conflito que os dois lados criaram do nada, onde
o índice não tem estágio 1 e a base aparece como lado vazio.

Fica anotado para o /domain-modeling: o CONTEXT.md não tem termo nenhum de
conflito, e as três versões agora têm nome na tela.

**2026-09-01T19:09:21.818135904Z**

As três versões de um conflito abrem ao lado do painel, na aba dele, a partir dos estágios do índice.
