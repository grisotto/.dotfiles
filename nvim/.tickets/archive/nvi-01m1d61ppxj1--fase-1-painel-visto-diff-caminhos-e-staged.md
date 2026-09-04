---
id: nvi-01m1d61ppxj1
title: 'Fase 1: painel, visto, diff, caminhos e staged/unstaged'
status: closed
type: feature
priority: 1
mode: afk
created: '2026-09-01T00:31:32.061654298Z'
updated: '2026-09-03T19:43:08.419443603Z'
closed: '2026-09-03T19:43:08.419443603Z'
assignee: grisotto
parent: nvi-01m1d6164sz2
tags:
- git
- review
acceptance:
- title: Painel lista as seções corretas a partir do estado real do repositório
  done: true
- title: Arquivo com mudança staged e unstaged aparece nas duas seções
  done: true
- title: Renomeado aparece com o caminho novo e a linha não quebra
  done: true
- title: Marcar como visto move o arquivo para a seção Vistos e o contador acompanha
  done: true
- title: Visto sobrevive a reabrir o editor
  done: true
- title: Arquivo que muda depois de marcado volta a aparecer como não visto
  done: true
- title: Caminho relativo usa a raiz do projeto resolvida pelo detector existente
  done: true
- title: Stage, unstage e descartar refletem no estado real do repositório
  done: true
- title: Menu de contexto do botão direito mostra a ação junto do atalho
  done: true
- title: Fora de repositório e em repositório sem commits o painel mostra mensagem, não erro
  done: true
- title: Testes rodam em nvim headless contra repositório temporário, afirmando sobre as linhas do painel e sobre o estado do git
  done: true
---

## Description

Fase autossuficiente: ao fim dela já dá para revisar no dia a dia. Cobre as user stories 1-35 e 59-63 da spec do épico.

### Entregável

Painel de revisão lateral com as seções conflitos, staged, unstaged, untracked e a seção Vistos recolhida no fim, com contador de progresso no cabeçalho. Enter abre o diff de duas vias na aba do painel; outra tecla abre o mesmo diff no diffview; conflito vai para o merge tool de três vias, com uma segunda tecla para o layout que inclui o base. Abrir arquivo, marcar e desmarcar visto, copiar caminho absoluto e caminho relativo à raiz do projeto, mover entre staged e unstaged, descartar com confirmação, atualizar e fechar. Clique esquerdo abre o diff, clique direito abre menu de contexto mostrando ação e atalho. Persistência do visto entre sessões.

### Fora desta fase

Anotações, relatório de revisão, modo commit, grafo, ver e comparar arquivo em outro rev, e o terceiro modo de conflito construído no painel.

## Notes

**2026-09-03T19:43:08.419443603Z**

Fase 1 entregue pelos tickets filhos; suíte verde (317 testes) e os 11 critérios verificados.
