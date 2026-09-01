---
id: nvi-01m1d6hw839c
title: 'Abrir o que está na linha: diff e arquivo'
status: closed
type: task
priority: 1
mode: afk
created: '2026-09-01T00:40:22.017532405Z'
updated: '2026-09-01T01:23:43.182438847Z'
closed: '2026-09-01T01:23:43.182438847Z'
assignee: grisotto
parent: nvi-01m1d61ppxj1
tags:
- git
- review
acceptance:
- title: Enter numa linha de staged compara HEAD com o índice, ao lado do painel e sem trocar de aba
  done: true
- title: Enter numa linha de unstaged compara o índice com o working tree
  done: true
- title: Uma segunda tecla abre o mesmo diff no diffview
  done: true
- title: Enter num arquivo conflitado abre o merge tool de três vias
  done: true
- title: Uma segunda tecla abre o conflito no layout que inclui a versão base
  done: true
- title: Duas teclas abrem o arquivo de verdade, na janela principal e num split
  done: true
- title: Abrir um diff novo substitui o anterior sem deixar janelas órfãs
  done: true
deps:
- nvi-01m1d6hw44g6
---

## Description

### O que construir

A partir de uma linha do painel, o revisor abre o que aquela linha representa.

Enter abre o diff de duas vias ao lado do painel, na mesma aba, para a lista continuar visível enquanto se lê. O que é comparado depende da seção da linha: numa linha de staged, o HEAD contra o índice; numa linha de unstaged, o índice contra o working tree.

Outra tecla abre o mesmo diff no diffview, em aba própria. As duas convivem de propósito (ADR-0006): o revisor compara as apresentações no mesmo arquivo e o uso decide qual vira o padrão.

Um arquivo conflitado não tem conteúdo no estágio zero do índice, então o diff de duas vias não se aplica: Enter num conflito vai para o merge tool de três vias do diffview, com a versão atual à esquerda, o merge no meio e a que está entrando à direita. Uma segunda tecla abre o mesmo conflito no layout que também mostra a versão base.

Duas teclas abrem o arquivo de verdade, uma na janela principal e outra num split.

### Fronteira

O merge tool, a navegação entre conflitos e a escolha de lado são do diffview (ADR-0005). O diff de duas vias montado na aba do painel é código nosso e é o que os testes cobrem.

## Notes

**2026-09-01T01:23:40.529127818Z**

Enter monta o diff de duas vias ao lado do painel, na mesma aba: HEAD × índice numa linha staged, índice × working tree numa linha unstaged ou untracked, com o arquivo de verdade do lado do working tree. `d` abre a apresentação alternativa (diffview; num conflito, o layout com a versão base) e `o`/`O` abrem o arquivo na janela principal e num split. Conflito não monta diff de duas vias: vai para o merge tool do diffview (ADR-0005), e as duas apresentações convivem em teclas paralelas (ADR-0006).

Módulos novos: `review/diff.lua` (o diff que é código nosso), `review/window.lua` (onde as coisas abrem, ao lado do painel) e `review/actions.lua` (o que cada tecla faz). 16 testes novos, 36 na suíte.

Revisão de código: a troca do layout do merge tool na configuração do diffview guardava como "layout do revisor" um layout nosso quando um segundo conflito era aberto antes de o primeiro fechar, e o layout configurado se perdia pelo resto da sessão — corrigido antes do commit e verificado à mão com o diffview no runtimepath. A costura de teste em docs/agents/testing.md passou a nomear o terceiro item que os testes já precisavam afirmar (o que aparece na tela ao lado do painel); a spec do épico ainda descreve a costura com dois.

**2026-09-01T01:23:43.182438847Z**

Enter abre o diff de duas vias montado no painel; teclas paralelas abrem o diffview, o merge tool e o arquivo.
