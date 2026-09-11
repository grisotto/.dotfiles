---
id: nvi-01m2723w2zb5
title: Relatório para o agente em XML (R) e markdown (M)
status: open
type: task
priority: 2
mode: afk
created: '2026-09-11T01:43:04.031752435Z'
updated: '2026-09-11T01:43:04.152841110Z'
assignee: grisotto
parent: nvi-01m271x0rry4
tags:
- git
- review
acceptance:
- title: R gera XML e M gera markdown, e o helper de teste lê os mesmos itens dos dois documentos
  done: false
- title: Cabeçalho com raiz absoluta, branch e referência do modo, sem data de geração
  done: false
- title: Itens em lista plana com id, type, file, lines, código citado e texto; arquivo inteiro sem lines e sem código
  done: false
- title: Anotação deslocada entra na lista marcada como não encontrada, e só então o preâmbulo traz a regra dela
  done: false
- title: 'Quickfix com #id type em cada item; arquivos .xml e .md gravados fora do repositório e documento copiado'
  done: false
- title: R e M no menu, no which-key e na ajuda do painel; README atualizado
  done: false
---

## Parent

nvi-01m271x0rry4

## What to build

O revisor aperta `R` no painel e recebe o relatório de revisão em tags XML; aperta `M` e recebe o mesmo relatório em markdown. Os dois têm o mesmo conteúdo: um cabeçalho com a raiz absoluta do repositório, a branch e a referência do modo (sha completo e assunto num commit, `antigo^..novo` num intervalo, HEAD no working tree), sem data; o preâmbulo padrão embutido (revisão humana da mudança do agente, o que cada tipo usado pede, não alterar nada além do pedido, localizar pelo código citado, não fazer commit, responder uma linha por id com `feito`, `respondido` ou `recusado: motivo`); e uma lista plana de itens numerados, ordenados por arquivo e linha, com `id`, `type`, `file`, `lines`, o código citado exatamente e o texto. A anotação de arquivo inteiro vai sem linhas e sem código. A anotação deslocada entra na mesma lista, marcada como não encontrada, com o código de quando foi escrita, e o preâmbulo só então explica o que fazer com ela.

Enquanto a fatia do tipo da anotação não chega, toda anotação sai como `issue`.

A quickfix passa a ter cada item começando com `#id type`. Cada formato grava o seu arquivo (`<raiz>-<modo>.xml` e `.md`) no diretório de hoje e copia o documento para a área de transferência. `R` e `M` aparecem no menu de contexto, no which-key e na ajuda do painel.

O módulo do relatório passa a montar itens e renderizá-los num formato, sem que a renderização leia repositório ou estado. O helper de teste do relatório passa a devolver o cabeçalho e os itens de qualquer um dos dois formatos. README: teclas do painel, "Depois de `R`", onde as coisas são gravadas, roteiro de teste manual.

Veja a spec: seções "O documento para o agente", "Quickfix" e as decisões de formato XML, markdown e preâmbulo; ADR-0006 (dois formatos como teclas).

## Blocked by

- Nenhum (pode começar já)