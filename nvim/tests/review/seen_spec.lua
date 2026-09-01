local fixture = require "tests.helpers.fixture"
local panel = require "tests.helpers.panel"
local review = require "review"

local config_root = vim.fn.getcwd()

---Open the review panel on `dir`, in a tabpage of its own — the way a reviewer
---with one repository per tab does it. Each test gets a panel that was never
---opened before, so what it observes is the state on disk and not what a
---previous test left in this one.
---@param dir string
local function open_in(dir)
  vim.cmd "tabnew"
  vim.cmd.tcd(vim.fn.fnameescape(dir))
  review.open()
end

describe("visto", function()
  before_each(function()
    review.setup {}
    fixture.data_dir()
  end)

  after_each(function()
    review.close()
    -- Back to the first tabpage before dropping the others: `tabonly!` keeps
    -- the current one, and keeping a tabpage of the test would carry its panel
    -- — and the state of its sections — into the next one.
    vim.cmd "tabfirst"
    vim.cmd "tabonly!"
    vim.cmd.cd(vim.fn.fnameescape(config_root))
    fixture.cleanup()
  end)

  describe("marcar e desmarcar", function()
    it("tira o arquivo marcado da sua seção e o põe em Vistos", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:commit_file("b.txt", "b v1\n")
      repo:write("a.txt", "a v2\n")
      repo:write("b.txt", "b v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "v"

      assert.same({ "M  b.txt" }, panel.section "Unstaged")
      assert.equals(1, panel.section_count "Vistos")
    end)

    it("devolve o arquivo à sua seção quando desmarcado de dentro de Vistos", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:write("a.txt", "a v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "v"
      panel.focus_section "Vistos"
      panel.feed "<CR>"

      panel.focus("Vistos", "a%.txt")
      panel.feed "v"

      assert.same({ "M  a.txt" }, panel.section "Unstaged")
      assert.is_nil(panel.section_count "Vistos")
    end)

    it("marca uma vez só o mesmo conteúdo em dois arquivos", function()
      -- O visto é do conteúdo, não do nome (ADR-0002): dois arquivos com o
      -- mesmo texto são o mesmo texto para ler.
      local repo = fixture.repo()
      repo:write("um.txt", "idêntico\n")
      repo:write("outro.txt", "idêntico\n")

      open_in(repo.root)
      panel.focus("Untracked", "um%.txt")
      panel.feed "v"

      assert.is_nil(panel.section_count "Untracked")
      assert.equals(2, panel.section_count "Vistos")
    end)

    it("marca como visto um arquivo conflitado", function()
      -- Um conflito é lido no working tree, com os marcadores e tudo: é aquele
      -- texto que o revisor viu, e é ele que a marca identifica.
      local repo = fixture.repo()
      repo:conflict "conflito.txt"

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "v"

      assert.is_nil(panel.section_count "Conflitos")
      assert.equals(1, panel.section_count "Vistos")
    end)

    it("marca a exclusão de um arquivo sem marcar a de outro", function()
      -- Um arquivo apagado não tem conteúdo para identificar; o que a marca
      -- guarda é a identidade do que sumiu, e duas exclusões diferentes não
      -- podem virar a mesma marca.
      local repo = fixture.repo()
      repo:commit_file("um.txt", "um\n")
      repo:commit_file("outro.txt", "outro\n")
      repo:delete "um.txt"
      repo:delete "outro.txt"

      open_in(repo.root)
      panel.focus("Unstaged", "um%.txt")
      panel.feed "v"

      assert.same({ "D  outro.txt" }, panel.section "Unstaged")
      assert.equals(1, panel.section_count "Vistos")
    end)
  end)

  describe("cabeçalho", function()
    it("mostra quantos foram vistos do total", function()
      local repo = fixture.repo()
      repo:write("um.txt", "um\n")
      repo:write("dois.txt", "dois\n")
      repo:write("tres.txt", "três\n")

      open_in(repo.root)
      assert.equals("Revisão · main · 0/3 vistos", panel.lines()[1])

      panel.focus("Untracked", "um%.txt")
      panel.feed "v"

      assert.equals("Revisão · main · 1/3 vistos", panel.lines()[1])
    end)

    it("conta as duas mudanças do arquivo que está staged e unstaged", function()
      -- Uma mudança staged e uma unstaged no mesmo arquivo são dois diffs para
      -- ler, e as seções já as contam assim. Marcar uma não marca a outra: o
      -- que está no índice e o que está no disco são conteúdos diferentes.
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:write("a.txt", "a v2\n")
      repo:add "a.txt"
      repo:write("a.txt", "a v3\n")

      open_in(repo.root)
      assert.equals("Revisão · main · 0/2 vistos", panel.lines()[1])

      panel.focus("Staged", "a%.txt")
      panel.feed "v"

      assert.equals("Revisão · main · 1/2 vistos", panel.lines()[1])
      assert.is_nil(panel.section_count "Staged")
      assert.same({ "M  a.txt" }, panel.section "Unstaged")
      assert.equals(1, panel.section_count "Vistos")
    end)
  end)

  describe("entre sessões", function()
    it("mantém os vistos depois de fechar e reabrir", function()
      -- Nada do visto fica na memória do painel: reabrir só encontra o arquivo
      -- em Vistos se o documento gravado no diretório de dados foi lido de novo.
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:write("a.txt", "a v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "v"
      review.close()

      open_in(repo.root)

      assert.is_nil(panel.section_count "Unstaged")
      assert.equals(1, panel.section_count "Vistos")
    end)

    it("volta a listar como não visto o arquivo que mudou depois de marcado", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:write("a.txt", "a v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "v"

      repo:write("a.txt", "a v3\n")
      panel.feed "r"

      assert.same({ "M  a.txt" }, panel.section "Unstaged")
      assert.is_nil(panel.section_count "Vistos")
    end)
  end)

  describe("a seção Vistos", function()
    it("fica no fim, depois das seções que ainda faltam", function()
      local repo = fixture.repo()
      repo:write("visto.txt", "visto\n")
      repo:write("falta.txt", "falta\n")

      open_in(repo.root)
      panel.focus("Untracked", "visto%.txt")
      panel.feed "v"

      local untracked, vistos
      for index, line in ipairs(panel.lines()) do
        if line:match "^Untracked" then untracked = index end
        if line:match "Vistos" then vistos = index end
      end
      assert.is_not_nil(untracked)
      assert.is_true(untracked < vistos)
    end)

    it("chega recolhida, e expande e recolhe na sua linha", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:write("a.txt", "a v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "v"
      assert.same({}, panel.section "Vistos")

      panel.focus_section "Vistos"
      panel.feed "<CR>"
      assert.same({ "M  a.txt" }, panel.section "Vistos")

      panel.focus_section "Vistos"
      panel.feed "<CR>"
      assert.same({}, panel.section "Vistos")
    end)
  end)

  describe("identificar o conteúdo", function()
    ---@param calls fun(): string[]
    ---@return string[] the git calls that hashed something
    local function hashing(calls)
      return vim.tbl_filter(function(call) return call:match "hash%-object" ~= nil end, calls())
    end

    it("hasheia todo o working tree num processo só", function()
      local repo = fixture.repo()
      for index = 1, 10 do
        repo:write(("arquivo-%d.txt"):format(index), ("conteúdo %d\n"):format(index))
      end
      local calls = fixture.trace_git()

      open_in(repo.root)

      assert.equals(10, panel.section_count "Untracked")
      assert.equals(1, #hashing(calls))
    end)

    it("não hasheia de novo o que o índice já identificou", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:write("a.txt", "a v2\n")
      repo:add "a.txt"
      local calls = fixture.trace_git()

      open_in(repo.root)
      panel.focus("Staged", "a%.txt")
      panel.feed "v"

      assert.equals(1, panel.section_count "Vistos")
      assert.same({}, hashing(calls))
    end)
  end)

  describe("apresentação dos vistos", function()
    it("deixa o arquivo visto esmaecido no lugar quando configurado assim", function()
      review.setup { seen_display = "dimmed" }
      local repo = fixture.repo()
      repo:write("visto.txt", "visto\n")
      repo:write("falta.txt", "falta\n")

      open_in(repo.root)
      panel.focus("Untracked", "visto%.txt")
      panel.feed "v"

      assert.same({ "?  falta.txt", "?  visto.txt" }, panel.section "Untracked")
      assert.is_nil(panel.section_count "Vistos")
      assert.same({ "?  visto.txt" }, panel.dimmed())
      assert.equals("Revisão · main · 1/2 vistos", panel.lines()[1])
    end)

    it("não esmaece nada na apresentação em seção própria", function()
      local repo = fixture.repo()
      repo:write("visto.txt", "visto\n")

      open_in(repo.root)
      panel.focus("Untracked", "visto%.txt")
      panel.feed "v"

      assert.equals(1, panel.section_count "Vistos")
      assert.same({}, panel.dimmed())
    end)
  end)
end)
