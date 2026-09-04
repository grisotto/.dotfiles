---
id: nvi-01m1j8ywyy2w
title: Painel de revisão aparece fora da janela dele e toma a tela
status: closed
type: bug
priority: 1
mode: afk
created: '2026-09-02T23:58:38.046583388Z'
updated: '2026-09-03T00:29:51.339602825Z'
closed: '2026-09-03T00:29:51.339602825Z'
assignee: grisotto
parent: nvi-01m1d6164sz2
tags:
- git
- review
- plugin-local
acceptance:
- title: O buffer do painel exibido em outra janela volta sozinho para o que estava lá, e o painel segue na faixa dele
  done: true
- title: Nada consegue abrir outro buffer dentro da janela do painel
  done: true
- title: Fechar ou redimensionar outra janela não muda a largura do painel; redimensionar o painel focado, sim
  done: true
- title: O q do painel nunca fecha a janela de conteúdo do revisor
  done: true
- title: Teste exibe o buffer do painel na janela de conteúdo e afirma que ela volta ao arquivo
  done: true
---

## Description

### Sintoma

Com o painel aberto, abrir outra coisa (`<Leader>n`, que na AstroNvim é `:enew`, ou um seletor de arquivos), escolher um arquivo e depois apertar uma tecla ou voltar deixa o **conteúdo do painel na janela grande**, em vez de na faixa à esquerda.

### Causa

Duas portas abertas em `lua/review/panel.lua`:

1. `M.win()` devolve **qualquer** janela da aba que esteja mostrando o buffer do painel. Basta o buffer aparecer na janela de conteúdo — por `<C-^>`, por um seletor, por qualquer plugin que escolha "a última janela usada" — para que ela passe a ser "o painel" para todas as ações. Inclusive para o `q`, que então fecha a janela de trabalho do revisor.
2. A janela do painel tem `winfixwidth`, mas nada impede que outro buffer seja aberto *dentro* dela, e nada impede que o buffer do painel seja mostrado *fora* dela. `winfixwidth` também não segura a largura quando uma janela vizinha é fechada: o espaço vai para o vizinho de qualquer jeito.

### Solução

- `winfixbuf` na janela do painel (o editor em uso é 0.12), salva e restaurada junto das outras de `WINDOW_OPTIONS`, e desligada antes do `:enew` de `give_up_win`.
- O painel guarda o winid da janela dele. `win_of` prefere esse winid e só cai na varredura por buffer quando ele não vale mais — a varredura é o que hoje elege a janela errada.
- Autocmd `BufWinEnter`: o buffer do painel exibido numa janela que não é a dele é despejado — a janela volta ao buffer que estava lá (`#`) ou a um buffer vazio. Uma bandeira durante o `open_win` impede que o despejo alcance a janela que o próprio painel acabou de criar.
- Autocmd `WinResized`/`WinClosed`: a largura do painel é restaurada quando ele **não** é a janela atual; quando é, a largura nova vira a dele — redimensionar o painel com ele focado é gesto do revisor, o resto é acidente de layout.

O painel viver numa janela só já é o que o ADR-0001 decidiu. Isto é fazer o código sustentar a decisão em vez de confiar que ninguém vai mexer.

## Notes

**2026-09-03T00:29:47.960057769Z**

A revisão do diff levantou dois pontos que ficam fora daqui:

- `window.content` (lua/review/window.lua) devolve ao painel a largura que ele tinha antes de dividir, e essa função só roda quando o painel está sozinho na aba — quando a largura dele é a da tela inteira. O arquivo aberto ao lado nasce com uma faixa de nada. Com a largura guardada isso se corrige sozinho no tique seguinte (o `WinResized` devolve ao painel a largura dele, e o resto vai para o conteúdo), mas o meio do caminho continua feio.
- `win_of` ainda cai na varredura por buffer quando o winid não vale mais, que foi o que o ticket pediu. Com o despejo cobrindo `BufWinEnter` e `WinNew`, ela é último recurso — mas continua sendo o caminho por onde uma janela errada seria eleita se algum dia o despejo não alcançar (um `eventignore`, por exemplo).

**2026-09-03T00:29:51.339602825Z**

O painel guarda o winid da janela dele e a largura dela; `winfixbuf` mantém outro buffer fora, e o despejo por BufWinEnter e WinNew mantém o buffer do painel dentro.
