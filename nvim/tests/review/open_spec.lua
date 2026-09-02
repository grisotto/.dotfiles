local diff = require "tests.helpers.diff"
local editor = require "tests.helpers.editor"
local fixture = require "tests.helpers.fixture"
local panel = require "tests.helpers.panel"
local review = require "review"

local config_root = vim.fn.getcwd()

---Open the review panel with the editor sitting inside `dir`.
---@param dir string
local function open_in(dir)
  vim.fn.chdir(dir)
  review.open()
end

---Paths compare only after resolving: the fixture lives under a temporary
---directory, which is a symlink on some machines.
---@param path string
---@return string
local function resolved(path) return vim.fn.resolve(path) end

---@return string the file the current window is showing
local function current_file() return resolved(vim.api.nvim_buf_get_name(0)) end

---@return integer how many windows the tabpage has
local function window_count() return #vim.api.nvim_tabpage_list_wins(0) end

---Open the panel on `dir` in a tabpage of its own, the way a reviewer with one
---repository per tab does it: a new tabpage with its own `:tcd`.
---@param dir string
local function open_in_new_tab(dir)
  vim.cmd "tabnew"
  vim.cmd.tcd(vim.fn.fnameescape(dir))
  review.open()
end

describe("abrir o que está na linha", function()
  before_each(function() review.setup {} end)

  after_each(function()
    editor.reset()
    -- `cd`, not `chdir`: a tabpage local directory of a test would otherwise
    -- outlive it.
    vim.cmd.cd(vim.fn.fnameescape(config_root))
    fixture.cleanup()
  end)

  describe("diff de duas vias", function()
    it("numa linha de staged compara o HEAD com o índice", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "no head\n")
      repo:write("a.txt", "no indice\n")
      repo:add "a.txt"
      repo:write("a.txt", "no working tree\n")

      open_in(repo.root)
      panel.focus("Staged", "a%.txt")
      panel.feed "<CR>"

      assert.same({ { "no head" }, { "no indice" } }, diff.sides())
    end)

    it("numa linha de unstaged compara o índice com o working tree", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "no head\n")
      repo:write("a.txt", "no indice\n")
      repo:add "a.txt"
      repo:write("a.txt", "no working tree\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"

      assert.same({ { "no indice" }, { "no working tree" } }, diff.sides())
    end)

    it("abre ao lado do painel, na mesma aba, com o painel ainda visível", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "v1\n")
      repo:write("a.txt", "v2\n")
      local tabpage = vim.api.nvim_get_current_tabpage()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"

      assert.equals(tabpage, vim.api.nvim_get_current_tabpage())
      assert.equals(1, #vim.api.nvim_list_tabpages())
      assert.is_true(panel.is_open())
      assert.equals(3, window_count())
    end)

    it("compara o arquivo novo com um lado vazio", function()
      local repo = fixture.repo()
      repo:write("novo.txt", "acabou de nascer\n")
      repo:add "novo.txt"

      open_in(repo.root)
      panel.focus("Staged", "novo%.txt")
      panel.feed "<CR>"

      assert.same({ { "" }, { "acabou de nascer" } }, diff.sides())
    end)

    it("compara o arquivo deletado com um lado vazio", function()
      local repo = fixture.repo()
      repo:commit_file("morto.txt", "ainda vivo\n")
      repo:git { "rm", "morto.txt" }

      open_in(repo.root)
      panel.focus("Staged", "morto%.txt")
      panel.feed "<CR>"

      assert.same({ { "ainda vivo" }, { "" } }, diff.sides())
    end)

    it("compara o arquivo untracked com um lado vazio", function()
      local repo = fixture.repo()
      repo:write("nao-rastreado.txt", "só no disco\n")

      open_in(repo.root)
      panel.focus("Untracked", "nao%-rastreado%.txt")
      panel.feed "<CR>"

      assert.same({ { "" }, { "só no disco" } }, diff.sides())
    end)

    it("põe o arquivo de verdade do lado do working tree, para poder editar ali", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "v1\n")
      repo:write("a.txt", "v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"

      local right = assert(diff.right(), "o diff não abriu")
      local bufnr = vim.api.nvim_win_get_buf(right)
      assert.equals(resolved(repo.root .. "/a.txt"), resolved(vim.api.nvim_buf_get_name(bufnr)))
      assert.equals("", vim.bo[bufnr].buftype)
      assert.is_true(vim.bo[bufnr].modifiable)
    end)

    it("mostra do lado do HEAD o conteúdo do caminho antigo de um arquivo renomeado", function()
      local repo = fixture.repo()
      repo:commit_file("antigo.txt", "uma linha longa o bastante para o git enxergar a renomeação\n")
      repo:git { "mv", "antigo.txt", "novo.txt" }

      open_in(repo.root)
      panel.focus("Staged", "novo%.txt")
      panel.feed "<CR>"

      assert.same({
        { "uma linha longa o bastante para o git enxergar a renomeação" },
        { "uma linha longa o bastante para o git enxergar a renomeação" },
      }, diff.sides())
    end)

    it("um diff novo substitui o anterior, sem deixar janela órfã", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:commit_file("b.txt", "b v1\n")
      repo:write("a.txt", "a v2\n")
      repo:write("b.txt", "b v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      panel.focus("Unstaged", "b%.txt")
      panel.feed "<CR>"

      assert.same({ { "b v1" }, { "b v2" } }, diff.sides())
      assert.equals(3, window_count())
    end)

    it("continua nomeando os dois lados ao abrir o mesmo diff de novo", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "no head\n")
      repo:write("a.txt", "no indice\n")
      repo:add "a.txt"

      open_in(repo.root)
      panel.focus("Staged", "a%.txt")
      panel.feed "<CR>"
      panel.feed "<CR>"

      assert.same({ "review://HEAD/a.txt", "review://índice/a.txt" }, diff.names())
    end)

    it("não desmonta o diff da outra aba", function()
      -- Uma aba por repositório: o diff que o painel de uma aba montou não é o
      -- diff que o painel da outra substitui.
      local a = fixture.repo()
      a:commit_file("a.txt", "a v1\n")
      a:write("a.txt", "a v2\n")
      local b = fixture.repo()
      b:commit_file("b.txt", "b v1\n")
      b:write("b.txt", "b v2\n")

      open_in_new_tab(a.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"

      open_in_new_tab(b.root)
      panel.focus("Unstaged", "b%.txt")
      panel.feed "<CR>"

      vim.cmd "tabprevious"
      assert.same({ { "a v1" }, { "a v2" } }, diff.sides())
    end)

    it("não faz nada numa linha que não é arquivo", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "v1\n")
      repo:write("a.txt", "v2\n")

      open_in(repo.root)
      panel.focus_header()

      assert.has_no.errors(function() panel.feed "<CR>" end)
      assert.same({}, diff.sides())
      assert.equals(2, window_count())
    end)

    it("não monta o diff de duas vias num arquivo conflitado", function()
      -- Um conflito não tem conteúdo no estágio zero do índice: comparar duas
      -- vias ali não quer dizer nada. Ele vai para o merge tool do diffview.
      local repo = fixture.repo()
      repo:conflict "conflito.txt"

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")

      assert.has_no.errors(function() panel.feed "<CR>" end)
      assert.same({}, diff.sides())
    end)

    it("a apresentação alternativa não monta diff nosso, nem estoura sem o diffview", function()
      -- Ela é do diffview (ADR-0005), que não está no runtimepath da suíte.
      local repo = fixture.repo()
      repo:commit_file("a.txt", "v1\n")
      repo:write("a.txt", "v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")

      assert.has_no.errors(function() panel.feed "d" end)
      assert.same({}, diff.sides())
    end)
  end)

  describe("as três versões de um conflito", function()
    it("abre a nossa, a base e a que está entrando, lado a lado", function()
      local repo = fixture.repo()
      repo:conflict "conflito.txt"

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "D"

      assert.same({ { "atual" }, { "base" }, { "entrando" } }, diff.sides())
    end)

    it("abre na aba do painel, com a lista ainda visível ao lado", function()
      local repo = fixture.repo()
      repo:conflict "conflito.txt"
      local tabpage = vim.api.nvim_get_current_tabpage()

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "D"

      assert.equals(tabpage, vim.api.nvim_get_current_tabpage())
      assert.equals(1, #vim.api.nvim_list_tabpages())
      assert.is_true(panel.is_open())
      assert.equals(4, window_count())
    end)

    it("nomeia cada versão, que é como o revisor as distingue", function()
      local repo = fixture.repo()
      repo:conflict "conflito.txt"

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "D"

      assert.same({
        "review://atual/conflito.txt",
        "review://base/conflito.txt",
        "review://entrando/conflito.txt",
      }, diff.names())
    end)

    it("continua nomeando cada versão ao abrir o mesmo conflito de novo", function()
      -- As três só se distinguem pelo nome, e o nome de um buffer é único no
      -- editor: as versões de antes têm que sair da frente antes das novas.
      local repo = fixture.repo()
      repo:conflict "conflito.txt"

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "D"
      panel.feed "D"

      assert.same({
        "review://atual/conflito.txt",
        "review://base/conflito.txt",
        "review://entrando/conflito.txt",
      }, diff.names())
    end)

    it("mostra um lado vazio no conflito que não tem base", function()
      -- Os dois lados criaram o arquivo do nada: não há estágio 1 no índice.
      local repo = fixture.repo()
      repo:conflict_without_base "conflito.txt"

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "D"

      assert.same({ { "atual" }, { "" }, { "entrando" } }, diff.sides())
    end)

    it("substitui o diff que estava na tela, sem deixar janela órfã", function()
      local repo = fixture.repo()
      repo:conflict "conflito.txt"
      repo:write("a.txt", "só no disco\n")

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "D"
      panel.focus("Untracked", "a%.txt")
      panel.feed "<CR>"

      assert.same({ { "" }, { "só no disco" } }, diff.sides())
      assert.equals(3, window_count())
    end)

    it("não monta nada numa linha que não é conflito", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "v1\n")
      repo:write("a.txt", "v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")

      assert.has_no.errors(function() panel.feed "D" end)
      assert.same({}, diff.sides())
      assert.equals(2, window_count())
    end)
  end)

  describe("abrir o arquivo", function()
    it("abre o arquivo na janela principal, com o painel ainda visível", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "v1\n")
      repo:write("a.txt", "v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "o"

      assert.equals(resolved(repo.root .. "/a.txt"), current_file())
      assert.is_false(vim.wo[0].diff)
      assert.is_true(panel.is_open())
      assert.equals(2, window_count())
    end)

    it("abre o arquivo num split, sem tomar o lugar do que estava aberto", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "v1\n")
      repo:write("a.txt", "v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "O"

      assert.equals(resolved(repo.root .. "/a.txt"), current_file())
      assert.is_true(panel.is_open())
      assert.equals(3, window_count())
    end)

    it("abrir o arquivo depois de um diff não deixa meio diff na tela", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "v1\n")
      repo:write("a.txt", "v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      panel.feed "o"

      assert.same({}, diff.sides())
      assert.equals(resolved(repo.root .. "/a.txt"), current_file())
      assert.equals(2, window_count())
    end)

    it("abre um arquivo cujo caminho tem espaço e %", function()
      -- O caminho vira argumento de um comando do editor, onde `%` e espaço
      -- têm significado próprio.
      local repo = fixture.repo()
      repo:write("um % estranho.txt", "existe\n")

      open_in(repo.root)
      panel.focus("Untracked", "estranho")
      panel.feed "o"

      assert.equals(resolved(repo.root .. "/um % estranho.txt"), current_file())
      assert.same({ "existe" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("abre o arquivo untracked, que só existe no disco", function()
      local repo = fixture.repo()
      repo:write("nao-rastreado.txt", "só no disco\n")

      open_in(repo.root)
      panel.focus("Untracked", "nao%-rastreado%.txt")
      panel.feed "o"

      assert.equals(resolved(repo.root .. "/nao-rastreado.txt"), current_file())
      assert.same({ "só no disco" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)
  end)
end)
