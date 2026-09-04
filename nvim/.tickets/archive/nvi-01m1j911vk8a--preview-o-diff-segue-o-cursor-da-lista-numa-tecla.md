---
id: nvi-01m1j911vk8a
title: 'Preview: o diff segue o cursor da lista, numa tecla'
status: closed
type: feature
priority: 2
mode: afk
created: '2026-09-02T23:59:48.595637572Z'
updated: '2026-09-03T11:43:30.186799430Z'
closed: '2026-09-03T11:43:30.186799430Z'
assignee: grisotto
parent: nvi-01m1j8zy1rqj
tags:
- git
- review
- plugin-local
acceptance:
- title: A tecla p liga e desliga o preview com o painel aberto, e o padrão vem da opção preview
  done: false
- title: Com o preview ligado, mover o cursor desenha o diff da entrada ao lado sem tirar o foco da lista
  done: false
- title: O preview não redesenha quando a entrada sob o cursor não mudou
  done: false
- title: O preview não dispara quando o painel não é a janela atual
  done: false
- title: Um conflito no preview mostra as três versões, sem trocar de aba
  done: false
- title: A tecla p aparece no menu de contexto e no which-key como as outras
  done: false
deps:
- nvi-01m1j8ywyy2w
---

## Description

### Entregável

A varredura do lazygit e do Sublime Merge: mover o cursor na lista já desenha o diff ao lado, sem apertar nada.

- Opção `preview` (padrão **desligado**) e tecla **`p`** no painel que liga e desliga ao vivo. Tecla, e não só opção: varrer e ler são dois momentos da mesma revisão, e alternar entre eles é gesto, não mudança de configuração. É o mesmo princípio do ADR-0006.
- `CursorMoved` no buffer do painel, com debounce (~80ms), **só** quando o painel é a janela atual e **só** quando a entrada sob o cursor mudou. Sem isso, cada `j` numa lista de cem arquivos custa dois `git show` e a tela pisca durante uma navegação que muitas vezes é só chegar lá embaixo.
- O preview **não rouba o foco**: precisa de uma variante do `diff.open` que monte as janelas e deixe o cursor onde está. Hoje o `build` termina em `nvim_set_current_win`, que é o certo para o `<CR>` e o errado para o preview.
- Um conflito segue indo para o merge tool no `<CR>`; no preview ele mostra as três versões no painel, que é a apresentação que não troca de aba.

### Por que padrão desligado

O revisor que desce a lista está, na maior parte das vezes, a caminho de um arquivo específico. Ligado por padrão, o preview cobra o custo de ler todos os arquivos do caminho. Quem varre liga com `p` e desliga quando começa a ler de verdade.

## Notes

**2026-09-03T11:43:30.186799430Z**

Absorvido: republicado sem mudança como nvi-01m1kh83jb71.
