---
id: nvi-01m1j8zd0zar
title: Diff aberto não diz como se fecha, e fechar pela metade deixa o editor em diff
status: closed
type: bug
priority: 1
mode: afk
created: '2026-09-02T23:58:54.495156183Z'
updated: '2026-09-03T01:02:38.581763320Z'
closed: '2026-09-03T01:02:38.581763320Z'
assignee: grisotto
parent: nvi-01m1d6164sz2
tags:
- git
- review
- plugin-local
acceptance:
- title: Toda janela de diff aberta pelo painel mostra na winbar o lado que está exibindo
  done: true
- title: A winbar da janela mais à direita mostra o atalho que fecha o diff
  done: true
- title: q fecha o diff inteiro de qualquer uma das janelas e devolve o foco ao painel
  done: true
- title: Fechar uma janela do diff por fora derruba a outra e não deixa diffthis ligado em nada
  done: true
- title: O buffer real do arquivo não fica com o mapeamento nem com a winbar depois que o diff sai
  done: true
- title: Testes cobrem fechar pelo q e fechar por fora
  done: true
---

## Description

### Sintoma

Com o diff aberto — dois arquivos lado a lado — não há atalho que o feche, e nada na tela diz qual seria. Fechar uma das janelas na mão (`<Leader>x`, `:q`) deixa a outra metade sozinha, ainda em modo diff.

### Causa

`mappings.close` (`q`) só é mapeado no `open_rev` (`lua/review/diff.lua:334`), que é a consulta de um rev — uma janela só. O diff de duas vias (`M.open`) e as três versões de um conflito (`M.open_conflict`) não mapeiam nada.

E fechar por buffer é pior do que parece: no working tree o lado direito **é o buffer real do arquivo** (`file_buf`), não uma cópia — é o que deixa o revisor corrigir o que está lendo. `<Leader>x` ali mexe no arquivo do revisor, e a janela que sobra fica com `diffthis` ligado, colorindo um arquivo que não está sendo comparado com nada.

### Solução

- **Winbar em cada janela do diff**: o nome do lado à esquerda (`índice`, `a1b2c3d`, `atual`/`base`/`entrando`), e na janela mais à direita, alinhados à direita, os atalhos. É a resposta à pergunta "como fecho isto" no lugar onde ela é feita, e é o mesmo princípio do menu de contexto (ADR-0008): a ação aparece junto do atalho dela.
- **`q` fecha o diff inteiro** a partir de qualquer uma das janelas dele e devolve o foco ao painel — inclusive do lado do working tree. O mapeamento é local ao buffer e é **removido quando o diff é desmontado**, junto com a winbar que a janela tinha antes: o buffer do arquivo é do revisor, e não pode ficar com tecla nossa depois que o diff sai.
- **`WinClosed` numa janela do diff derruba o diff inteiro**: não existe meio diff na tela, e nenhuma janela fica com `diffthis` ligado sozinha. É o que torna `<Leader>x` inofensivo em vez de proibido.

A winbar é também onde os atalhos de navegação entre arquivos vão aparecer quando a tarefa do laço entrar.

## Notes

**2026-09-03T01:02:38.581763320Z**

A winbar de cada janela do diff diz o lado, e a mais à direita as teclas; q fecha o diff inteiro de qualquer lado e volta ao painel; uma janela que sai — fechada ou trocada de buffer — derruba o resto, sem deixar tecla, winbar nem diffthis para trás.
