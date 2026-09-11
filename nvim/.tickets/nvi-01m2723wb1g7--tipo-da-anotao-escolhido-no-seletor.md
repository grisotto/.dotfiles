---
id: nvi-01m2723wb1g7
title: Tipo da anotação escolhido no seletor
status: open
type: task
priority: 2
mode: afk
created: '2026-09-11T01:43:04.281899877Z'
updated: '2026-09-11T01:43:04.409937709Z'
assignee: grisotto
parent: nvi-01m271x0rry4
tags:
- git
- review
acceptance:
- title: Seletor antes do texto, com nome e instrução de cada tipo, na entrada curta e na longa
  done: false
- title: issue primeiro numa anotação nova; o tipo atual primeiro numa edição; cancelar o seletor desiste
  done: false
- title: annotation_types acrescenta tipos e troca a instrução de um existente
  done: false
- title: Tipo gravado no estado; anotação antiga sem tipo sai como issue
  done: false
- title: Relatório e quickfix mostram o tipo; o preâmbulo lista só os tipos usados
  done: false
deps:
- nvi-01m2723w2zb5
---

## Parent

nvi-01m271x0rry4

## What to build

Toda anotação passa a ter um tipo da anotação. Ao anotar uma linha, um trecho ou um arquivo, o revisor escolhe o tipo num seletor do editor antes de escrever o texto (na entrada curta e na longa): cada opção mostra o nome e a instrução ao agente, `issue` vem primeiro numa anotação nova e o tipo atual vem primeiro numa anotação que está sendo editada, e desistir do seletor desiste da anotação. A entrada de texto diz o tipo e o ponto (`issue em a.clj:42-44`).

Os oito tipos padrão, na ordem: `issue`, `refactor`, `test`, `revert`, `question`, `suggestion`, `nitpick`, `praise`. A opção `annotation_types` recebe `{ name, instruction }`: nome existente troca a instrução, nome novo é acrescentado ao fim. O tipo é gravado no documento de estado; anotação sem tipo conta como `issue`.

O relatório (XML e markdown) mostra o tipo de cada item e a quickfix o põe no `#id type`, e o preâmbulo lista as instruções só dos tipos usados, na ordem da configuração. README e roteiro manual atualizados.

Veja a spec: "Tipo da anotação" e a decisão "Entrada do tipo"; `CONTEXT.md`: Tipo da anotação.

## Blocked by

- nvi-01m2723w2zb5