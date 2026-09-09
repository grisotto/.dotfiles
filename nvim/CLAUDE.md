## Agent skills

### Issue tracker

Issues are tracked with the `knot` CLI (tickets under `.tickets/`, config in `.knot.edn`). See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles map onto knot's `tags` and `mode` fields (knot has no generic label field). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` + `docs/adr/` at the repo root (created lazily as needed). See `docs/agents/domain.md`.

### Tests

`make test` runs the suite in headless Neovim (plenary busted). See `docs/agents/testing.md` for the single seam and the fixture helpers.

### Depurar o que só acontece no editor do revisor

Suíte verde e "não funciona aqui" convivem: a sessão do revisor tem estado que a
suíte não tem. O retrato da sessão é um script que ele roda e que **grava um
txt** para o agente ler, em vez de imprimir na tela dele. Veja
`docs/agents/debugging.md` — o molde, as quatro perguntas e a reprodução
headless com a configuração real.

### Lint and formatting

`make lint` (selene) and `make format` (stylua). Both binaries are Mason's, in `~/.local/share/nvim/mason/bin` — that directory is appended to `PATH` in `~/.bashrc` and `~/.zshrc`, so nothing has to be installed. On a machine without them, `:MasonInstall selene stylua` inside Neovim is the whole setup.

`make lint` exits non-zero on warnings. A clean run is `0 errors, 0 warnings, 0 parse errors`.

### Agilis workflow

The project-specific integration lives in `lua/agilis.lua`; keep its detection,
commands and buffer-local mappings together there. `lua/plugins/agilis.lua`
only calls `require("agilis").setup()` during AstroCore startup. The integration
activates only when Neovim finds a `workspace.edn` root that also contains
`bb.edn`, `shadow-cljs.edn` and `bases/webapp`.

Use `README.md` as the user-facing command and mapping reference. When a mapping
changes, update that table in the same change. These implementation choices are
the maintenance constraints that are easy to miss by reading the table:

- The backend nREPL uses the canonical port `7888`.
- Shadow CLJS chooses a dynamic port. Read `.shadow-cljs/nrepl.port`, connect to
  it, then select build `main` with `ConjureShadowSelect main`. A successful
  connection can return either `[:selected :main]` or `:already-selected`.
- A CLJS evaluation needs a browser connected to the running build. `No
  available JS runtime` means the nREPL connection worked but no browser has
  loaded the application.
- Conjure uses its `clojure.test` runner. This project does not use Kaocha.
- Clojure and EDN autoformat-on-save stay disabled in
  `lua/plugins/astrolsp.lua`. `AgilisFormat` writes the buffer and runs `bb fmt`
  so the project's formatter and parenthesis repair remain the source of truth.
- JVM tests run through `clojure -M:poly test project:development
  brick:<brick>`. CLJS tests remain a separate `bb test:cljs` command.
- `vim-jack-in` is intentionally absent. The external `tmux-agilis3.sh`
  workflow owns the backend and Shadow processes; Conjure only connects to
  them.
- The Clojure AstroCommunity pack supplies clojure-lsp, Conjure, ParPar,
  clj-kondo and cljfmt. Keep one import for each community pack in
  `lua/community.lua`; duplicate imports make future overrides hard to trace.

After changing this integration, completion means all of these checks pass:

1. Run `PATH="$PATH:$HOME/.local/share/nvim/mason/bin" make format`.
2. Run `PATH="$PATH:$HOME/.local/share/nvim/mason/bin" make lint` and require
   zero errors and warnings.
3. Redirect `make test` to a file, check its exit code, and inspect the file for
   failed or errored specs.
4. Open a `.clj` or `.cljs` file inside Hickory and confirm the `Agilis*`
   commands and `<Leader>a` mappings exist. Confirm they do not attach in an
   unrelated repository.
5. With `tmux-agilis3.sh` running, connect to Shadow and evaluate a small CLJS
   expression. The proof is a `ClojureScript` session in the Conjure log and an
   evaluated value, not only a successful TCP connection.
