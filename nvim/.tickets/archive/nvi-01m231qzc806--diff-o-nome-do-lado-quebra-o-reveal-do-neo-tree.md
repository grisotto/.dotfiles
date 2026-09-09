---
id: nvi-01m231qzc806
title: 'Diff: o nome do lado quebra o reveal do neo-tree'
status: closed
type: bug
priority: 2
mode: afk
created: '2026-09-09T12:19:36.455988466Z'
updated: '2026-09-09T12:25:06.670225730Z'
closed: '2026-09-09T12:25:06.670225730Z'
assignee: grisotto
parent: nvi-01m1d61ppxj1
tags:
- review
- git
---

## Description

Com o cursor num lado do diff que veio do git, `<leader>e` (`Neotree toggle`) falha com duas mensagens:

```
[WARN ] Root path review:/índice doesn't exist, backing out to review:
[ERROR] debounce filesystem_navigate error: Vim(tcd):E344: Can't find directory "review:" in cdpath
```

**Causa.** O AstroNvim liga `follow_current_file` no neo-tree, então todo toggle é um *reveal* do buffer atual: o neo-tree lê `nvim_buf_get_name(0)` e trata o resultado como caminho de arquivo, sem olhar `buftype`. Os lados que vêm do git são nomeados em `diff.lua` como `review://<rev>/<caminho>`; o `://` faz o Neovim guardar o nome literal, o `vim.fs.normalize` do neo-tree colapsa a barra dupla, e sobra `review:/índice/a.txt`, que não é subcaminho da cwd. Daí o popup "File not in cwd. Change cwd to review:/índice?" e, respondendo sim, a subida por diretórios inexistentes até `review:` — o warn — e o `tcd review:` que estoura E344 dentro do debounce do neo-tree.

Morde sempre que o cursor está numa janela de um lado `review://`: o lado esquerdo de qualquer diff, os dois lados de uma linha staged, todos os lados de um conflito e do modo commit. Com o lado direito do working tree não acontece, porque ali o buffer é o arquivo de verdade.

**Correção.** Nomear os lados dentro da raiz do repositório, com o rev no fim do nome — `<raiz>/<caminho>@<rev>` — em vez do esquema tipo URI. O nome continua dizendo qual versão está na tela, e o reveal do neo-tree passa a cair sob a cwd: ele navega para a raiz, não acha o nó e cala a boca. Falhando por fora do repositório revisado, o pai do nome é um diretório que existe, então nem o warn nem o E344 aparecem.

Toca a linha do `README.md` que documenta o nome e as asserções de nome em `tests/review/open_spec.lua`, `rev_spec.lua` e `preview_spec.lua` — inclusive as que usam `^review://` para dizer que o que está ao lado do painel *não* é um lado de rev, que precisam de outro discriminador.

## Notes

**2026-09-09T12:25:06.536462954Z**

Verificado ponta a ponta com a configuração real (XDG_CONFIG_HOME apontando para este repo, repositório temporário com um arquivo novo staged): o painel monta os lados como <raiz>/novo.txt@HEAD e <raiz>/novo.txt@índice, e o `Neotree toggle` com o cursor no lado do índice abre a árvore na raiz do repositório — sem o popup de trocar a cwd, sem o warn de backing out e sem o E344 no log do neo-tree. Nenhum cliente de LSP passa a anexar nos lados: eles continuam `nofile`.

Suíte: 338 passando, 0 falhas, 0 erros. `make lint`: 0 errors, 0 warnings, 0 parse errors.

**2026-09-09T12:25:06.670225730Z**

Os lados que vêm do git passam a se chamar <raiz>/<caminho>@<rev> em vez de review://<rev>/<caminho>: o reveal do neo-tree cai dentro do repositório revisado e cala a boca.
