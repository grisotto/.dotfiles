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

`make lint` exits non-zero on warnings, and two of them are older than this plugin: the unused `client` and `bufnr` of the commented-out `on_attach` stub in `lua/plugins/astrolsp.lua`, straight from the AstroNvim template. A clean run today is "0 errors, 2 warnings" — read the warnings, don't read the exit code.
