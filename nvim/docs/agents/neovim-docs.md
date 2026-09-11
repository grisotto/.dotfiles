# Documentação do Neovim

A resposta de uma dúvida sobre o Neovim está na documentação da versão
instalada. A memória e a web podem descrever outra versão: o arquivo de uma
entrada muda de nome, uma função ganha ou perde campo, um evento passa a
disparar diferente.

## Onde está

- **Neovim:** `$VIMRUNTIME/doc/*.txt`. O caminho sai de
  `nvim --headless --clean -c 'lua io.stdout:write(vim.env.VIMRUNTIME)' -c qa`,
  e a versão de `nvim --version`.
- **Plugins:** `~/.local/share/nvim/lazy/<plugin>/doc/`. O plugin sem `doc/` —
  o heirline é um — responde pelo código, no `lua/` do mesmo diretório. O
  código também é a resposta quando a documentação não diz o que o plugin faz
  por conta própria: que o heirline reescreve a winbar a cada `BufWinEnter` só
  estava no `lua/heirline/init.lua`.
- **Link para a web:** com a versão fixada,
  `https://github.com/neovim/neovim/blob/v<versão>/runtime/doc/<arquivo>.txt`.

## Como achar uma entrada

O arquivo `tags` de cada `doc/` diz em que `.txt` cada entrada está:

```sh
# o shell não tem $VIMRUNTIME; é o Neovim que sabe
VIMRUNTIME=$(nvim --headless --clean -c 'lua io.stdout:write(vim.env.VIMRUNTIME)' -c qa)
rg -P '^getmousepos\(\)\t' "$VIMRUNTIME/doc/tags"        # → vimfn.txt
rg -n '\*getmousepos\(\)\*' "$VIMRUNTIME/doc/vimfn.txt"  # → a linha
```

Com a linha, leia o trecho com o Read. As entradas têm a forma do `:help`:
função com `()` (`nvim_win_call()`, `vim.schedule()`), opção entre aspas
simples (`'winbar'`), evento pelo nome (`OptionSet`), tópico com hífen
(`autocmd-nested`). O `tags` de um plugin funciona do mesmo jeito.

Sem o nome exato, pelo assunto:

| Assunto | Arquivo |
| --- | --- |
| `nvim_*`, janelas flutuantes | `api.txt` |
| `vim.*` do Lua (`vim.keymap`, `vim.schedule`, `vim.fs`) | `lua.txt` |
| `vim.fn.*` | `vimfn.txt` |
| opções | `options.txt` |
| eventos, autocmds e quando eles aninham | `autocmd.txt` |
| mapeamentos | `map.txt` |
| janelas e splits | `windows.txt` |
| modo diff | `diff.txt` |
| convenções de plugin em Lua | `lua-plugin.txt` |
| o que mudou de uma versão para outra | `news.txt`, `deprecated.txt` |

## Quando a entrada é vaga

A entrada que não decide a dúvida se resolve rodando, e não lendo mais:
`getmousepos()` diz só "row inside winid", sem dizer se a winbar conta. Um
`nvim --headless --clean` responde, com o teste dentro de `vim.defer_fn`: os
comandos de `-c` rodam antes do `VimEnter`, e `OptionSet` e outros eventos não
disparam antes dele. Com a configuração real no lugar do `--clean`, o molde é o
de `debugging.md`.
