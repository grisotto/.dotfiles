# Rodar o Neovim como agente: mandar teclas, ler a tela, esperar o assíncrono

Pesquisa feita em 2026-09-11 contra o Neovim **0.12.5** instalado
(`/opt/nvim-linux-x86_64`), o tmux **3.7c** e os projetos abaixo, cada um fixado
num commit. Toda afirmação tem fonte. Há três tipos:

- **doc**: entrada do `:help` do 0.12.5, com o arquivo, a tag e o link fixado em
  `v0.12.5`;
- **código**: arquivo e linhas de um repositório, num commit ou tag;
- **experimento E*n***: rodado nesta máquina, com Neovim 0.12.5 e tmux 3.7c, no
  sandbox de shell. É observação de comportamento, não é documentação. Os
  resultados estão na seção [Experimentos locais](#experimentos-locais).

O que não foi possível confirmar na fonte está marcado **Não confirmado** e
reunido em [Não confirmado](#não-confirmado).

---

## 1. Resumo de uma tela

| Abordagem | Como entra no Neovim | Teclas | O que lê | Espera | Socket? | Para quê |
| --- | --- | --- | --- | --- | --- | --- |
| **Headless com script** (`--headless -c`, `-l`, plenary) | o próprio processo | `nvim_feedkeys(…, 'x')` | a API inteira; a tela por `screenstring()`/`screenattr()` | `vim.wait(ms, cond)` | não | afirmar sobre buffers, janelas, mapas e texto na tela, rápido e dentro da suíte |
| **`--embed` + `nvim_ui_attach`** (cliente de UI) | processo filho, msgpack-RPC por stdio | `nvim_input` | eventos `redraw`: grade, cursor, modo, mensagens e cmdline estruturados | até o evento `flush` com o estado esperado | **não** | ler a tela sem terminal e disparar os eventos do laço principal |
| **`--embed --headless` sem UI** | processo filho por stdio | `nvim_input` | a API por `nvim_exec_lua`; a tela por `screenstring()` | laço de consulta (`nvim_get_mode`, variável) | **não** | dirigir um editor "como o usuário" sem montar um cliente de UI |
| **RPC por socket** (`--listen`, `--server`) | processo já rodando | `nvim_input`, `--remote-send` | a API; `--remote-expr` | laço de consulta com `--remote-expr` | sim | inspecionar ou dirigir a sessão que já está aberta |
| **tmux** (`send-keys`, `capture-pane`) | pty real, com a TUI de verdade | `send-keys` | o texto da tela como o terminal mostra; atributos com `-e` | laço `until capture-pane | grep` | não (só o socket do próprio tmux) | ver exatamente o que o revisor vê, com a configuração real |
| **mini.test child** | filho `--headless --listen` + `sockconnect` | `child.type_keys` (`nvim_input`) | `child.lua*`; captura de tela por `screenstring`/`screenattr` | `vim.loop.sleep` entre teclas; `is_blocked` | sim (pipe em `tempname()`) | suíte com capturas de tela de referência |
| **Screen tests do Neovim** | filho `--embed --headless` por stdio | `feed` (`nvim_input`) | a grade completa, com atributos e `ext_*` | `screen:expect` roda o laço até casar ou estourar o tempo | não | referência de como se faz; não é interface pública |
| **MCP** | cliente MCP → servidor → socket do Neovim | `nvim_input`/`command` | o que as ferramentas expõem | depende do servidor | sim | dar a um agente acesso à sessão viva do usuário |

Qual usar:

- **Afirmar dentro da suíte:** headless, que é o que a suíte já faz. Para
  afirmar sobre a tela, some `screenstring()` depois de um redraw. É a mesma
  técnica da captura do mini.test, e não pede dependência nova.
- **Eventos do laço principal** (`CursorMoved`, `WinResized`): um filho
  `--embed --headless` dirigido por `nvim_input`. Por stdio, sem socket (E9).
- **Validar com a configuração real, como o revisor vê:** tmux (E6–E8). Quando
  a pergunta é sobre estado, junte o retrato de `docs/agents/debugging.md`
  gravando num arquivo.
- **Ler a tela estruturada sem terminal:** um cliente `--embed` com
  `nvim_ui_attach`, por stdio (E4).

---

## 2. As abordagens

### 2.1 Headless com script

**Como funciona.**

- `--headless` sobe sem UI e não espera `nvim_ui_attach`. A TUI embutida não é
  usada, então o stdio fica livre como canal ([doc: `starting.txt` `*--headless*`][st-headless]).
- Para saber se há UI, consulta-se `nvim_list_uis()` durante ou depois do
  `VimEnter` ([doc][st-headless]).
- `-l {script}` executa um script Lua "non-interactively (no UI)" e sai. Pula a
  configuração do usuário sem `-u`, desliga plugins sem `'loadplugins'` e liga
  `'verbose'`=1 para que `print()` saia na saída ([doc: `starting.txt` `*-l*`][st-l]).
- `-u {vimrc}` escolhe o arquivo de inicialização; `NONE` pula tudo e `NORC`
  mantém os plugins ([doc: `*-u*`][st-u]).
- `--clean` imita uma instalação limpa: não lê shada, tira os diretórios do
  usuário do `'runtimepath'` e carrega os plugins embutidos ([doc: `*--clean*`][st-clean]).
- `-es` é o modo script: sem UI, sem a maioria dos prompts e mensagens, e
  imprime só `:print`, `:list`, `:number` e `:set` ([doc: `*-es*`][st-es]).
  `--headless` existe também "to see messages that would not be printed by -es"
  ([doc][st-headless]).

**O que se observa.**

- **Buffers, janelas, mapeamentos e opções:** pela API, direto.
- **A tela:**
  - `screenstring({row}, {col})` devolve o caractere na posição da tela, "mainly
    to be used for testing" ([doc: `vimfn.txt` `*screenstring()*`][fn-screenstring]).
  - `screenattr()` devolve um número de atributo que "can only be used to
    compare to the attribute at other positions" ([doc: `*screenattr()*`][fn-screenattr]).
  - Num headless sem nenhuma UI, `screenstring()` lê texto, statusline e janela
    flutuante com borda (E1).
- **Um porém antes do `VimEnter`:**
  - Os comandos de `-c` rodam com `v:vim_did_enter=0`.
  - O **primeiro** `:redraw` desenhou a flutuante no lugar errado e sem o buffer
    de baixo.
  - Depois de `vim.wait(100)` e outro `:redraw` (ou `:redraw!`, ou
    `nvim__redraw({flush=true})`), a tela ficou certa (E1).
  - A causa não foi achada. **Não confirmado.**
- **Mensagens:**
  - `vim.ui_attach()` (experimental) recebe os eventos `ext_messages`,
    `ext_cmdline` e `ext_popupmenu` num callback Lua, no mesmo processo
    ([doc: `lua.txt` `*vim.ui_attach()*`][lua-ui-attach]).
  - Desde a 0.11, o callback de `msg_show` roda em contexto `api-fast`
    ([doc: `news-0.11.txt`][news-011]).
- **Teclas recebidas:** `vim.on_key()` escuta toda tecla "after mappings have
  been applied"; `typed` traz as teclas antes dos mapeamentos
  ([doc: `lua.txt` `*vim.on_key()*`][lua-on-key]).

**Como esperar o assíncrono.**

- `vim.wait(time, callback, interval)` espera até `callback` devolver `true`,
  processando outros eventos enquanto isso ([doc: `lua.txt` `*vim.wait()*`][lua-wait]).
  - Não pode ser chamado durante um evento `api-fast`, desde a 0.10
    ([doc: `news-0.10.txt`][news-010]).
  - Na 0.12 passou a devolver os resultados do callback ([doc: `news.txt`][news-012]).
- `vim.schedule(fn)` agenda `fn` no laço principal ([doc: `*vim.schedule()*`][lua-schedule]).
- `vim.defer_fn(fn, timeout)` é um timer de um disparo, já agendado
  ([doc: `*vim.defer_fn()*`][lua-defer]).
- Quem roda num evento "fast" (`vim.in_fast_event()`) não pode mexer em estado
  do editor e tem que agendar ([doc: `api.txt` `*api-fast*`][api-fast];
  [doc: `*vim.in_fast_event()*`][lua-in-fast]).

**Limites.**

- **Os eventos do laço principal não chegam.**
  - Tecla mandada por `nvim_feedkeys(…, 'x')` dentro do processo mudou a
    largura da janela sem disparar `WinResized` (E9).
  - A mesma tecla por `nvim_input` num processo filho disparou (E9).
  - `docs/agents/testing.md` já registra o mesmo para `CursorMoved`,
    `WinResized` e `VimResized`.
- **Mouse:** `nvim_input_mouse()` é "Send mouse event from GUI" e usa grade e
  posição de UI ([doc: `api.txt` `*nvim_input_mouse()*`][api-input-mouse]).
  Que ele não faz nada sem UI presa foi registrado em `docs/agents/testing.md`;
  não foi reverificado aqui.
- **plenary** (a suíte deste repositório):
  - `PlenaryBustedDirectory` roda cada `*_spec.lua` num Neovim
    `--headless -c 'lua require("plenary.busted").run(…)'` separado, com
    `timeout` padrão de 50 000 ms ([código: `test_harness.lua` L43-L110][pl-harness];
    [doc: README L224-L280][pl-readme]).
  - Suporta `describe`, `it`, `pending`, `before_each`, `after_each`, `clear` e
    `assert.*` ([README L263-L271][pl-readme]).
  - Não oferece nada para teclas nem para tela: a seção do `test_harness` no
    README só lista esses itens.
  - Como os specs rodam de dentro de `-c`, rodam antes do `VimEnter` (E1).

**Exemplo mínimo** (E1):

```lua
-- nvim --headless --clean -c "luafile tela.lua" -c "qa!"
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "FLOAT" })
vim.api.nvim_open_win(buf, false, { relative = "editor", row = 1, col = 2, width = 8, height = 1, border = "single" })
vim.wait(100) -- um giro do laço antes do redraw (E1)
vim.cmd.redraw()
local rows = {}
for r = 1, 4 do
  local s = {}
  for c = 1, 14 do s[#s + 1] = vim.fn.screenstring(r, c) end
  rows[#rows + 1] = table.concat(s)
end
io.stdout:write(table.concat(rows, "\n") .. "\n")
```

### 2.2 `--embed` com `nvim_ui_attach`: ler a tela sem terminal

**Como funciona.**

- `--embed` usa "stdin/stdout as a msgpack-RPC channel". O Neovim sai se o
  canal fechar ([doc: `starting.txt` `*--embed*`][st-embed]).
- Sem `--headless`, ele **espera** um `nvim_ui_attach()` antes de ler a
  configuração e os buffers.
- Quem não é UI passa `--embed --headless`, o que equivale a
  `--headless --cmd "call stdioopen({'rpc': v:true})"` ([doc][st-embed];
  [doc: `*channel-stdio*`][ch-stdio]; [doc: `*stdioopen()*`][fn-stdioopen]).
- `jobstart(cmd, {rpc = true})` sobe o filho e fala msgpack-RPC pelo stdio
  dele ([doc: `vimfn.txt` `*jobstart()*`][fn-jobstart]). O exemplo do `:help`
  usa `jobstart(['nvim', '--embed'], {'rpc': v:true})` com `rpcrequest`
  ([doc: `api.txt` `*rpc-connecting*`][api-rpc]; [doc: `*nvim_exec_lua()*`][api-exec-lua]).
- Um canal RPC é "implicitly trusted": o outro lado chama qualquer função da API
  ([doc: `*channel-rpc*`][ch-rpc]).

**O protocolo de UI.**

- `nvim_ui_attach(width, height, options)` "Activates UI events on the
  channel" e é o que deixa o `--embed` continuar a subir.
  - Com várias UIs presas, a tela global fica do tamanho da menor.
  - É "RPC only" ([doc: `api.txt` `*nvim_ui_attach()*`][api-ui-attach]).
- As opções `ext_*` ([doc: `api-ui-events.txt` `*ui-option*`][ui-option]):
  - `ext_linegrid`: eventos de grade por linha; recomendado para UIs novas.
  - `ext_multigrid`: uma grade por janela; liga `ext_linegrid`.
  - `ext_messages`: mensagens como eventos; liga `ext_linegrid` e `ext_cmdline`.
  - `ext_cmdline`, `ext_popupmenu`, `ext_tabline`, `ext_hlstate`.
- O Neovim manda notificações `redraw` com lotes de eventos ([doc: `*ui-events*`][ui-redraw]).
  - Só o estado depois do evento `flush` é consistente: "The user should only
    see the final state (when "flush" is sent)" ([doc][ui-redraw];
    [doc: `*ui-global*` `["flush"]`][ui-global]).
- Na grade por linha ([doc: `*ui-linegrid*`][ui-linegrid]):
  - `grid_resize`;
  - `hl_attr_define`, que mapeia id para atributos;
  - `grid_line [grid, row, col_start, cells, wrap]`, onde cada célula é
    `[text, hl_id, repeat]`;
  - a grade 1 é a tela global.
- Com `ext_multigrid` chegam também ([doc: `*ui-multigrid*`][ui-multigrid]):
  - `win_pos` e `win_float_pos`;
  - `win_viewport`, com topline, botline e cursor por janela;
  - `win_viewport_margins`, que conta a winbar.
- Com `ext_messages` ([doc: `*ui-messages*`][ui-messages]):
  - `msg_show [kind, content, replace_last, history, append, id, trigger]`, com
    `kind` como `emsg`, `wmsg`, `echo`, `lua_print`, `confirm`…;
  - `msg_showmode`, `msg_showcmd`, `msg_ruler`, `msg_history_show`;
  - a cmdline por `cmdline_show` e `cmdline_hide` ([doc: `*ui-cmdline*`][ui-cmdline]).
- O modo corrente chega em `mode_change` ([doc: `*ui-global*`][ui-global]).

**Sequência de partida** ([doc: `*ui-startup*`][ui-startup]):

1. `nvim_get_api_info`;
2. configuração pré-init;
3. autocmd `VimEnter` com `rpcrequest` de volta, se precisar;
4. `nvim_ui_attach`. A UI tem que tratar entrada desde já, porque ler a
   configuração pode abrir prompts bloqueantes.

**O que foi verificado aqui.**

- **Por stdio, sem socket, funciona (E4).** Um cliente de 40 linhas em Lua:
  1. `vim.uv.spawn` do `nvim --embed --clean` com pipes;
  2. `vim.mpack.encode` para mandar;
  3. `vim.mpack.Unpacker` para ler;
  4. manteve a grade 1 a partir de `grid_line`;
  5. depois de `nvim_input('ihello from embed<Esc>')`, leu a tela inteira,
     statusline incluída.
- **`vim.mpack.Unpacker` e `vim.mpack.Session` não estão documentados.**
  `lua.txt` só documenta `encode` e `decode` ([doc: `*vim.mpack*`][lua-mpack]).
  Eles são o que o cliente de testes do próprio Neovim usa
  ([código: `test/client/rpc_stream.lua` L6, L38-L60][nv-rpcstream]).
  Tratar como interface interna.
- **Um Neovim pai com `jobstart(…, {rpc=true})` não serve como UI (E3).**
  - Pedidos antes do attach funcionam (E2).
  - Depois de `nvim_ui_attach`, o `rpcrequest` seguinte falhou com erro vazio.
  - No código, o canal descarta eventos `redraw` quando o processo não é um
    cliente de UI ([código: `channel.c` L245-L258][nv-channel]).
  - A causa exata da falha não foi achada. **Não confirmado.**
- **Clientes prontos para o processo filho:**
  - pynvim: `attach('child', argv=[…])`, além de `'socket'`, `'tcp'` e
    `'stdio'` ([código: `pynvim/__init__.py` L84-L147][pynvim]);
  - cliente Node: `attach({ proc })`, que usa o stdin e o stdout do processo,
    ou `attach({ socket })` ([código: `attach.ts` L17-L43][node-attach]). O
    README sobe `nvim --clean --embed` com `child_process.spawn`
    ([README L66-L76][node-readme]).
  - Nenhum dos dois está instalado nesta máquina.

**Como esperar.** O que os screen tests do Neovim fazem: rodar o laço de eventos
recebendo `redraw`, conferir o estado a cada `flush` e parar quando casar ou
quando o tempo estourar ([código: `screen.lua` L776-L870][nv-screen-wait]).

**Limites.**

- É preciso escrever ou instalar um cliente msgpack.
- `--embed` sem `--headless` fica parado até o attach.
- Prompts bloqueantes na partida travam pedidos "deferred" ([doc: `*api-fast*`][api-fast]).
- Presa na sessão de outra pessoa, a UI encolhe a tela dela até o próprio
  tamanho ([doc][api-ui-attach]).

**Exemplo mínimo** (resumo do E4):

```lua
-- nvim --clean -l ui.lua
local uv, mpack = vim.uv, vim.mpack
local W, H, id, buf, flushes = 30, 6, 0, "", 0
local grid = {}
for r = 0, H - 1 do grid[r] = {} for c = 0, W - 1 do grid[r][c] = " " end end
local stdin, stdout = uv.new_pipe(false), uv.new_pipe(false)
local proc = uv.spawn(vim.v.progpath, { args = { "--embed", "--clean" }, stdio = { stdin, stdout, nil } }, function() end)
local function request(m, ...) id = id + 1; stdin:write(mpack.encode({ 0, id, m, { ... } })) end
local unpack = mpack.Unpacker() -- não documentado; usado por test/client/rpc_stream.lua
stdout:read_start(function(_, data)
  if not data then return end
  buf = buf .. data
  local pos = 1
  while pos <= #buf do
    local msg, nextpos = unpack(buf, pos)
    if msg == nil then break end
    pos = nextpos
    if msg[1] == 2 and msg[2] == "redraw" then
      for _, ev in ipairs(msg[3]) do
        for i = 2, #ev do
          local a = ev[i]
          if ev[1] == "grid_line" and a[1] == 1 then
            local row, col = a[2], a[3]
            for _, cell in ipairs(a[4]) do
              for _ = 1, cell[3] or 1 do if col < W then grid[row][col] = cell[1] end col = col + 1 end
            end
          elseif ev[1] == "flush" then flushes = flushes + 1 end
        end
      end
    end
  end
  buf = buf:sub(pos)
end)
request("nvim_ui_attach", W, H, { ext_linegrid = true })
request("nvim_input", "ihello from embed<Esc>")
vim.wait(3000, function() return flushes > 0 and table.concat(grid[0], "", 0, W - 1):find("hello") ~= nil end, 20)
for r = 0, H - 1 do print("|" .. table.concat(grid[r], "", 0, W - 1) .. "|") end
proc:kill("sigterm")
```

### 2.3 `--embed --headless` sem UI: dirigir por `nvim_input`

Não é abordagem separada no `:help`, mas é a combinação mais barata que não usa
socket.

- **Montagem:** `jobstart({nvim, '--embed', '--headless', …}, {rpc = true})`,
  `vim.rpcrequest(ch, 'nvim_input', …)` para as teclas, e
  `vim.rpcrequest(ch, 'nvim_exec_lua', …)` para ler o estado, a tela incluída
  por `screenstring()` (E2).
- **Por que as teclas contam como do usuário:** passam pelo buffer de entrada
  de baixo nível ([doc: `*nvim_input()*`][api-input]), e o filho está no laço
  principal esperando tecla.
- **Os eventos do laço disparam (E9):**
  - `CursorMoved` disparou depois de `nvim_input('j')`;
  - `WinResized` disparou depois de `nvim_input('<C-w>5<LT>')`, com a largura
    indo de 40 para 35.
- **Limite 1: não chame `vim.rpcrequest` dentro do callback de `vim.wait`.** No
  E3 isso deu erro, e numa tentativa do E9 travou o processo. Consulte num laço
  de `vim.wait(20)`. A causa não foi investigada. **Não confirmado.**
- **Limite 2: um `<` solto em `nvim_input` deixa o filho esperando tecla.**
  `nvim_get_mode().blocking = true` (E10); o correto é `<LT>`
  ([doc][api-input]).

### 2.4 RPC por socket (`--listen`, `--server`, `--remote-*`)

**Como funciona.**

- **Endereço:**
  - `--listen {addr}` sobe um servidor RPC num pipe ou endereço TCP e define
    `v:servername` ([doc: `starting.txt` `*--listen*`][st-listen];
    [doc: `vvars.txt` `*v:servername*`][vv-servername]).
  - Sem `--listen`, o Neovim sobe um servidor padrão na partida
    ([doc: `starting.txt` `*initialization*` passo 4][st-init4]); no E5 foi
    `/run/user/1000/nvim.<pid>.0`.
  - `serverstart()` abre mais endereços. Com `:` é TCP (porta `0` aleatória);
    sem barra, o nome vira `stdpath("run").."/{name}.{pid}.{counter}"`
    ([doc: `vimfn.txt` `*serverstart()*`][fn-serverstart]).
  - TCP em localhost é "generally less secure than named pipes"
    ([doc: `api.txt` `*rpc-connecting*`][api-rpc]).
- **Linha de comando** ([doc: `remote.txt`][remote]):
  - `--server {addr}` escolhe a instância;
  - `--remote-send {keys}` manda teclas **sem mapear**;
  - `--remote-expr {expr}` avalia e imprime no stdout;
  - `--remote-ui` mostra a UI do servidor no terminal.
  - As variantes `--remote-wait*` não existem no Neovim ([doc: `*E5600*`][remote]).
- **Dentro do Lua:** `sockconnect('pipe', addr, {rpc = true})`, que é o que o
  mini.test usa ([doc: `*sockconnect()*`][fn-sockconnect]).
- **Desde a 0.11**, o Neovim **falha** se o endereço de `--listen` for inválido,
  "instead of silently skipping" ([doc: `news-0.11.txt` L350-L351][news-011]).

**A observação do sandbox, revista (E5).**

- **O limite de tamanho do caminho:**
  - O caminho de socket Unix cabe em `sun_path[108]`
    ([código: Linux `include/uapi/linux/un.h` L7-L11][linux-un]; `man 7 unix`).
  - O Neovim faz o bind com `UV_PIPE_NO_TRUNCATE`
    ([código: `src/nvim/event/socket.c` L172-L173][nv-socket]).
  - A libuv do 0.12.5 é a v1.52.1 ([código: `cmake.deps/deps.txt` L1][nv-deps]).
    Com essa flag, ela devolve `UV_EINVAL` quando o nome passa do tamanho
    ([código: libuv `src/unix/pipe.c` L92-L94][libuv-pipe]).
- **O que o E5 mostrou:**
  - Com o caminho do scratchpad (110 bytes), `nvim --listen` saiu com
    `Failed to --listen: invalid argument`, e o `--server … --remote-expr` deu
    `E247: … connection refused`. É o mesmo par de sintomas da observação da
    sessão.
  - Com `/tmp/claude-listen-test.sock` (28 bytes), o socket subiu e
    `--remote-expr '1+1'` devolveu `2`.
  - `sockconnect` num `tempname()` e `serverstart('127.0.0.1:0')` também
    funcionaram.
- **Conclusão:** o sandbox desta sessão **não bloqueia socket Unix em geral**.
  - O caminho da sessão anterior era
    `<scratchpad>/probe.sock`, com **114 bytes**, acima dos 108 de `sun_path`:
    a causa da observação 2 é esse limite.

**O que se observa.** Tudo o que a API dá. Para a tela da sessão viva:

- `--remote-expr` com `screenstring()`;
- ou uma UI presa no mesmo socket, já que UIs "can also connect to a running
  Nvim instance and invoke nvim_ui_attach()" ([doc: `*ui-option*`][ui-option]).
  Com o aviso de que ela encolhe a tela ([doc][api-ui-attach]).

**Como esperar e o risco de travar.**

- **Pedido "deferred" trava:** a maioria das funções da API é deferred e "If
  the editor is waiting for user input in a "modal" fashion (e.g. an input()
  prompt), a deferred request will block" ([doc: `*api-fast*`][api-fast]).
  Antes de um `--remote-expr`, consulte `nvim_get_mode()`, que é fast e diz
  `blocking` ([doc: `*nvim_get_mode()*`][api-get-mode]).
- **Na 0.12,** `nvim__exec_lua_fast()` (experimental) executa Lua mesmo com o
  editor bloqueado ([doc: `api.txt` `*nvim__exec_lua_fast()*`][api-exec-lua-fast];
  [doc: `news.txt` L120-L121][news-012]).

**Novidades de sessão.**

- 0.11: `:detach` solta a UI e deixa o servidor rodando
  ([doc: `news-0.11.txt` L421-L422][news-011]).
- 0.12:
  - `:restart` reinicia e reata as UIs;
  - `:connect` liga a UI atual a outro servidor ([doc: `news.txt` L433-L435][news-012]);
  - ambos têm eventos de UI `restart` e `connect` ([doc: `*ui-global*`][ui-global]).

**Exemplo mínimo** (E5):

```sh
sock=/tmp/nvim-agente-$$.sock          # curto: < 108 bytes
nvim --headless --clean --listen "$sock" &
timeout 3 bash -c "until [ -S $sock ]; do sleep 0.1; done"
nvim --server "$sock" --remote-expr 'nvim_get_mode().blocking'
nvim --server "$sock" --remote-send 'ihello<Esc>'
nvim --server "$sock" --remote-expr 'getline(1)'
nvim --server "$sock" --remote-send ':qa!<CR>'
```

### 2.5 tmux (`send-keys`, `capture-pane`)

**Como funciona.**

- **`send-keys`** ([doc: `tmux.1` L4019-L4069][tmux-man-sendkeys]):
  - "Send a key or keys to a window or client"; cada argumento é um nome de
    tecla (`C-a`, `NPage`, `Escape`) ou, se não for reconhecido, uma sequência
    de caracteres;
  - "All arguments are sent sequentially";
  - `-l` desliga a busca pelo nome e manda UTF-8 literal;
  - `-H` manda bytes em hexadecimal;
  - `-N` repete; `-R` reinicia o estado do terminal.
- **No código** ([código: `cmd-send-keys.c` L119-L133][tmux-sendkeys-c]):
  1. procura o nome com `key_string_lookup_string`;
  2. sem nome, cai para literal;
  3. entrega ao painel com `window_pane_key` ([código: L89][tmux-sendkeys-c]).
- **`capture-pane`** ([doc: `tmux.1` L2670-L2729][tmux-man-capture]):
  - `-p` joga na saída padrão;
  - `-e` inclui sequências de escape de atributos de texto e fundo;
  - `-C` escapa não imprimíveis;
  - `-J` junta linhas quebradas e preserva espaços finais; `-N` preserva
    espaços finais;
  - `-a` usa a tela alternativa;
  - `-S` e `-E` escolhem as linhas.
- **`escape-time`:** "the time in milliseconds for which tmux waits after an
  escape is input to determine if it is part of a function or meta key
  sequences" ([doc: `tmux.1` L4388-L4392][tmux-man-escape]).
  - No código, o valor é lido no parser de teclas **do terminal cliente**
    ([código: `tty-keys.c` L970][tmux-ttykeys]).
  - `send-keys` entra por outro caminho, `window_pane_key`.
  - Que o `escape-time` não afeta `send-keys` é inferência a partir desses dois
    trechos, sem traçar o caminho inteiro. **Não confirmado** na fonte; os
    experimentos E6 e E7 são compatíveis com isso.
- **Do lado do Neovim:** o que chega ao painel é lido pela TUI, que converte
  sequências com libtermkey ([doc: `tui.txt` `*tui-input*`][tui-input]).
  - O `:help` dá o exemplo `tmux send-keys 'Escape' [ 2 7 u 'C-W' j`, em que
    `Escape [ 2 7 u` é o `<Esc>` sem ambiguidade em CSI u.
  - Numa sequência de tecla incompleta, a TUI espera `'ttimeoutlen'` se
    `'ttimeout'` estiver ligado ([código: `tui/input.c` L476-L499][nv-tuiinput];
    [doc: `options.txt` `*'ttimeout'*`][opt-ttimeout]).

**O que se observa.**

- A tela real que o terminal mostraria, com a configuração real: seletor do
  snacks, winbar, notificações. Foi a observação 1 da sessão.
- Os atributos só com `-e`, como sequências SGR.
- Nada estruturado: para buffers, mapas e estado do plugin, mande
  `:luafile probe.lua` pelo próprio `send-keys` e leia o arquivo que o probe
  grava, como em `docs/agents/debugging.md` (E8 usa isso).

**Como esperar.**

- Um laço que consulta a tela:
  `timeout 5 bash -c 'until tmux capture-pane -p | grep -q X; do sleep 0.2; done'`.
- Ou um arquivo gravado pelo probe.
- Nos experimentos, isso bastou e deu diagnóstico preciso (E6–E8).

**Limites.**

- Leitura de tela por texto.
- Tempo de partida da configuração real (o E8 usou 12 s de folga).
- Nenhum sinal de "terminou de desenhar": não há `flush`.
- A interação do `<Esc>` com plugins ([§3.2](#32-o-esc-e-os-timeouts)).

**Exemplo mínimo:**

```sh
tmux -L agente new-session -d -x 120 -y 30 -c "$repo" nvim
timeout 40 bash -c 'until tmux -L agente capture-pane -p | grep -q "New File"; do sleep 0.3; done'
tmux -L agente send-keys ':luafile /tmp/probe.lua' Enter      # probe grava o estado num arquivo
tmux -L agente send-keys i 'abc'
tmux -L agente send-keys Escape                               # um Esc por chamada (§3.2)
timeout 3 bash -c 'until tmux -L agente capture-pane -p | grep -q -v "INSERT"; do sleep 0.1; done'
tmux -L agente capture-pane -p -J > /tmp/tela.txt
tmux -L agente kill-server
```

### 2.6 mini.test: `MiniTest.new_child_neovim()`

Código lido no commit `6664ea9` de `echasnovski/mini.nvim`.

**Como funciona.**

- **Partida** ([código: `lua/mini/test.lua` L1149-L1200][mini-start]):
  - `child.start(args, opts)` monta `{ nvim, '--clean', '-n', '--listen',
    <tempname()>, '--headless', '--cmd', 'set lines=24 columns=80' }` mais os
    `args`;
  - sobe com `vim.fn.jobstart`;
  - conecta com `sockconnect('pipe', addr, {rpc = true})`, tentando a cada
    10 ms até `connection_timeout` (5000 ms).
  - O comentário diz que definir `'lines'` e `'columns'` "makes headless
    process more like interactive" ([código: L1168-L1172][mini-start]).
- **Wrappers:** `child.api`, `child.lua`, `child.lua_get` e `child.cmd` usam
  `vim.rpcrequest`; as variantes `*_notify` usam `vim.rpcnotify`, "Useful for
  making blocking requests (like `getcharstr()`)"
  ([código: L1231-L1245, L1355-L1386][mini-start]).
- **`child.type_keys(wait, ...)`** ([código: L1309-L1349][mini-typekeys];
  [doc: anotação L1557-L1583][mini-doc-typekeys]):
  - chama `nvim_input` por entrada, trocando `<` solto por `<LT>`;
  - zera e confere `v:errmsg` para transformar erro do filho em erro do teste,
    só quando o filho não está bloqueado;
  - dorme `wait` ms entre entradas com `vim.loop.sleep`.
- **Bloqueio:** `child.is_blocked()` é `nvim_get_mode().blocking`, e a maioria
  dos métodos recusa rodar com o filho bloqueado (`prevent_hanging`)
  ([código: L1136-L1146, L1388-L1391][mini-typekeys]).
  `child.ensure_normal_mode()` manda `<C-\>` e `<C-n>` ([código: L1396-L1399][mini-typekeys]).
- **`child.get_screenshot()`** ([código: L1401-L1425][mini-screenshot];
  [doc: anotação L1585-L1610][mini-doc-screenshot]):
  - faz `:redraw`;
  - chama `screenstring(i, j)` e `screenattr(i, j)` para toda célula de
    `'lines'` × `'columns'`, **dentro do filho headless, sem UI presa**.
  - Os atributos viram símbolos que "can't tell how exactly cell is
    highlighted, only if two cells are highlighted the same"
    ([doc: `TESTING.md` L901][mini-testing]).
- **Referência:** `MiniTest.expect.reference_screenshot(screenshot, path, opts)`
  cria a referência na primeira execução, em `tests/screenshots`, e compara
  nas seguintes ([código: L811][mini-refshot]; [doc: `TESTING.md` L892-L903][mini-testing]).
- **Travamentos:** o `TESTING.md` diz que o filho que "stops executing without
  any output" costuma estar bloqueado por um hit-enter prompt ou por
  Operator-pending ([doc: L711][mini-testing]).

**Neste sandbox:** o par `--listen tempname()` + `sockconnect` funcionou,
porque o caminho é curto (E5).

**Limites.**

- Pede o mini.nvim (ou o `mini.test` avulso) como dependência nova. Aqui só o
  `mini.icons` está instalado.
- A captura não diz a cor, só igualdade de atributo.
- As esperas são `sleep` fixos, a menos que se escreva a condição.

**Exemplo mínimo** (do `TESTING.md` L844-L903):

```lua
local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set({ hooks = {
  pre_case = function() child.restart({ "-u", "scripts/minimal_init.lua" }) end,
  post_once = child.stop,
} })
T["mostra"] = function()
  child.type_keys("i", "Hello", "<Esc>")
  MiniTest.expect.reference_screenshot(child.get_screenshot())
end
return T
```

### 2.7 Os screen tests do próprio Neovim

**Como funciona.**

- **Cada teste é um processo novo:** "Each test starts a new Nvim process
  (10-30ms)"; afirma-se com `t.eq()` e `screen:expect()`, "which automatically
  waits as needed" ([doc: `dev_test.txt` L14-L19][dev-test]).
- **O processo filho:**
  - `nvim_argv` traz `-u NONE -i NONE`, várias `--cmd` e `--embed`
    ([código: `test/functional/testnvim.lua` L34-L56][nv-testnvim-argv]);
  - `_new_argv` acrescenta `--headless` e um `--listen` com o id do teste,
    "for logging" ([código: L589-L600][nv-testnvim-newargv]);
  - `new_session` sobe o processo com `ProcStream.spawn`, que é `uv.spawn` com
    pipes em stdin, stdout e stderr ([código: `testnvim.lua` L500-L527][nv-testnvim-session];
    [código: `test/client/uv_stream.lua` L167-L197][nv-uvstream]);
  - fala msgpack por `vim.mpack.Session` ([código: `rpc_stream.lua` L38-L60][nv-rpcstream]);
  - ou seja, o RPC do teste é **por stdio**.
- **Teclas e laço:**
  - `feed(...)` chama `nvim_input` em laço até todos os bytes entrarem
    ([código: L361-L381][nv-testnvim-feed]);
  - `poke_eventloop()` força um giro do laço com `nvim_eval('1')`, "a deferred
    function" ([código: L795-L799][nv-testnvim-poke]).
- **A tela:**
  - `Screen.new(width, height, options)` liga `ext_linegrid` por padrão e se
    prende com `nvim_ui_attach` ([código: `test/functional/ui/screen.lua` L180-L260, L290-L316][nv-screen-new]);
  - `_handle_grid_line` preenche a grade ([código: L1298][nv-screen-grid]).
- **`screen:expect`** ([código: cabeçalho L1-L46][nv-screen-head]):
  - `expect()` especifica o estado **eventual**: roda o laço com um timeout,
    confere a cada atualização e para quando casa;
  - `_wait` roda `run_session` com um `notification_cb` que só aceita `redraw`
    e confere depois de cada `flush` ([código: L776-L870][nv-screen-wait]);
  - o timeout padrão é 3500 ms, ×3 com `CI` e ×3 com `VALGRIND`
    ([código: L96-L105][nv-screen-head]);
  - as chaves incluem `grid`, `attr_ids`, `condition`, `any`, `none`, `mode`,
    `unchanged`, `intermediate`, `reset`, `timeout`, `cmdline`, `popupmenu` e
    `messages` ([código: L400-L495][nv-screen-expect]);
  - `screen:snapshot_util()` imprime o estado atual já no formato de `expect`
    ([código: L1663][nv-screen-snap]; [doc: `dev_test.txt` L145-L151][dev-test]).
- **O aviso de prompt:** "Hanging tests can happen due to unexpected modal
  prompts … The default screen width is 50 columns", e um caminho longo no
  cmdline dispara o hit-enter prompt ([doc: `dev_test.txt` L140-L144][dev-test]).

**Limites.**

- Não é interface pública: "TODO: Expose the test framework as a public
  interface, for use in 3P plugins", com link para a issue #34592
  ([doc: `dev_test.txt` L21-L22][dev-test]). A issue não foi lida.
- Depende da árvore do Neovim e do harness próprio (`nvim -ll`).
- Serve como **referência de desenho**: stdio, UI de linegrid e espera por
  `flush`.

### 2.8 MCP

Achados por busca na web e lidos no repositório, cada um num commit. Nenhum é
do projeto Neovim. Os três exigem **socket** para uma instância já rodando, ou
seja, estão na mesma categoria da §2.4.

- **`bigcodegen/mcp-neovim-server`** (TypeScript):
  - usa "the official neovim/node-client JavaScript library" ([README L3][mcp1-readme]);
  - conecta "if you expose a socket file, for example `--listen /tmp/nvim`"
    ([README L9][mcp1-readme]), por `NVIM_SOCKET_PATH`, com padrão `/tmp/nvim`
    ([README L129][mcp1-readme]);
  - no código: `attach({ socket })` ([código: `src/neovim.ts` L95-L104][mcp1-src]),
    e as ferramentas usam `nvim.command` e `nvim.input`
    ([código: L795-L807][mcp1-src]).
- **`linw1995/nvim-mcp`** (Rust):
  - cliente Neovim é `nvim-rs` 0.9.2 ([código: `Cargo.toml` L62][mcp2-cargo]);
  - fala MCP por stdio ou HTTP ([README L9][mcp2-readme]);
  - acha as instâncias com `--connect auto` ([README L153-L155][mcp2-readme]);
  - um plugin Neovim registra um socket por repositório ([README L95-L96][mcp2-readme]).
- **`paulburgess1357/nvim-mcp`** (Python):
  - "connects through Neovim's native msgpack-RPC socket — no plugins
    required" ([README L7][mcp3-readme]);
  - dependências `mcp[cli]` e `msgpack` ([código: `pyproject.toml` L28-L30][mcp3-py]).

Se algum deles expõe a tela renderizada (grade ou `screenstring`) não foi
verificado. **Não confirmado.**

### 2.9 Outras: `vusted`, `busted` com `nlua`

- **`vusted`:** "busted wrapper for testing neovim plugin". Roda o Neovim com
  `VUSTED_ARGS`, padrão `--headless --clean` ([README L12, L41-L46][vusted]).
  O README abre com "**This project is no longer maintained.**" e indica
  mini.test, `notomo/ntf` e `lewis6991/nvim-test` ([README L3-L10][vusted]).
- **`nlua`:** emula a linha de comando do `lua` "Using Neovim's `-l` option
  under the hood". Com isso, `busted --lua nlua spec/…` roda o busted de
  verdade dentro do Neovim ([README L24, L37, L83-L88][nlua]).
  - Como `-l` é "non-interactively (no UI)" ([doc][st-l]), tem os mesmos
    limites da §2.1.
  - `dev_test.txt` usa o `nlua` para depurar os testes do próprio Neovim
    ([doc: L153-L162][dev-test]).

---

## 3. Teclas

### 3.1 `nvim_input` × `nvim_feedkeys` × `send-keys` × `--remote-send`

| | `nvim_input(keys)` | `nvim_feedkeys(keys, mode, escape_ks)` | `tmux send-keys` | `--remote-send` |
| --- | --- | --- | --- | --- |
| Onde entra | "a low-level input buffer", como tecla digitada ([doc][api-input]); no código, `input_enqueue` ([código: `api/vim.c` L369-L374][nv-apivim]) | o **typeahead**, por `ins_typebuf`; com `L`, a entrada de baixo nível ([código: L282-L351][nv-apivim]) | bytes no pty do painel, lidos pela TUI ([doc][tui-input]) | teclas mandadas ao servidor ([doc][remote]) |
| Bloqueia? | não: "non-blocking (input is processed asynchronously by the eventloop)"; é `api-fast` ([doc][api-input]) | sim: "This is a blocking call" ([doc][api-feedkeys]); só executa na hora com `x` ([doc: `*feedkeys()*`][fn-feedkeys]) | não; volta depois de escrever | não |
| Mapeamentos | aplicados, como do usuário | `m` remapeia (padrão); `n` não remapeia ([doc][fn-feedkeys]) | aplicados | "The {keys} are not mapped" ([doc][remote]) |
| "Digitado"? | sim | só com `t`; sem `t` é "as if coming from a mapping", o que muda undo, dobras etc. ([doc][fn-feedkeys]) | sim | **Não confirmado** |
| Códigos de tecla | `<CR>` traduzido; `<` literal é `<LT>`; devolve os bytes escritos, que podem ser menos ([doc][api-input]) | use `nvim_replace_termcodes()` ou `vim.keycode()`; `escape_ks` escapa `K_SPECIAL` ([doc][api-feedkeys]) | nomes do tmux (`Escape`, `C-w`); `-l` literal ([doc][tmux-man-sendkeys]) | `<CR>` reconhecido ([doc][remote]) |
| Timeouts de terminal | não se aplicam | não se aplicam | aplicam-se: `'ttimeout'`/`'ttimeoutlen'` na TUI ([doc][opt-ttimeout]) | não se aplicam |

As flags de `feedkeys()` que importam para teste ([doc: `vimfn.txt` `*feedkeys()*`][fn-feedkeys]):

- **`x`:** "Execute commands until typeahead is empty", como `:normal!`. Se a
  sequência terminar em Insert, age como se `<Esc>` fosse digitado, "to avoid
  getting stuck".
- **`!`:** com `x`, não sai do Insert ("Useful for testing CursorHoldI").
- **`i`:** insere no começo do typeahead em vez de acrescentar.
- **Chamada recursiva:** se `feedkeys()` for chamado enquanto comandos
  executam, "all typeahead will be consumed by the last call".

**Mouse.** `nvim_input_mouse(button, action, modifier, grid, row, col)` é
não-bloqueante e "doesn't support "scripting" multiple mouse events by calling
it multiple times in a loop: the intermediate mouse positions will be ignored"
([doc][api-input-mouse]). A forma `<LeftMouse><col,row>` por `nvim_input` está
deprecada desde o api-level 6 ([doc][api-input]).

- 0.10: os botões `x1` e `x2` ([doc: `news-0.10.txt` L155][news-010]).
- 0.12: UIs multigrid podem passar `grid` 0 ([doc: `news.txt` L444][news-012]).

**Diferença prática observada (E9).** No mesmo filho, a mesma redução de
largura:

- por `nvim_input`: disparou `WinResized`;
- por `nvim_feedkeys(…, 'x')` dentro de `nvim_exec_lua`: não disparou.

Quem precisa dos eventos do laço principal manda teclas por `nvim_input` a um
processo que está esperando tecla.

### 3.2 O `<Esc>` e os timeouts

**As quatro regras.**

- **`'ttimeout'` e `'ttimeoutlen'` (padrão 50):** valem quando parte de um
  código de tecla chegou **pela TUI**: "if <Esc> (the \x1b byte) is received
  and 'ttimeout' is set, Nvim waits 'ttimeoutlen' milliseconds for the terminal
  to complete a key code sequence" ([doc: `options.txt` `*'ttimeout'*`, `*'ttimeoutlen'*`][opt-ttimeout]).
  O código liga um timer com esse valor quando o libtermkey devolve tecla
  parcial ([código: `tui/input.c` L476-L499][nv-tuiinput]).
- **`'timeout'` e `'timeoutlen'` (padrão 1000; a configuração real usa 500,
  E8):** valem para sequências **mapeadas** ([doc: `*'timeout'*`, `*'timeoutlen'*`][opt-timeout]).
- **ESC seguido de tecla vira ALT:** no terminal, "If ESC is followed by a {key}
  within 'ttimeoutlen' milliseconds, the ESC is interpreted as: <ALT-{key}>"
  ([doc: `map.txt` `*:map-alt-keys*`][map-alt]).
- **`escape-time` do tmux:** vale para a entrada que o tmux lê do terminal
  cliente ([doc][tmux-man-escape]; [código: `tty-keys.c` L970][tmux-ttykeys]).
  No servidor do experimento, o valor era 10.

**A hipótese da sessão.** Dois `Escape` do `send-keys` teriam sido juntados
pelo `escape-time` ou pelo `ttimeoutlen`. Os logs de `vim.on_key` a refutam:

- **E6 (`nvim --clean` no tmux):**
  - `send-keys Escape Escape` numa chamada chegou como **dois** `<Esc>`
    (modo `i` e depois `n`);
  - `send-keys Escape j` chegou como `<Esc>` e `j`, não `<M-j>`;
  - a sequência CSI u do `:help` também funcionou.
- **E7 (configuração real, buffer comum):** `Escape Escape` numa chamada chegou
  como dois `<Esc>`, e o modo foi de `i` para `n`.
- **E8 (configuração real, `snacks.input` aberto):**
  - **Um `Escape` por chamada, com 1 s entre eles:** o primeiro levou a `n` e
    o segundo cancelou (callback com `nil`).
  - **`Escape Escape` numa chamada:** nada mudou por 4 s. O modo ficou `i`, a
    caixa na tela, e `nvim_get_mode().blocking` ficou `false`.
  - **Uma tecla `y` depois disso:** `on_key` registrou `key=y typed=<Esc><Esc>y`.
    Os dois Esc tinham chegado, e o modo só então foi para `n`, com a caixa
    ainda aberta.
  - **Não havia mapa `<M-Esc>` nem `<Esc><Esc>`** em `i` ou `n`; só o `<Esc>`
    local do buffer, com `expr`.

**O que a fonte explica, e onde para.**

- **O `<Esc>` do snacks não sai do Insert na hora.**
  - Em Insert, é um mapa `expr` que roda as ações `cmp_close` e `stopinsert`
    ([código: snacks.nvim `lua/snacks/input.lua` L64-L73][snacks-input]).
  - A ação `stopinsert` **agenda** o comando: `vim.schedule(function()
    vim.cmd("stopinsert") end)` ([código: L184-L188][snacks-input]).
  - `:stopinsert` sai do Insert "as soon as possible"
    ([doc: `insert.txt` `*:stopinsert*`][ins-stopinsert]): liga a flag
    `stop_insert_mode` ([código: `ex_docmd.c` L7470-L7475][nv-exdocmd]), e o
    modo Insert a confere ao processar a tecla ou o evento seguinte
    ([código: `edit.c` L552-L559][nv-edit]).
- **O que falta:** por que dois Esc seguidos deixaram o Insert pendente até a
  próxima tecla, e um só não. **Não confirmado.**

**Regra prática para um agente no tmux.** Mande **um `Escape` por
`send-keys`** e espere a mudança observável antes do próximo: o `-- INSERT --`
sumir, a caixa fechar, ou um probe gravar o modo. Quando o efeito não vier,
confirme com `vim.on_key` gravando `typed` num arquivo. Foi o que separou
"tecla não chegou" de "chegou e ficou pendente".

### 3.3 O modo pendente

- **`nvim_get_mode()`:**
  - devolve `{ mode, blocking }`, em que "blocking is true if Nvim is waiting
    for input"; é `api-fast` ([doc: `api.txt` `*nvim_get_mode()*`][api-get-mode]);
  - os códigos de `mode()` incluem `no` (Operator-pending), `r` (hit-enter),
    `rm` (`-- more --`), `r?` (`:confirm`) e `!` (comando externo)
    ([doc: `vimfn.txt` `*mode()*`][fn-mode]).
- **O risco:** com o editor esperando entrada "modal", pedidos deferred
  **travam** ([doc: `*api-fast*`][api-fast]). Consulte `blocking` antes de
  `nvim_exec_lua`, ou use `nvim__exec_lua_fast` na 0.12 ([doc][api-exec-lua-fast]).
- **O que o mini.test faz:** `is_blocked` e `prevent_hanging`
  ([código][mini-typekeys]). O Neovim avisa sobre hit-enter prompt em tela
  estreita ([doc: `dev_test.txt` L140-L144][dev-test]).
- **Duas observações:**
  - `blocking` ficou `true` depois de `nvim_input('<C-w>5<')`, com o `<` solto
    esperando o resto (E10);
  - ficou `false` enquanto os dois Esc esperavam no snacks.input (E8). Ou seja,
    `blocking=false` **não** garante que a última tecla já fez efeito.

---

## 4. O que mudou na 0.10, na 0.11 e na 0.12

| Versão | Mudança relevante | Fonte |
| --- | --- | --- |
| 0.10 | `nvim_input_mouse()` aceita `x1` e `x2` | [doc: `news-0.10.txt` L155][news-010] |
| 0.10 | `vim.wait()` não pode ser chamado em `api-fast` | [doc: `news-0.10.txt` L418][news-010] |
| 0.10 | `nvim__redraw()` (experimental) força redesenho, com `flush` | [doc: `api.txt` `*nvim__redraw()*`, "Since: 0.10.0"][api-redraw] |
| 0.11 | callbacks de `vim.ui_attach()` para `msg_show` rodam em `api-fast`; `cmdline_show` passa a receber prompts; `msg_show` ganha `history` e novos `kind` | [doc: `news-0.11.txt` L65-L76][news-011] |
| 0.11 | o Neovim falha se o endereço de `--listen` for inválido | [doc: `news-0.11.txt` L350-L351][news-011] |
| 0.11 | `:detach` solta a UI e deixa o servidor rodando | [doc: `news-0.11.txt` L421-L422][news-011] |
| 0.11 | o conteúdo de `ui-messages` traz o id do grupo de destaque | [doc: `news-0.11.txt` L437][news-011] |
| 0.12 | `msg_show.bufwrite` e `completion` viram `progress`; somem `return_prompt` e `msg_history_clear`; `msg_clear` muda de sentido | [doc: `news.txt` L22-L23, L49-L54][news-012] |
| 0.12 | `nvim__exec_lua_fast()` executa Lua com o editor bloqueado; `nvim_ui_send()` | [doc: `news.txt` L110-L121][news-012] |
| 0.12 | `msg_show` ganha `append`, `id` e `trigger`; kind `empty` | [doc: `news.txt` L199-L204][news-012] |
| 0.12 | `vim.wait()` devolve os resultados do callback | [doc: `news.txt` L299][news-012] |
| 0.12 | `ui2` experimental substitui a grade de mensagens; `:restart` e `:connect`; multigrid com posições absolutas; `nvim_input_mouse` com grid 0 | [doc: `news.txt` L426-L446][news-012] |

A tag `nvim__screenshot()` não existe no `doc/tags` do 0.12.5.

---

## 5. Recomendações para este repositório

### 5.1 O que acrescentar à suíte plenary

A costura continua a mesma: Neovim headless, fixture de repositório e API
pública. Três acréscimos cabem nela sem dependência nova.

1. **Afirmar sobre a tela quando o que se afirma é composição.**
   - Um helper `tests/helpers/screen.lua` que:
     1. faz um giro do laço (`vim.wait`);
     2. roda `vim.cmd.redraw()`;
     3. devolve as linhas por `screenstring()`;
     4. compara células por `screenattr()`.
   - É o que o `child.get_screenshot` do mini.test faz ([código][mini-screenshot]).
   - Serve para o que nenhuma leitura de buffer mostra: a janela de ajuda
     flutuante por cima do painel, a borda e o título da entrada longa, a
     winbar truncada, o `+N −M` alinhado à direita como ele cai na célula.
   - Três cuidados:
     - fixe `'lines'` e `'columns'` no `minimal_init`, como o mini.test fixa
       24×80, para a tela não depender da máquina;
     - os specs rodam de dentro de `-c`, antes do `VimEnter`, e lá o primeiro
       `:redraw` saiu errado. Faça sempre giro e redraw (E1);
     - `screenattr()` só diz igualdade ([doc][fn-screenattr]). Para o grupo de
       destaque, continue com as leituras de extmark que a suíte já tem.
2. **Cobrir os eventos do laço principal com um filho por stdio.**
   - Hoje `WinResized` e `CursorMoved` são disparados à mão
     (`docs/agents/testing.md`).
   - Um helper sobe `jobstart({nvim, '--embed', '--headless', '--noplugin',
     '-u', 'tests/minimal_init.lua'}, {rpc = true})`, manda o gesto por
     `nvim_input` e lê o resultado por `nvim_exec_lua`.
   - No E9, `CursorMoved` e `WinResized` dispararam assim.
   - Três cuidados:
     - `<` vira `<LT>` (E10);
     - consulte `blocking` antes de pedidos deferred;
     - não chame `rpcrequest` dentro do callback de `vim.wait` (§2.3).
   - `VimResized` pede um tamanho de UI mudando (`nvim_ui_try_resize`), ou
     seja, um cliente de UI (§2.2). Não testado. **Não confirmado.**
3. **Não trocar o runner.** O mini.test resolve a captura de tela com a mesma
   técnica do item 1 e exigiria dependência e reescrita. O `vusted` está sem
   manutenção ([README][vusted]).

### 5.2 Validar com a configuração real sem mexer em socket

Em ordem de custo:

1. **tmux**, para "o que o revisor vê". Já funcionou nesta sessão e nos
   experimentos (E6–E8).
   - Um `send-keys` por gesto; um `Escape` por chamada.
   - Espera por `until capture-pane | grep`.
   - Estado por um probe mandado com `:luafile`, gravando num arquivo, que é o
     molde de `docs/agents/debugging.md`.
   - É o único caminho em que os timeouts de terminal e a TUI de verdade estão
     no meio. Os mapas `<Space>`/`nowait` que `testing.md` manda verificar à mão
     se verificam assim.
2. **Headless com a configuração real**, que é a reprodução de
   `docs/agents/debugging.md` (`nvim --headless -c "lua vim.defer_fn(…)"`),
   agora com a tela: depois do `VimEnter`, `screenstring()` lê a UI desenhada,
   janelas flutuantes incluídas (E1).
3. **`--embed` por stdio com a configuração real**: sem `--clean` e sem `-u`,
   dirigido por `nvim_input` (§2.3). Com um cliente de UI (§2.2) quando for
   preciso a grade estruturada ou as mensagens por `ext_messages`.
4. **Socket, se precisar da sessão viva.** O socket funciona com caminho curto
   (E5): use `/tmp/nvim-<curto>.sock`, e não um caminho sob o scratchpad
   (110 bytes > 108).

### 5.3 `--embed` por stdio é saída para o sandbox?

**Sim, para o que depende de socket.**

- **A fonte:** `--embed` usa "stdin/stdout as a msgpack-RPC channel"
  ([doc: `*--embed*`][st-embed]); com `--headless`, stdin e stdout "can be used
  as a channel" ([doc: `*channel-stdio*`][ch-stdio]); e `jobstart` com `rpc`
  fala "over stdio" ([doc: `*jobstart()*`][fn-jobstart]). Nada disso abre
  socket.
- **Os experimentos:** neste sandbox funcionaram o controle por stdio (E2), o
  cliente de UI por stdio (E4) e os eventos do laço (E9).
- **Os screen tests do Neovim** fazem o mesmo: `--embed` por pipes de
  `uv.spawn` ([código][nv-uvstream]).

Ressalvas:

- Com `--headless`, o Neovim sobe o servidor padrão mesmo assim
  ([doc: passo 4][st-init4]). Nos experimentos isso não atrapalhou.
- Ser UI exige um cliente msgpack que trate `redraw`. Um Neovim pai com
  `jobstart` não serviu (E3).
- `--embed` sem `--headless` espera o attach ([doc][st-embed]).
- A premissa da pergunta muda: o socket também funciona com caminho curto (E5).

---

## Experimentos locais

Rodados em 2026-09-11 com Neovim 0.12.5 e tmux 3.7c, no sandbox de shell. Os
scripts ficaram no scratchpad da sessão, que é temporário.

- **E1: headless sem UI lê a tela.**
  - `nvim --headless --clean`: `nvim_list_uis()` = 0, `'lines'` = 24,
    `'columns'` = 80, `screenstring(1,1..2)` = `he` depois de `setline` e
    `:redraw`.
  - **Depois do `VimEnter`** (`--cmd` com autocmd + `defer_fn`): uma flutuante
    com `border='single'` saiu inteira em `screenstring()` (`┌────────┐`,
    `│FLOAT   │`).
  - **Dentro de `-c`** (`v:vim_did_enter=0`): o primeiro `:redraw` desenhou a
    flutuante no canto, sem a linha `texto`. Depois de `vim.wait(100)` com
    `:redraw`, `:redraw!` ou `nvim__redraw({flush=true, valid=false})`, a tela
    ficou certa (`texto`, `~ ┌────────┐`).
- **E2: filho `--embed --headless --clean` por `jobstart(…, {rpc=true})`.**
  `nvim_input('ihello<Esc>')`, `nvim_get_mode()` → `{mode="n", blocking=false}`,
  e `nvim_exec_lua` leu o buffer `{"hello"}` e a tela `he`.
- **E3: filho `--embed --clean` com `nvim_ui_attach` feito pelo pai Neovim.**
  - O attach respondeu `vim.NIL`; o `rpcrequest('nvim_get_mode')` seguinte
    falhou com erro vazio.
  - Com attach por `rpcnotify`, o filho não chegou a gravar o arquivo de prova
    em 3 s.
- **E4: cliente de UI por stdio** (`vim.uv.spawn` + `vim.mpack`).
  - Grade 30×6 depois de `nvim_input('ihello from embed<Esc>')`:
    `|hello from embed              |`, três `~`, statusline
    `|< Name] [+] 1,16           All|`, 1 `flush`.
- **E5: sockets.**
  - `--listen` num caminho de 110 bytes sob o scratchpad:
    `nvim: Failed to --listen: invalid argument`, exit 1; o `--server …
    --remote-expr '1+1'` deu `E247 … connection refused`, exit 2.
  - `--listen /tmp/claude-listen-test.sock`: o socket existiu e o
    `--remote-expr '1+1'` devolveu `2`.
  - `jobstart` com `--listen tempname()` (`/tmp/nvim.grisotto/…/0`) e
    `sockconnect('pipe', …, {rpc=true})`: `nvim_eval('1+1')` = 2.
  - `serverstart('127.0.0.1:0')` → `127.0.0.1:36445`; `v:servername` padrão
    `/run/user/1000/nvim.<pid>.0`.
- **E6: tmux + `nvim --clean`, `vim.on_key` gravando num arquivo.**
  - `escape-time` = 10.
  - Em Insert, `send-keys Escape Escape` → `<Esc>` (modo i) e `<Esc>` (modo n).
  - O mesmo com dois `send-keys` seguidos e com 1 s entre eles.
  - `send-keys Escape j` → `<Esc>`, `j`.
  - `send-keys Escape '[' 2 7 u j` → `<Esc>`, `j`.
- **E7: tmux + configuração real, buffer vazio (`:enew`).** Em Insert,
  `send-keys Escape Escape` → dois `<Esc>`, e o modo foi de `i` para `n`.
- **E8: tmux + configuração real + `Snacks.input`** (snacks.nvim `e6fd58c`).
  - Opções: `ttimeout=true`, `ttimeoutlen=50`, `timeoutlen=500`.
  - **Esc espaçados:** o modo foi a `n` depois do primeiro; o segundo chamou o
    callback com `nil`, e a caixa sumiu.
  - **`Escape Escape` numa chamada:** 4 s sem mudança (`mode=i`,
    `blocking=false`, caixa na tela). Depois de `y`: `on_key key=y
    typed=<Esc><Esc>y mode=i`, em seguida `mode=n`, e a caixa continuou.
  - **Mapas:** `maparg('<Esc>','i')` = local, `expr=1`, "cmp close, stopinsert";
    nenhum `<M-Esc>` nem `<Esc><Esc>`.
- **E9: eventos do laço num filho `--embed --headless --clean`.**
  - `nvim_input('j')` → `CursorMoved` disparou (contador 2, cursor `{2,0}`).
  - `nvim_input('<C-w>v')` → `WinResized` 1; `nvim_input('<C-w>5<LT>')` →
    `WinResized` 2, largura 40 → 35.
  - No mesmo filho, `nvim_feedkeys(vim.keycode('<C-w>5<'), 'x', false)` dentro
    de `nvim_exec_lua` → largura 35 → 30, `WinResized` 0.
- **E10: `nvim_input('<C-w>5<')`** deixou o filho com
  `nvim_get_mode() = {mode="n", blocking=true}`.

---

## Não confirmado

- **O snacks.input:** por que dois `<Esc>` seguidos deixam o Insert pendente
  até a próxima tecla, enquanto um só funciona (E8). A fonte mostra o
  `stopinsert` agendado e a flag conferida na tecla seguinte, mas não fecha o
  caso de duas teclas.
- **Que o `escape-time` do tmux não se aplica a `send-keys`:** inferido de
  `tty-keys.c` L970 e `cmd-send-keys.c` L89, e compatível com E6 e E7, sem
  traçar o caminho inteiro no código.
- **Por que o `rpcrequest` falha** depois de `nvim_ui_attach` feito por um pai
  Neovim com `jobstart` (E3), e por que `rpcrequest` dentro do callback de
  `vim.wait` falha ou trava.
- **Por que o primeiro `:redraw` antes do `VimEnter`** desenha a flutuante no
  lugar errado (E1).
- **Se `--remote-send` conta como tecla digitada** para undo e afins.
- **`VimResized` e `nvim_input_mouse`** num filho com cliente de UI: não
  testados.
- **`nvim_input_mouse` sem UI não fazer nada:** vem de `docs/agents/testing.md`,
  não reverificado.
- **`vim.mpack.Unpacker` e `vim.mpack.Session`:** existem e são usados pelo
  cliente de testes do Neovim, mas não são API documentada no `lua.txt`.
- **Se algum servidor MCP da §2.8 lê a tela renderizada.**
- **`--remote-ui` contra um servidor headless dentro do tmux:** documentado
  ([remote]), não testado.
- **O conteúdo da issue neovim/neovim#34592**, citada em `dev_test.txt`: não
  foi lido.

---

## Fontes

### Documentação do Neovim 0.12.5 (`$VIMRUNTIME/doc`, espelho em `v0.12.5`)

- `starting.txt`:
  - `*--clean*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt#L90-L95
  - `*-es*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt#L191-L215
  - `*-l*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt#L217-L248
  - `*-u*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt#L326-L344
  - `*--embed*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt#L381-L403
  - `*--headless*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt#L405-L421
  - `*--listen*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt#L423-L429
  - `*initialization*`, passo 4: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt#L449
- `remote.txt`: `*--remote-send*`, `*--remote-expr*`, `*--remote-ui*`, `*--server*`, `*E5600*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/remote.txt#L47-L123
- `channel.txt`:
  - `*channel-intro*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/channel.txt#L14-L30
  - `*channel-rpc*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/channel.txt#L144-L149
  - `*channel-stdio*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/channel.txt#L152-L171
- `api.txt`:
  - `*rpc*` e `*rpc-connecting*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L17-L91
  - `*api-fast*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L157-L168
  - `*nvim_exec_lua()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L754-L781
  - `*nvim_feedkeys()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L783-L810
  - `*nvim_get_mode()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L1033-L1043
  - `*nvim_input()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L1114-L1139
  - `*nvim_input_mouse()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L1141-L1176
  - `*nvim_list_uis()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L1218-L1228
  - `*nvim__exec_lua_fast()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L1723-L1744
  - `*nvim__redraw()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L1839-L1869
  - `*api-ui*`, `*nvim_ui_attach()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L3690-L3711
- `api-ui-events.txt`:
  - `*ui-option*`, `*ui-ext-options*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api-ui-events.txt#L23-L69
  - `redraw`/`flush`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api-ui-events.txt#L71-L119
  - `*ui-startup*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api-ui-events.txt#L122-L148
  - `*ui-global*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api-ui-events.txt#L161-L284
  - `*ui-linegrid*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api-ui-events.txt#L287-L306
  - `*ui-multigrid*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api-ui-events.txt#L604-L715
  - `*ui-cmdline*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api-ui-events.txt#L762-L806
  - `*ui-messages*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api-ui-events.txt#L825-L935
- `lua.txt`:
  - `*vim.in_fast_event()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/lua.txt#L688-L693
  - `*vim.schedule()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/lua.txt#L719-L728
  - `*vim.ui_attach()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/lua.txt#L798-L847
  - `*vim.wait()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/lua.txt#L856-L899
  - `*vim.defer_fn()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/lua.txt#L1276-L1288
  - `*vim.on_key()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/lua.txt#L1372-L1405
  - `*vim.mpack*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/lua.txt#L4172-L4194
- `vimfn.txt`:
  - `*feedkeys()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vimfn.txt#L2257-L2301
  - `*jobstart()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vimfn.txt#L5464-L5555
  - `*mode()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vimfn.txt#L6928-L6980
  - `*screenattr()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vimfn.txt#L8235-L8246
  - `*screenstring()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vimfn.txt#L8341-L8353
  - `*serverstart()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vimfn.txt#L8793-L8825
  - `*sockconnect()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vimfn.txt#L10079
  - `*stdioopen()*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vimfn.txt#L10375-L10394
- `vvars.txt` `*v:servername*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vvars.txt#L588-L596
- `options.txt`:
  - `*'timeout'*`, `*'timeoutlen'*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/options.txt#L6881-L6892
  - `*'ttimeout'*`, `*'ttimeoutlen'*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/options.txt#L6960-L6980
- `map.txt` `*:map-alt-keys*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/map.txt#L825-L839
- `insert.txt` `*:stopinsert*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/insert.txt#L2042-L2046
- `tui.txt` `*tui-input*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/tui.txt#L136-L161
- `dev_test.txt` `*dev-test*`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/dev_test.txt
- `news-0.10.txt`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/news-0.10.txt
- `news-0.11.txt`: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/news-0.11.txt
- `news.txt` (mudanças da 0.12): https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/news.txt

### Código do Neovim (`v0.12.5`)

- `test/functional/ui/screen.lua`: https://github.com/neovim/neovim/blob/v0.12.5/test/functional/ui/screen.lua
  - L1-L105, L180-L316, L400-L495, L776-L870, L1298, L1663
- `test/functional/testnvim.lua`: https://github.com/neovim/neovim/blob/v0.12.5/test/functional/testnvim.lua
  - L34-L56, L361-L381, L485-L527, L589-L600, L795-L799
- `test/client/uv_stream.lua`: https://github.com/neovim/neovim/blob/v0.12.5/test/client/uv_stream.lua#L167-L197
- `test/client/rpc_stream.lua`: https://github.com/neovim/neovim/blob/v0.12.5/test/client/rpc_stream.lua#L6-L60
- `src/nvim/msgpack_rpc/channel.c`: https://github.com/neovim/neovim/blob/v0.12.5/src/nvim/msgpack_rpc/channel.c#L245-L258
- `src/nvim/api/vim.c`: https://github.com/neovim/neovim/blob/v0.12.5/src/nvim/api/vim.c#L282-L374
- `src/nvim/tui/input.c`: https://github.com/neovim/neovim/blob/v0.12.5/src/nvim/tui/input.c#L476-L499
- `src/nvim/event/socket.c`: https://github.com/neovim/neovim/blob/v0.12.5/src/nvim/event/socket.c#L172-L173
- `src/nvim/edit.c`: https://github.com/neovim/neovim/blob/v0.12.5/src/nvim/edit.c#L552-L559
- `src/nvim/ex_docmd.c`: https://github.com/neovim/neovim/blob/v0.12.5/src/nvim/ex_docmd.c#L7470-L7475
- `cmake.deps/deps.txt`: https://github.com/neovim/neovim/blob/v0.12.5/cmake.deps/deps.txt#L1

### Outros projetos

- **mini.nvim** (`6664ea9af6c43dc31934e27476bbe61c556c8dc1`):
  - `lua/mini/test.lua`: https://github.com/echasnovski/mini.nvim/blob/6664ea9af6c43dc31934e27476bbe61c556c8dc1/lua/mini/test.lua
    - L811, L1132-L1200, L1231-L1245, L1309-L1425, L1532-L1610
  - `TESTING.md`: https://github.com/echasnovski/mini.nvim/blob/6664ea9af6c43dc31934e27476bbe61c556c8dc1/TESTING.md
    - L701-L711, L844-L903
  - `doc/mini-test.txt`: https://github.com/echasnovski/mini.nvim/blob/6664ea9af6c43dc31934e27476bbe61c556c8dc1/doc/mini-test.txt
- **plenary.nvim** (`74b06c6c75e4eeb3108ec01852001636d85a932b`):
  - `README.md` L224-L280: https://github.com/nvim-lua/plenary.nvim/blob/74b06c6c75e4eeb3108ec01852001636d85a932b/README.md#L224-L280
  - `lua/plenary/test_harness.lua` L43-L110: https://github.com/nvim-lua/plenary.nvim/blob/74b06c6c75e4eeb3108ec01852001636d85a932b/lua/plenary/test_harness.lua#L43-L110
- **tmux** (`3.7c`):
  - `tmux.1`, `send-keys` L4019-L4069: https://github.com/tmux/tmux/blob/3.7c/tmux.1#L4019-L4069
  - `tmux.1`, `capture-pane` L2670-L2729: https://github.com/tmux/tmux/blob/3.7c/tmux.1#L2670-L2729
  - `tmux.1`, `escape-time` L4388-L4392: https://github.com/tmux/tmux/blob/3.7c/tmux.1#L4388-L4392
  - `cmd-send-keys.c`: https://github.com/tmux/tmux/blob/3.7c/cmd-send-keys.c (L89, L119-L133)
  - `tty-keys.c` L970: https://github.com/tmux/tmux/blob/3.7c/tty-keys.c#L970
- **pynvim** (`eb8a178bc0970f3a08772119cec287436522beab`) `pynvim/__init__.py` L84-L147: https://github.com/neovim/pynvim/blob/eb8a178bc0970f3a08772119cec287436522beab/pynvim/__init__.py#L84-L147
- **node-client** (`ff604a1ea09f4383855e18119b0fee921307e8e6`):
  - `packages/neovim/src/attach/attach.ts`: https://github.com/neovim/node-client/blob/ff604a1ea09f4383855e18119b0fee921307e8e6/packages/neovim/src/attach/attach.ts#L17-L43
  - `README.md` L66-L76: https://github.com/neovim/node-client/blob/ff604a1ea09f4383855e18119b0fee921307e8e6/README.md#L66-L76
- **vusted** (`42dd69e4a185d3738f983c621f96dd60f413fd53`) `README.md`: https://github.com/notomo/vusted/blob/42dd69e4a185d3738f983c621f96dd60f413fd53/README.md
- **nlua** (`9da8d7ec50cd6ef9f80f018fcd102deadf407d19`) `README.md`: https://github.com/mfussenegger/nlua/blob/9da8d7ec50cd6ef9f80f018fcd102deadf407d19/README.md
- **mcp-neovim-server** (`9076bbb34a08f44a743ad66c78638ef22da58ab0`):
  - `README.md`: https://github.com/bigcodegen/mcp-neovim-server/blob/9076bbb34a08f44a743ad66c78638ef22da58ab0/README.md
  - `src/neovim.ts`: https://github.com/bigcodegen/mcp-neovim-server/blob/9076bbb34a08f44a743ad66c78638ef22da58ab0/src/neovim.ts
- **nvim-mcp (linw1995)** (`986be68135a05ebdb727e73e609ffda0bbbbfdf6`):
  - `README.md`: https://github.com/linw1995/nvim-mcp/blob/986be68135a05ebdb727e73e609ffda0bbbbfdf6/README.md
  - `Cargo.toml` L62: https://github.com/linw1995/nvim-mcp/blob/986be68135a05ebdb727e73e609ffda0bbbbfdf6/Cargo.toml#L62
- **nvim-mcp (paulburgess1357)** (`4e581a15113d40de41a601a2ef4b3369be6da5ae`):
  - `README.md` L7: https://github.com/paulburgess1357/nvim-mcp/blob/4e581a15113d40de41a601a2ef4b3369be6da5ae/README.md#L7
  - `pyproject.toml` L28-L30: https://github.com/paulburgess1357/nvim-mcp/blob/4e581a15113d40de41a601a2ef4b3369be6da5ae/pyproject.toml#L28-L30
- **snacks.nvim** (`e6fd58c82f2f3fcddd3fe81703d47d6d48fc7b9f`, a versão instalada) `lua/snacks/input.lua`: https://github.com/folke/snacks.nvim/blob/e6fd58c82f2f3fcddd3fe81703d47d6d48fc7b9f/lua/snacks/input.lua (L64-L73, L184-L188)
- **libuv** (`v1.52.1`) `src/unix/pipe.c` L92-L98: https://github.com/libuv/libuv/blob/v1.52.1/src/unix/pipe.c#L92-L98
- **Linux** (`v6.12`) `include/uapi/linux/un.h` L7-L11: https://github.com/torvalds/linux/blob/v6.12/include/uapi/linux/un.h#L7-L11; e `man 7 unix` (Linux man-pages, instalado)

[st-clean]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt#L90-L95
[st-es]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt#L191-L215
[st-l]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt#L217-L248
[st-u]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt#L326-L344
[st-embed]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt#L381-L403
[st-headless]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt#L405-L421
[st-listen]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt#L423-L429
[st-init4]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/starting.txt#L449
[remote]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/remote.txt#L47-L123
[ch-rpc]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/channel.txt#L144-L149
[ch-stdio]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/channel.txt#L152-L171
[api-rpc]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L17-L91
[api-fast]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L157-L168
[api-exec-lua]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L754-L781
[api-feedkeys]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L783-L810
[api-get-mode]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L1033-L1043
[api-input]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L1114-L1139
[api-input-mouse]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L1141-L1176
[api-exec-lua-fast]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L1723-L1744
[api-redraw]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L1839-L1869
[api-ui-attach]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api.txt#L3690-L3711
[ui-option]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api-ui-events.txt#L23-L69
[ui-redraw]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api-ui-events.txt#L71-L119
[ui-startup]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api-ui-events.txt#L122-L148
[ui-global]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api-ui-events.txt#L161-L284
[ui-linegrid]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api-ui-events.txt#L287-L306
[ui-multigrid]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api-ui-events.txt#L604-L715
[ui-cmdline]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api-ui-events.txt#L762-L806
[ui-messages]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/api-ui-events.txt#L825-L935
[lua-in-fast]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/lua.txt#L688-L693
[lua-schedule]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/lua.txt#L719-L728
[lua-ui-attach]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/lua.txt#L798-L847
[lua-wait]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/lua.txt#L856-L899
[lua-defer]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/lua.txt#L1276-L1288
[lua-on-key]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/lua.txt#L1372-L1405
[lua-mpack]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/lua.txt#L4172-L4194
[fn-feedkeys]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vimfn.txt#L2257-L2301
[fn-jobstart]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vimfn.txt#L5464-L5555
[fn-mode]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vimfn.txt#L6928-L6980
[fn-screenattr]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vimfn.txt#L8235-L8246
[fn-screenstring]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vimfn.txt#L8341-L8353
[fn-serverstart]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vimfn.txt#L8793-L8825
[fn-sockconnect]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vimfn.txt#L10079
[fn-stdioopen]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vimfn.txt#L10375-L10394
[vv-servername]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/vvars.txt#L588-L596
[opt-timeout]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/options.txt#L6881-L6892
[opt-ttimeout]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/options.txt#L6960-L6980
[map-alt]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/map.txt#L825-L839
[ins-stopinsert]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/insert.txt#L2042-L2046
[tui-input]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/tui.txt#L136-L161
[dev-test]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/dev_test.txt
[news-010]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/news-0.10.txt
[news-011]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/news-0.11.txt
[news-012]: https://github.com/neovim/neovim/blob/v0.12.5/runtime/doc/news.txt
[nv-screen-head]: https://github.com/neovim/neovim/blob/v0.12.5/test/functional/ui/screen.lua#L1-L105
[nv-screen-new]: https://github.com/neovim/neovim/blob/v0.12.5/test/functional/ui/screen.lua#L180-L316
[nv-screen-expect]: https://github.com/neovim/neovim/blob/v0.12.5/test/functional/ui/screen.lua#L400-L495
[nv-screen-wait]: https://github.com/neovim/neovim/blob/v0.12.5/test/functional/ui/screen.lua#L776-L870
[nv-screen-grid]: https://github.com/neovim/neovim/blob/v0.12.5/test/functional/ui/screen.lua#L1298
[nv-screen-snap]: https://github.com/neovim/neovim/blob/v0.12.5/test/functional/ui/screen.lua#L1663
[nv-testnvim-argv]: https://github.com/neovim/neovim/blob/v0.12.5/test/functional/testnvim.lua#L34-L56
[nv-testnvim-feed]: https://github.com/neovim/neovim/blob/v0.12.5/test/functional/testnvim.lua#L361-L381
[nv-testnvim-session]: https://github.com/neovim/neovim/blob/v0.12.5/test/functional/testnvim.lua#L485-L527
[nv-testnvim-newargv]: https://github.com/neovim/neovim/blob/v0.12.5/test/functional/testnvim.lua#L589-L600
[nv-testnvim-poke]: https://github.com/neovim/neovim/blob/v0.12.5/test/functional/testnvim.lua#L795-L799
[nv-uvstream]: https://github.com/neovim/neovim/blob/v0.12.5/test/client/uv_stream.lua#L167-L197
[nv-rpcstream]: https://github.com/neovim/neovim/blob/v0.12.5/test/client/rpc_stream.lua#L6-L60
[nv-channel]: https://github.com/neovim/neovim/blob/v0.12.5/src/nvim/msgpack_rpc/channel.c#L245-L258
[nv-apivim]: https://github.com/neovim/neovim/blob/v0.12.5/src/nvim/api/vim.c#L282-L374
[nv-tuiinput]: https://github.com/neovim/neovim/blob/v0.12.5/src/nvim/tui/input.c#L476-L499
[nv-socket]: https://github.com/neovim/neovim/blob/v0.12.5/src/nvim/event/socket.c#L172-L173
[nv-deps]: https://github.com/neovim/neovim/blob/v0.12.5/cmake.deps/deps.txt#L1
[nv-edit]: https://github.com/neovim/neovim/blob/v0.12.5/src/nvim/edit.c#L552-L559
[nv-exdocmd]: https://github.com/neovim/neovim/blob/v0.12.5/src/nvim/ex_docmd.c#L7470-L7475
[mini-start]: https://github.com/echasnovski/mini.nvim/blob/6664ea9af6c43dc31934e27476bbe61c556c8dc1/lua/mini/test.lua#L1132-L1200
[mini-typekeys]: https://github.com/echasnovski/mini.nvim/blob/6664ea9af6c43dc31934e27476bbe61c556c8dc1/lua/mini/test.lua#L1309-L1399
[mini-screenshot]: https://github.com/echasnovski/mini.nvim/blob/6664ea9af6c43dc31934e27476bbe61c556c8dc1/lua/mini/test.lua#L1401-L1425
[mini-refshot]: https://github.com/echasnovski/mini.nvim/blob/6664ea9af6c43dc31934e27476bbe61c556c8dc1/lua/mini/test.lua#L811
[mini-doc-typekeys]: https://github.com/echasnovski/mini.nvim/blob/6664ea9af6c43dc31934e27476bbe61c556c8dc1/lua/mini/test.lua#L1557-L1583
[mini-doc-screenshot]: https://github.com/echasnovski/mini.nvim/blob/6664ea9af6c43dc31934e27476bbe61c556c8dc1/lua/mini/test.lua#L1585-L1610
[mini-testing]: https://github.com/echasnovski/mini.nvim/blob/6664ea9af6c43dc31934e27476bbe61c556c8dc1/TESTING.md
[pl-readme]: https://github.com/nvim-lua/plenary.nvim/blob/74b06c6c75e4eeb3108ec01852001636d85a932b/README.md#L224-L280
[pl-harness]: https://github.com/nvim-lua/plenary.nvim/blob/74b06c6c75e4eeb3108ec01852001636d85a932b/lua/plenary/test_harness.lua#L43-L110
[tmux-man-sendkeys]: https://github.com/tmux/tmux/blob/3.7c/tmux.1#L4019-L4069
[tmux-man-capture]: https://github.com/tmux/tmux/blob/3.7c/tmux.1#L2670-L2729
[tmux-man-escape]: https://github.com/tmux/tmux/blob/3.7c/tmux.1#L4388-L4392
[tmux-sendkeys-c]: https://github.com/tmux/tmux/blob/3.7c/cmd-send-keys.c
[tmux-ttykeys]: https://github.com/tmux/tmux/blob/3.7c/tty-keys.c#L970
[pynvim]: https://github.com/neovim/pynvim/blob/eb8a178bc0970f3a08772119cec287436522beab/pynvim/__init__.py#L84-L147
[node-attach]: https://github.com/neovim/node-client/blob/ff604a1ea09f4383855e18119b0fee921307e8e6/packages/neovim/src/attach/attach.ts#L17-L43
[node-readme]: https://github.com/neovim/node-client/blob/ff604a1ea09f4383855e18119b0fee921307e8e6/README.md#L66-L76
[vusted]: https://github.com/notomo/vusted/blob/42dd69e4a185d3738f983c621f96dd60f413fd53/README.md
[nlua]: https://github.com/mfussenegger/nlua/blob/9da8d7ec50cd6ef9f80f018fcd102deadf407d19/README.md
[mcp1-readme]: https://github.com/bigcodegen/mcp-neovim-server/blob/9076bbb34a08f44a743ad66c78638ef22da58ab0/README.md
[mcp1-src]: https://github.com/bigcodegen/mcp-neovim-server/blob/9076bbb34a08f44a743ad66c78638ef22da58ab0/src/neovim.ts
[mcp2-readme]: https://github.com/linw1995/nvim-mcp/blob/986be68135a05ebdb727e73e609ffda0bbbbfdf6/README.md
[mcp2-cargo]: https://github.com/linw1995/nvim-mcp/blob/986be68135a05ebdb727e73e609ffda0bbbbfdf6/Cargo.toml#L62
[mcp3-readme]: https://github.com/paulburgess1357/nvim-mcp/blob/4e581a15113d40de41a601a2ef4b3369be6da5ae/README.md#L7
[mcp3-py]: https://github.com/paulburgess1357/nvim-mcp/blob/4e581a15113d40de41a601a2ef4b3369be6da5ae/pyproject.toml#L28-L30
[snacks-input]: https://github.com/folke/snacks.nvim/blob/e6fd58c82f2f3fcddd3fe81703d47d6d48fc7b9f/lua/snacks/input.lua#L64-L188
[libuv-pipe]: https://github.com/libuv/libuv/blob/v1.52.1/src/unix/pipe.c#L92-L98
[linux-un]: https://github.com/torvalds/linux/blob/v6.12/include/uapi/linux/un.h#L7-L11
