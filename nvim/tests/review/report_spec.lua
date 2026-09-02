local document = require "tests.helpers.document"
local editor = require "tests.helpers.editor"
local entry = require "tests.helpers.entry"
local fixture = require "tests.helpers.fixture"
local input = require "tests.helpers.input"
local panel = require "tests.helpers.panel"
local quickfix = require "tests.helpers.quickfix"
local report = require "tests.helpers.report"
local review = require "review"

local config_root = vim.fn.getcwd()

---Open the review panel on `dir`, in a tabpage of its own — the way a reviewer
---with one repository per tab does it.
---@param dir string
local function open_in(dir)
  vim.cmd "tabnew"
  vim.cmd.tcd(vim.fn.fnameescape(dir))
  review.open()
end

---A repository with one file changed in the working tree, which is what there
---is to annotate.
---@return FixtureRepo
local function repo_with_a_change()
  local repo = fixture.repo()
  repo:commit_file("a.txt", "um\ndois\ntrês\n")
  repo:write("a.txt", "um\ndois alterado\ntrês\n")
  return repo
end

---Annotate a line of a file, the way the reviewer does it: open the file from
---the panel, put the cursor on the line, write the remark.
---@param section string e.g. "Unstaged"
---@param pattern string a Lua pattern matching the entry
---@param line integer
---@param text string
---@return integer winid the window the file was read in
local function annotate_line(section, pattern, line, text)
  panel.focus(section, pattern)
  panel.feed "o"
  vim.api.nvim_win_set_cursor(0, { line, 0 })
  input.answer(text)
  review.annotate()
  return vim.api.nvim_get_current_win()
end

---Annotate a whole file from the panel.
---@param section string
---@param pattern string
---@param text string
local function annotate_file(section, pattern, text)
  panel.focus(section, pattern)
  input.answer(text)
  panel.feed "a"
end

describe("relatório de revisão", function()
  before_each(function()
    review.setup {}
    fixture.data_dir()
    input.install()
  end)

  after_each(function()
    input.restore()
    quickfix.clear()
    editor.reset()
    vim.cmd.cd(vim.fn.fnameescape(config_root))
    fixture.cleanup()
  end)

  describe("documento", function()
    it("agrupa as anotações por arquivo, com a linha e o trecho citado", function()
      local repo = repo_with_a_change()
      repo:write("b.txt", "outro arquivo\n")

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")
      annotate_file("Untracked", "b%.txt", "este nem devia estar aqui")
      panel.feed "R"

      assert.same({ "a.txt", "b.txt" }, report.headings())
      assert.same({
        "**Linha 2**",
        "",
        "```text",
        "dois alterado",
        "```",
        "",
        "arrumar isso",
      }, report.section "a.txt")
      -- A anotação de arquivo não tem trecho para citar: ela é sobre o arquivo
      -- inteiro, e não sobre uma linha dele.
      assert.same({
        "**O arquivo inteiro**",
        "",
        "este nem devia estar aqui",
      }, report.section "b.txt")
    end)

    it("diz de que revisão é, e quantas anotações tem", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 1, "uma")
      annotate_line("Unstaged", "a%.txt", 3, "outra")
      panel.feed "R"

      local lines = report.lines()
      assert.is_truthy(lines[1]:match "^# Revisão de ")
      assert.is_truthy(lines[3]:match "^Working tree · 2 anotações em 1 arquivo · gerado em %d%d%d%d%-")
    end)

    it("cita o trecho na linguagem do arquivo, para quem lê o relatório fora do editor", function()
      local repo = fixture.repo()
      repo:commit_file("a.py", "print(1)\n")
      repo:write("a.py", "print(2)\n")

      open_in(repo.root)
      annotate_line("Unstaged", "a%.py", 1, "por que mudou?")
      panel.feed "R"

      assert.same({
        "**Linha 1**",
        "",
        "```python",
        "print(2)",
        "```",
        "",
        "por que mudou?",
      }, report.section "a.py")
    end)

    it("é gravado fora do repositório revisado", function()
      -- O relatório não pode sujar a lista que o painel está mostrando
      -- (ADR-0004): o que o git enxerga depois de gerá-lo é o que ele
      -- enxergava antes.
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")
      panel.feed "R"

      assert.is_true(report.exists())
      assert.equals(" M a.txt\n", repo:git { "status", "--porcelain" })
      assert.is_nil(report.path():find(repo.root, 1, true))
    end)

    it("contém apenas as anotações do modo atual", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "do working tree")
      document.plant {
        path = "a.txt",
        mode = "commit",
        line = 1,
        anchor = "um",
        text = "de outra revisão",
        at = "2026-01-01T00:00:00Z",
      }
      panel.feed "R"

      assert.is_nil(report.text():find("de outra revisão", 1, true))
      assert.same({ "a.txt" }, report.headings())
    end)

    it("não grava nada quando a revisão não tem anotação nenhuma", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.feed "R"

      assert.is_false(report.exists())
      assert.same({}, quickfix.items())
    end)

    it("leva embora o relatório anterior quando a revisão fica sem anotação", function()
      -- O relatório é sobre a revisão de agora: um documento com a observação
      -- que o revisor tirou de volta diria o que a revisão não diz mais, e é
      -- ele que sai do editor para um PR.
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "escrita sem querer")
      panel.feed "R"
      assert.is_true(report.exists())

      annotate_line("Unstaged", "a%.txt", 2, "")
      panel.feed "R"

      assert.is_false(report.exists())
      assert.same({}, quickfix.items())
    end)

    it("grava no diretório que o revisor configurou", function()
      local elsewhere = fixture.plain_dir()
      review.setup { report_directory = elsewhere }
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")
      panel.feed "R"

      assert.equals(1, #vim.fn.glob(elsewhere .. "/*.md", false, true))
      assert.is_false(report.exists())
    end)

    it("recusa um destino relativo, que cairia dentro do repositório revisado", function()
      -- Um caminho relativo é resolvido a partir do diretório do editor, que
      -- na revisão é o repositório revisado: o relatório apareceria como
      -- untracked na lista que o painel está mostrando (ADR-0004).
      assert.has_error(function() review.setup { report_directory = "relatorios" } end)
    end)

    it("gera o relatório do repositório do diretório atual quando o painel está fechado", function()
      local reviewed = repo_with_a_change()
      local elsewhere = repo_with_a_change()

      -- O painel desta aba listou um repositório e foi fechado; o revisor está
      -- em outro agora, e o relatório é da revisão que está acontecendo.
      open_in(reviewed.root)
      review.close()
      vim.cmd.tcd(vim.fn.fnameescape(elsewhere.root))
      vim.cmd.edit(vim.fn.fnameescape(elsewhere.root .. "/a.txt"))
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      input.answer "sobre este aqui"
      review.annotate()

      review.report()

      assert.is_truthy(report.text():find("sobre este aqui", 1, true))
    end)

    it("é regravado no mesmo lugar quando o revisor gera de novo", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "primeira leitura")
      panel.feed "R"
      local first = report.path()

      annotate_line("Unstaged", "a%.txt", 3, "segunda leitura")
      panel.feed "R"

      assert.equals(first, report.path())
      assert.is_truthy(report.text():find("segunda leitura", 1, true))
    end)
  end)

  describe("reancoragem", function()
    it("reancora a anotação cuja linha mudou de lugar", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")
      -- Duas linhas entram acima da anotada: o texto dela continua no arquivo,
      -- duas linhas abaixo de onde estava.
      repo:write("a.txt", "zero\nmeio\num\ndois alterado\ntrês\n")
      panel.feed "R"

      assert.same({
        "**Linha 4**",
        "",
        "```text",
        "dois alterado",
        "```",
        "",
        "arrumar isso",
      }, report.section "a.txt")
      assert.same({ { file = repo.root .. "/a.txt", lnum = 4, text = "arrumar isso" } }, quickfix.items())
    end)

    it("entrega marcada, em seção própria, a anotação cuja âncora sumiu", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")
      annotate_line("Unstaged", "a%.txt", 3, "esta continua onde estava")
      -- A linha anotada some do arquivo: a anotação não é descartada nem
      -- apontada para a linha errada (ADR-0003).
      repo:write("a.txt", "um\noutra coisa no lugar\ntrês\n")
      panel.feed "R"

      assert.same({ "a.txt", "Anotações deslocadas" }, report.headings())
      -- A que continua onde estava fica na seção do arquivo; a deslocada sai
      -- de lá e vai para a seção própria, com o trecho que havia quando foi
      -- escrita.
      local file_section = table.concat(report.section "a.txt", "\n")
      assert.is_truthy(file_section:find("esta continua onde estava", 1, true))
      assert.is_nil(file_section:find("arrumar isso", 1, true))

      local displaced = table.concat(report.section "Anotações deslocadas", "\n")
      assert.is_truthy(displaced:find("**a.txt · linha 2 quando foi escrita**", 1, true))
      assert.is_truthy(displaced:find("```text\ndois alterado\n```", 1, true))
      assert.is_truthy(displaced:find("arrumar isso", 1, true))
    end)
  end)

  describe("quickfix", function()
    it("recebe os pontos anotados, e abre para o revisor percorrê-los", function()
      local repo = repo_with_a_change()
      repo:write("b.txt", "outro arquivo\n")

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")
      annotate_file("Untracked", "b%.txt", "este nem devia estar aqui")
      panel.feed "R"

      -- Sem linha a anotação de arquivo é do arquivo: a quickfix a leva para o
      -- topo dele, que é onde ela está presa.
      assert.same({
        { file = repo.root .. "/a.txt", lnum = 2, text = "arrumar isso" },
        { file = repo.root .. "/b.txt", lnum = 0, text = "este nem devia estar aqui" },
      }, quickfix.items())
      assert.is_true(quickfix.is_open())
      assert.equals("Anotações da revisão", quickfix.title())
    end)

    it("chega a todo ponto pelo :cnext, inclusive no que não tem linha", function()
      -- Percorrer a lista é o que ela existe para permitir: um ponto que o
      -- `:cnext` pula está na lista sem estar ao alcance do revisor.
      local repo = repo_with_a_change()
      repo:write("b.txt", "outro arquivo\n")

      open_in(repo.root)
      local reading = annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")
      annotate_file("Untracked", "b%.txt", "este nem devia estar aqui")
      panel.feed "R"

      vim.api.nvim_set_current_win(reading)
      vim.cmd "cfirst"
      assert.equals(repo.root .. "/a.txt", vim.api.nvim_buf_get_name(0))
      vim.cmd "cnext"
      assert.equals(repo.root .. "/b.txt", vim.api.nvim_buf_get_name(0))
    end)

    it("leva a anotação deslocada sem linha, e dizendo que está deslocada", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")
      repo:write("a.txt", "um\noutra coisa no lugar\ntrês\n")
      panel.feed "R"

      assert.same({ { file = repo.root .. "/a.txt", lnum = 0, text = "deslocada · arrumar isso" } }, quickfix.items())
    end)

    it("resume numa linha a anotação que tem várias", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "A"
      entry.type "primeira linha\nsegunda linha"
      entry.save()
      panel.feed "R"

      assert.same({ { file = repo.root .. "/a.txt", lnum = 0, text = "primeira linha …" } }, quickfix.items())
    end)
  end)
end)
