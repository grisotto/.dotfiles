---
id: nvi-01m1kh7rw3p7
title: 'O laço de dentro do diff: ]f, [f e o Leader gv'
status: closed
type: feature
priority: 1
mode: afk
created: '2026-09-03T11:42:31.806821381Z'
updated: '2026-09-03T13:12:35.750986591Z'
closed: '2026-09-03T13:12:35.750986591Z'
assignee: grisotto
parent: nvi-01m1j8zy1rqj
tags:
- git
- review
- plugin-local
acceptance:
- title: ']f e [f dentro do diff abrem o próximo e o anterior não visto sem passar pela lista'
  done: true
- title: ']F e [F andam por todos os arquivos, vistos inclusive'
  done: true
- title: As quatro teclas movem o cursor do painel e deixam o foco no diff
  done: true
- title: Leader gv marca o que está sendo lido e abre o diff da próxima não vista
  done: true
- title: O lhs de Leader gv foi conferido com nvim_buf_get_keymap num arquivo rastreado
  done: true
- title: 'O cursor do painel é a única posição da revisão: lista e diff movem o mesmo cursor'
  done: true
- title: ADR-0009 grava a decisão do cursor único
  done: true
deps:
- nvi-01m1kh78jhtb
---

## Description

O mesmo laço do `<Space>`, disparado de onde o revisor está de verdade quase o tempo todo: dentro do arquivo.

- **`]f` / `[f` dentro do diff**: andam pelos arquivos **não vistos** sem voltar à lista — movem o cursor do painel e abrem o diff da entrada, deixando o foco no diff. `]F` / `[F` andam por todos, que é como se volta a um arquivo já visto.
- **`<Leader>gv` global**: marca a entrada sob o cursor do painel e abre o diff da próxima não vista. Espelha o `<Leader>ga`, que já é "anotar a linha que estou lendo".

É o que o IntelliJ (`F7`/`Shift+F7`, atravessando o arquivo sozinho), o Gerrit (`[`/`]`) e o próprio diffview (`<Tab>`/`<S-Tab>`) fazem: o revisor mora no diff e a lista o segue.

### O cursor do painel é a posição da revisão

Uma posição só, compartilhada pela lista e pelo diff: `<CR>`, `]f` e `<Leader>gv` movem todos o mesmo cursor, e é dele que sai a resposta para "qual arquivo eu estou revisando". É o que permite `<Leader>gv` funcionar de dentro de um arquivo sem ter que adivinhar qual das duas entradas de um arquivo com mudança staged e unstaged está na tela.

Decisão de modelo, não de apresentação: **vale um ADR** (0009).

### Notas de execução

- `]f`/`[f` e não `<Tab>`/`<S-Tab>`: no working tree o lado direito do diff é o buffer real do arquivo, editável, onde `<Tab>` é indentação. O par de colchetes é o idioma do editor para "próximo desta espécie" e não custa nada ao arquivo.
- `v` está fora dentro do diff pelo mesmo motivo: mataria o modo visual num buffer que o revisor edita. Daí o `<Leader>gv`.
- `<Leader>gv` precisa ser conferido com `nvim_buf_get_keymap` num arquivo rastreado antes de ser fixado, como foi feito com `<Leader>ga`: o gitsigns ocupa letras do grupo `<Leader>g` com mapeamentos locais ao buffer que o `nvim_get_keymap` não enxerga.
- As teclas do diff entram pelo mesmo caminho do `q` que já fecha o diff (`ReviewDiffKey`), e por isso aparecem na winbar.
- Navegação por *diferença* dentro do arquivo está fora: o `]c`/`[c` do próprio Neovim já faz isso em modo diff.

## Notes

**2026-09-03T13:12:35.750986591Z**

]f/[f andam pelas não vistas e ]F/[F por todas, de dentro do diff, movendo o cursor do painel e deixando o foco no diff; <Leader>gv marca o que está sendo lido e abre a próxima não vista. O cursor do painel vira a posição única da revisão (ADR-0009), na ordem da lista e sem dar a volta — nem pelo cabeçalho. As teclas só agem de dentro de um lado do diff montado, e o diff só apaga da tecla o que foi ele que escreveu.
