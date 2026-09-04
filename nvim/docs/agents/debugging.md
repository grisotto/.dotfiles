# Depurar o que só acontece no editor do revisor

A suíte roda num editor headless montado pelo `minimal_init`: só este
repositório, o plenary, o astrocore e o mini.icons, num repositório temporário
do fixture. A sessão do revisor tem tudo o que a suíte não tem — a configuração
real inteira, o layout de janelas que ele foi construindo, o painel por aba,
plugins que reescrevem teclas — e é por isso que "não funciona aqui" convive com
uma suíte verde.

Quando isso acontecer, não adivinhe: tire um retrato da sessão. A regra é uma
só, e é a mesma dos testes — comparar **o que o plugin acha** com **o que o
editor mostra**. Quase toda falha desse tipo é os dois discordando.

## O retrato da sessão

O revisor roda um script no editor dele; o script **grava um arquivo**; o agente
lê o arquivo. O `print` sozinho não serve: ele fica no `:messages` do revisor, e
tirá-lo de lá custa uma volta de copiar e colar a cada pergunta.

1. Escreva o script em `~/.config/nvim/review-diag.lua` (a raiz da configuração
   não é carregada pelo Neovim, então um arquivo solto ali é inerte).
2. Peça: *"rode `:luafile ~/.config/nvim/review-diag.lua` na situação em que
   falha e diga pronto"*.
3. Leia `~/.local/share/nvim/review-diag.txt` — o caminho sai de
   `vim.fn.stdpath "data"`, que é onde o plugin já grava o estado da revisão.
4. Apague o script quando terminar.

O molde, que é o da vez que isto achou o bug do laço:

```lua
local out = {}
local function say(...) out[#out + 1] = table.concat(vim.tbl_map(tostring, { ... }), " ") end

local ok, err = pcall(function()
  local panel = require "review.panel"
  local diff = require "review.diff"

  -- 1. o que o plugin acha
  say("aba atual:", vim.api.nvim_get_current_tabpage())
  say("painel que o plugin acha nesta aba:", panel.win() or "NENHUM")
  say("diff mostrando:", (diff.showing() or {}).path or "NADA")

  -- 2. o que o editor mostra
  say "-- janelas desta aba, da esquerda para a direita --"
  local wins = vim.api.nvim_tabpage_list_wins(0)
  table.sort(wins, function(a, b) return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2] end)
  for _, w in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(w)
    say(("  janela %d: buffer %d filetype=%s nome=%s"):format(w, buf, vim.bo[buf].filetype, vim.api.nvim_buf_get_name(buf)))
  end

  -- 3. de quem são as teclas em questão
  for _, lhs in ipairs { "]f", "[f", "]c" } do
    local map = vim.fn.maparg(lhs, "n", false, true)
    say(("mapa de %s: buffer=%s desc=%s"):format(lhs, tostring(map.buffer), tostring(map.desc)))
  end

  -- 4. a própria função que falha, chamada direto
  say("step por ler (]f):", panel.step { direction = 1, unseen = true })
end)
if not ok then say("ERRO:", err) end

local path = vim.fn.stdpath "data" .. "/review-diag.txt"
vim.fn.writefile(vim.split(table.concat(out, "\n"), "\n"), path)
print(table.concat(out, "\n") .. "\n\ngravado em " .. path)
```

As quatro perguntas são o roteiro:

1. **o que o plugin acha** — o estado dele, pela API pública (`panel.win`,
   `panel.mode`, `panel.repository`, `diff.showing`);
2. **o que o editor mostra** — a lista de janelas com filetype e nome, os
   buffers, o que está na tela. Sem isto o retrato não separa "sumiu da tela" de
   "está na tela e o plugin perdeu": a primeira versão do diagnóstico dizia só
   `painel: NENHUM`, e custou uma volta a mais para descobrir qual dos dois era;
3. **de quem é a tecla** — `maparg(lhs, "n", false, true)` devolve `desc` e
   `buffer`, que é como se sabe se a tecla ainda é nossa ou se outro plugin a
   reescreveu (o treesitter do AstroNvim reescreve `]f` a cada `FileType`);
4. **a função que falha, chamada direto**, com o valor que ela devolve — é o que
   separa "a tecla não chegou" de "a tecla chegou e a função desistiu".

Envolva tudo num `pcall` e grave o erro: um retrato que estoura no meio não diz
nada, e a linha que estourou costuma ser a resposta.

## A reprodução headless com a configuração real

O outro lado do mesmo problema: rodar a configuração **real** (e não a da
suíte) sobre um repositório de mentira, para ver se o comportamento aparece sem
o revisor no meio.

```sh
cd /caminho/para/um/repo/de/teste
nvim --headless -c "lua vim.defer_fn(function() dofile('/caminho/probe.lua') vim.cmd 'qa!' end, 4000)"
```

- o `defer_fn` dá ao lazy.nvim tempo de carregar os plugins antes do script;
- a saída sai por `io.stderr:write`, que atravessa o `--headless`;
- dentro do script, `vim.wait(ms, cond)` espera o que é assíncrono (o painel
  abrir, o diff montar) em vez de dormir um tempo fixo.

É o que confirma um conserto no ambiente do revisor, e é também o que inocenta a
configuração: se o gesto funciona aqui e não na sessão dele, o que difere é
estado de sessão — aba, layout, painel fechado —, e não a configuração.

## O que isto já achou

`]f` e `[f` que não andavam com `]c` andando: as teclas eram nossas, o diff
estava montado, e o painel não estava na aba. O `step` procurava a janela da
lista e desistia calado. Virou a atualização do ADR-0009 — a revisão anda com a
lista fechada — e as mensagens que dizem o que a impediu.
