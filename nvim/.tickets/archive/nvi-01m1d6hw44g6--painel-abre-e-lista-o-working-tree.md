---
id: nvi-01m1d6hw44g6
title: Painel abre e lista o working tree
status: closed
type: task
priority: 1
mode: afk
created: '2026-09-01T00:40:21.891904462Z'
updated: '2026-09-01T01:03:25.734255194Z'
closed: '2026-09-01T00:57:03.674604743Z'
assignee: grisotto
parent: nvi-01m1d61ppxj1
tags:
- git
- review
acceptance:
- title: Um atalho abre o painel e um fecha
  done: true
- title: As seções conflitos, staged, unstaged e untracked refletem o estado real do repositório
  done: true
- title: Arquivo com mudança staged e unstaged aparece nas duas seções
  done: true
- title: Arquivo renomeado aparece com o caminho novo e a linha não quebra
  done: true
- title: Cada seção mostra a contagem de arquivos e o cabeçalho mostra a branch
  done: true
- title: Fora de repositório e em repositório sem commits o painel mostra mensagem, não erro
  done: true
- title: Uma tecla atualiza o painel a partir do estado atual do git
  done: true
- title: Posição e largura são configuráveis e o painel não briga com o neo-tree pelo espaço
  done: true
- title: Harness roda em nvim headless com fixture de repositório temporário cobrindo as situações da spec
  done: true
---

## Description

Primeira fatia vertical: o painel de revisão existe, abre e mostra a verdade do repositório. Traz junto o harness de teste, porque não há nenhum neste repositório hoje.

### O que construir

Um atalho abre a janela lateral do painel de revisão. Ele lê o estado do repositório e mostra os arquivos agrupados nas seções conflitos, staged, unstaged e untracked, cada uma com a contagem de arquivos, e a branch atual no cabeçalho. Um arquivo que tem mudança staged e unstaged ao mesmo tempo aparece nas duas seções, porque são duas mudanças diferentes para revisar. Um arquivo renomeado aparece com o caminho novo.

Fora de um repositório, ou num repositório sem nenhum commit, o painel abre com uma mensagem em vez de estourar um erro.

Uma tecla atualiza o painel, outra fecha. Posição e largura são configuráveis, e a convivência com o neo-tree pelo mesmo espaço é resolvida.

### Harness de teste

Esta fatia estabelece a costura única descrita na spec: nvim headless, repositório temporário montado por um helper de fixture, API pública acionada, afirmações sobre as linhas renderizadas no painel e sobre o estado real do git. O runner é o busted do plenary, já instalado como dependência de outro plugin.

O fixture precisa saber montar: arquivo só staged; só unstaged; staged e unstaged ao mesmo tempo; untracked; renomeado; deletado; conflitado; repositório sem commits; diretório que não é repositório.

## Notes

**2026-09-01T00:57:03.674604743Z**

Painel de revisão abrindo e listando o working tree, com o primeiro harness de teste do repositório (plenary busted em nvim headless, 19 testes verdes). Implementado em 69ec605.

**2026-09-01T01:03:25.734255194Z**

Revisão de código pós-fechamento (36f8c3f): corrigidos o `<Leader>gr` colidindo com o "Reset Git hunk" local ao buffer do gitsigns, o estouro em caminho com quebra de linha, a leitura do git sem teto de tempo, a validação de `neo_tree` e o vazamento da marca neo-tree entre testes. Dois achados de baixa severidade ficaram para depois — ver nvi-* de convivência do painel com abas e janela única.
