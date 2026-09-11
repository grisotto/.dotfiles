---
id: nvi-01m28t7sxfk9
title: Inventário do que o NvChad tinha e o AstroNvim v6 não repôs
status: open
type: task
priority: 3
mode: hitl
created: '2026-09-11T18:03:53.134603512Z'
updated: '2026-09-11T18:35:05.249357336Z'
assignee: grisotto
tags:
- migracao
- teclas
links:
- nvi-01m28w0y5hnv
---

## Description

O commit `fb75081` ("astrovim6", 31/08) trocou a configuração NvChad v2.5 pelo template do AstroNvim v6 num salto só, apagando `lua/chadrc.lua`, `lua/mappings.lua`, `lua/options.lua`, `lua/plugins/init.lua`, `lua/configs/{lazy,conform,lspconfig}.lua` e `lua/utils/*` — 689 linhas. O andaime do v6 ficou correto; o que ficou para trás foi a ergonomia pessoal.

Este ticket é o inventário, para triagem item a item: cada linha é uma escolha ("quero de volta", "o v6 já resolve de outro jeito", "não uso mais"), não um bug. O conteúdo original se recupera com `git show fb75081^:nvim/lua/<arquivo>`.

### Plugins que sumiram

- **harpoon** (`<leader>a` marcar, `<leader>sss` desmarcar, `<C-e>` menu). Existe `astrocommunity.motion.harpoon`. Atenção: `<Leader>a` é o prefixo do Agilis (`lua/agilis.lua`) dentro do workspace do Hickory — fora dele está livre.
- **neoscroll** (`astrocommunity.scrolling.neoscroll-nvim`).
- **vim-exchange** (`astrocommunity.editing-support.vim-exchange`).
- **vim-sexp** + `vim-sexp-mappings-for-regular-people`. O pack `clojure` já traz parpar (parinfer + paredit) — conferir se cobre o gesto.
- **conform.nvim** (`stylua`, `prettier`). O v6 formata por none-ls; existe `astrocommunity.editing-support.conform-nvim`.
- **ALE** com `clj-kondo` e `joker` para Clojure. O pack `clojure` já traz clj-kondo.
- **auto-session**. Provavelmente já reposto: `astrocore.lua` configura `sessions.autosave` e o autocmd `restore_session` com resession. Confirmar e riscar.

### Teclas que sumiram

| Antiga | Situação hoje no v6 |
| --- | --- |
| `;` → `:` | livre |
| `jj` → `<Esc>` no insert | livre (o better-escape.nvim está instalado e sem tecla) |
| `]c` / `[c` navegar hunk | o v6 usa `]g` / `[g` ("Next/Previous Git hunk") |
| `<leader>cP`, `<leader>cs`, `<leader>rh`, `<leader>cr` (gitsigns) | sem equivalente mapeado |
| `<leader>w` / `<leader>v` abrir split | `<Leader>w` é **Save** no v6; `<Leader>v` está livre |
| `<leader>ls` rodar `snyk test` | `<Leader>ls` é **Search symbols** no v6 |
| `<leader>dd` abrir Chrome com perfil de debug | livre. Era WSL (`/mnt/c/Users/...`) — conferir se ainda faz sentido |
| `<localleader>gl` link do GitHub da linha | perdido com `lua/utils/git_utils.lua`. Existem `astrocommunity.git.gitlinker-nvim` e `git.openingh-nvim` |
| `K`, `<leader>rS`, `ln`, `le`, `lf`, `la`, `lw`, `lr`, `li`, `<leader>pO` (LspAttach) | o v6 tem `<Leader>l*` próprio (`lD lS ld li ls lv` globais, mais os locais ao buffer) e o `recipes.picker-lsp-mappings` já importado. Provavelmente redundante — comparar antes de repor |

### Ajuste fino de servidor LSP

Hoje `lua/plugins/astrolsp.lua` tem `servers = {}` e `config = {}`: tudo vem dos packs do astrocommunity, sem nenhuma opção nossa. O `lua/configs/lspconfig.lua` do NvChad tinha:

- **angularls** — `cmd` com `--tsProbeLocations` e `--ngProbeLocations` em `/usr/local/lib/node_modules`, `filetypes` incluindo `html`, `root_pattern("angular.json", ".git")`.
- **terraformls** — `filetypes` `terraform/hcl/tf/tfvars`, `init_options.experimentalFeatures.validateOnSave = true`, `root_pattern(".terraform", ".git")`.
- **pyright** — `typeCheckingMode = "basic"`, `autoImportCompletions = true`, `diagnosticMode = "workspace"`. (O Mason hoje tem **basedpyright** instalado, não pyright.)

No v6 isso vai em `astrolsp.opts.config[<servidor>]` ou num arquivo `lsp/<servidor>.lua` na raiz da configuração (`:h lsp-config`).

### Tema

O NvChad usava base46 `nightowl`. Hoje é `catppuccin-mocha` (`astroui.lua`). Registrado só para constar que foi troca, não perda.
