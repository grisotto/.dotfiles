---
id: nvi-01m1j90m9vyb
title: 'Marcar e avançar: o laço em uma tecla, na lista e dentro do diff'
status: closed
type: feature
priority: 1
mode: afk
created: '2026-09-02T23:59:34.715713487Z'
updated: '2026-09-03T11:43:30.039476114Z'
closed: '2026-09-03T11:43:30.039476114Z'
assignee: grisotto
parent: nvi-01m1j8zy1rqj
tags:
- git
- review
- plugin-local
acceptance:
- title: v marca e desmarca sem mover o cursor, como hoje
  done: false
- title: Espaço marca visto e leva à próxima não vista na ordem renderizada, sem dar a volta
  done: false
- title: Espaço em cima de um arquivo já visto desmarca e não avança
  done: false
- title: Sem próxima não vista, o cursor vai ao cabeçalho e o painel avisa o total visto
  done: false
- title: ']f e [f dentro do diff abrem o próximo e o anterior não visto sem passar pela lista'
  done: false
- title: ']F e [F andam por todos os arquivos, vistos inclusive'
  done: false
- title: Leader gv marca o que está sendo lido e abre o diff da próxima não vista
  done: false
- title: 'O cursor do painel é a única posição da revisão: lista e diff movem o mesmo cursor'
  done: false
- title: ADR-0009 grava a decisão do cursor único
  done: false
deps:
- nvi-01m1j8zd0zar
---

## Description

### Entregável

O gesto que fecha a revisão: *li este, me leve ao próximo que falta*.

- **`v` não muda**: marca e desmarca, e deixa o cursor onde está. Desmarcar é feito olhando para o arquivo, e uma tecla que saísse de cima dele desfaria a marca e esconderia o que foi desfeito.
- **`<Space>` no painel**: marca visto e desce para a **próxima não vista**, na ordem renderizada (Conflitos → Staged → Unstaged → Untracked, caminho crescente), pulando a seção Vistos e **sem dar a volta**. Só avança quando marcou — desmarcar não avança. Sem próxima, o cursor vai para o cabeçalho e o painel avisa `12/12 vistos`.
- **`]f` / `[f` dentro do diff**: andam pelos arquivos **não vistos** sem voltar à lista — movem o cursor do painel e abrem o diff da entrada, deixando o foco no diff. `]F` / `[F` andam por todos, que é como se volta a um arquivo já visto.
- **`<Leader>gv` global**: marca a entrada sob o cursor do painel e abre o diff da próxima não vista. É o mesmo laço, disparado de dentro do arquivo que está sendo lido — espelha o `<Leader>ga`, que já é "anotar a linha que estou lendo".

### O cursor do painel é a posição da revisão

Uma posição só, compartilhada pela lista e pelo diff: `<CR>`, `]f` e `<Leader>gv` movem todos o mesmo cursor, e é dele que sai a resposta para "qual arquivo eu estou revisando". É o que o IntelliJ faz — a seleção da lista de mudanças segue o diff — e é o que permite `<Leader>gv` funcionar de dentro de um arquivo sem ter que adivinhar qual das duas entradas de um arquivo com mudança staged e unstaged está na tela.

Decisão de modelo, não de apresentação: **vale um ADR** (0009).

### Notas de execução

- `]f`/`[f` e não `<Tab>`/`<S-Tab>`: no working tree o lado direito do diff é o buffer real do arquivo, editável, onde `<Tab>` é indentação. O par de colchetes é o idioma do editor para "próximo desta espécie" e não custa nada ao arquivo.
- `v` está fora dentro do diff pelo mesmo motivo: mataria o modo visual num buffer que o revisor edita. Daí o `<Leader>gv`.
- `<Leader>gv` precisa ser conferido com `nvim_buf_get_keymap` num arquivo rastreado antes de ser fixado, como foi feito com `<Leader>ga` — o gitsigns ocupa letras do grupo `<Leader>g` com mapeamentos locais ao buffer que o `nvim_get_keymap` não enxerga.
- As teclas novas do painel entram no menu de contexto e no which-key pela mesma lista das outras (`panel_actions`), que é o que impede menu e teclas de divergirem.

## Notes

**2026-09-03T11:43:30.039476114Z**

Absorvido: fatiado em nvi-01m1kh78jhtb (o Espaço na lista) e nvi-01m1kh7rw3p7 (o laço de dentro do diff, com o ADR-0009).
