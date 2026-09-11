local clipboard = require "tests.helpers.clipboard"
local confirm = require "tests.helpers.confirm"
local document = require "tests.helpers.document"
local editor = require "tests.helpers.editor"
local entry = require "tests.helpers.entry"
local fixture = require "tests.helpers.fixture"
local input = require "tests.helpers.input"
local panel = require "tests.helpers.panel"
local quickfix = require "tests.helpers.quickfix"
local report = require "tests.helpers.report"
local review = require "review"
local visual = require "tests.helpers.visual"

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

---Annotate a run of lines of a file, the way the reviewer does it: open the
---file from the panel, select the lines, press the key that annotates on them.
---@param section string
---@param pattern string
---@param first integer
---@param last integer
---@param text string
local function annotate_selection(section, pattern, first, last, text)
  panel.focus(section, pattern)
  panel.feed "o"
  input.answer(text)
  visual.press_on_lines(first, last, "<Leader>ga")
end

---The same items from both formats, which is the contract of the two keys
---(ADR-0006): whatever a test asserts about the items holds for each of them.
---@param expected TestReportItem[]
local function generate_both_and_expect_items(expected)
  panel.feed "R"
  panel.feed "M"
  assert.same(expected, report.items "xml")
  assert.same(expected, report.items "markdown")
end

describe("relatório de revisão", function()
  before_each(function()
    review.setup {}
    fixture.data_dir()
    input.install()
    -- O tipo é pedido antes do texto em toda anotação. Quem não fala dele
    -- escolhe `issue`, que é o `<CR>` do revisor numa anotação nova.
    confirm.install()
    confirm.answer_matching "^issue "
    clipboard.clear()
  end)

  after_each(function()
    input.restore()
    confirm.restore()
    quickfix.clear()
    editor.reset()
    vim.cmd.cd(vim.fn.fnameescape(config_root))
    fixture.cleanup()
  end)

  describe("documento", function()
    it("sai em XML pelo R e em markdown pelo M, com os mesmos itens", function()
      -- Os dois formatos existem para ser comparados (ADR-0006): o conteúdo é o
      -- mesmo, e só a sintaxe muda.
      local repo = repo_with_a_change()
      repo:write("b.txt", "outro arquivo\n")

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")
      annotate_file("Untracked", "b%.txt", "este nem devia estar aqui")
      panel.feed "R"
      panel.feed "M"

      local expected = {
        {
          id = 1,
          type = "issue",
          file = "a.txt",
          lines = "2",
          code = { "dois alterado" },
          text = "arrumar isso",
          not_found = false,
        },
        -- A anotação de arquivo não tem linha nem código: ela é sobre o arquivo
        -- inteiro, e não sobre um trecho dele.
        { id = 2, type = "issue", file = "b.txt", text = "este nem devia estar aqui", not_found = false },
      }
      assert.same(expected, report.items "xml")
      assert.same(expected, report.items "markdown")
    end)

    it("leva os mesmos valores nos dois formatos, sem entidades no XML", function()
      -- Quem lê é um modelo de linguagem, e não um parser: um `&amp;` só no XML
      -- faria os dois formatos dizerem coisas diferentes do mesmo ponto.
      local repo = fixture.repo()
      repo:commit_file("a & b.txt", "um\n")
      repo:write("a & b.txt", "if a < b && b > c\n")

      open_in(repo.root)
      annotate_line("Unstaged", "a & b%.txt", 1, 'o "maior" & o <menor>')

      generate_both_and_expect_items {
        {
          id = 1,
          type = "issue",
          file = "a & b.txt",
          lines = "1",
          code = { "if a < b && b > c" },
          text = 'o "maior" & o <menor>',
          not_found = false,
        },
      }
    end)

    it("põe numa lista só, por arquivo e por linha, com a anotação de arquivo antes das de linha", function()
      local repo = repo_with_a_change()
      repo:write("b.txt", "outro arquivo\n")

      open_in(repo.root)
      annotate_file("Untracked", "b%.txt", "este nem devia estar aqui")
      annotate_line("Unstaged", "a%.txt", 3, "a de baixo")
      annotate_line("Unstaged", "a%.txt", 1, "a de cima")
      annotate_file("Unstaged", "a%.txt", "o arquivo todo")

      generate_both_and_expect_items {
        { id = 1, type = "issue", file = "a.txt", text = "o arquivo todo", not_found = false },
        { id = 2, type = "issue", file = "a.txt", lines = "1", code = { "um" }, text = "a de cima", not_found = false },
        {
          id = 3,
          type = "issue",
          file = "a.txt",
          lines = "3",
          code = { "três" },
          text = "a de baixo",
          not_found = false,
        },
        { id = 4, type = "issue", file = "b.txt", text = "este nem devia estar aqui", not_found = false },
      }
    end)

    it("diz onde, em que branch e sobre qual HEAD, e não quando foi gerado", function()
      -- O caminho absoluto é o que situa o agente mesmo rodando num
      -- subdiretório; a data seria ruído para ele.
      local repo = repo_with_a_change()
      local head = vim.trim(repo:git { "rev-parse", "HEAD" })

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")
      panel.feed "R"
      panel.feed "M"

      local expected = { root = repo.root, branch = "main", reference = "HEAD " .. head }
      assert.same(expected, report.header "xml")
      assert.same(expected, report.header "markdown")
      for _, format in ipairs { "xml", "markdown" } do
        assert.is_nil(
          report.text(format):match "%d%d%d%d%-%d%d%-%d%d",
          "o relatório em " .. format .. " traz uma data"
        )
      end
    end)

    it("diz ao agente o que o tipo pede, como localizar, que não faça commit e como responder", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")
      panel.feed "R"
      panel.feed "M"

      local instructions = report.instructions "xml"
      assert.equals(instructions, report.instructions "markdown")
      for _, wanted in ipairs {
        "revisão humana",
        "`issue`",
        "Não altere nada além do que as anotações pedem",
        "pelo código citado",
        "Não faça commit",
        "`feito`",
        "`respondido`",
        "`recusado: motivo`",
      } do
        assert.is_truthy(
          instructions:find(wanted, 1, true),
          ("o preâmbulo não diz %q:\n%s"):format(wanted, instructions)
        )
      end
      -- Sem trecho não encontrado, a regra dele é uma leitura a mais que não se
      -- aplica.
      assert.is_nil(instructions:find("não encontrado", 1, true))
    end)

    it("cita o trecho em markdown na linguagem do arquivo", function()
      local repo = fixture.repo()
      repo:commit_file("a.py", "print(1)\n")
      repo:write("a.py", "print(2)\n")

      open_in(repo.root)
      annotate_line("Unstaged", "a%.py", 1, "por que mudou?")
      panel.feed "M"

      local text = report.text "markdown"
      assert.is_truthy(text:find("## 1. issue · a.py:1\n\n```python\nprint(2)\n```\n\npor que mudou?", 1, true), text)
    end)

    it("cita todas as linhas de uma anotação de trecho", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_selection("Unstaged", "a%.txt", 2, 3, "estas duas andam juntas")

      generate_both_and_expect_items {
        {
          id = 1,
          type = "issue",
          file = "a.txt",
          lines = "2-3",
          code = { "dois alterado", "três" },
          text = "estas duas andam juntas",
          not_found = false,
        },
      }
      assert.same(
        { { file = repo.root .. "/a.txt", lnum = 2, end_lnum = 3, text = "#1 issue · estas duas andam juntas" } },
        quickfix.items()
      )
    end)

    it("vai para a área de transferência no formato da tecla apertada", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")

      -- Com a quebra no fim: o documento vai linha a linha, e é assim que o
      -- editor entrega ao clipboard um texto copiado por linhas.
      panel.feed "R"
      assert.equals(report.text "xml" .. "\n", clipboard.content())
      -- E para o registro sem nome, que é o do `p` do próprio editor.
      assert.equals(report.text "xml", table.concat(vim.fn.getreg('"', 1, true), "\n"))

      panel.feed "M"
      assert.equals(report.text "markdown" .. "\n", clipboard.content())
      assert.equals(report.text "markdown", table.concat(vim.fn.getreg('"', 1, true), "\n"))
    end)

    it("não mexe na área de transferência quando não há anotação para relatar", function()
      -- O que o revisor tinha copiado vale mais que um relatório vazio, que não
      -- diz nada.
      local repo = repo_with_a_change()
      vim.fn.setreg("+", "o que o revisor tinha copiado")

      open_in(repo.root)
      panel.feed "R"
      panel.feed "M"

      assert.equals("o que o revisor tinha copiado", clipboard.content())
    end)

    it("grava um arquivo por formato, fora do repositório revisado", function()
      -- O relatório não pode sujar a lista que o painel está mostrando
      -- (ADR-0004): o que o git enxerga depois de gerá-lo é o que ele
      -- enxergava antes.
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")
      panel.feed "R"
      panel.feed "M"

      assert.equals(" M a.txt\n", repo:git { "status", "--porcelain" })
      assert.is_truthy(report.path("xml"):match "%-worktree%.xml$")
      assert.is_truthy(report.path("markdown"):match "%-worktree%.md$")
      for _, format in ipairs { "xml", "markdown" } do
        assert.is_nil(report.path(format):find(repo.root, 1, true))
      end
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

      generate_both_and_expect_items {
        {
          id = 1,
          type = "issue",
          file = "a.txt",
          lines = "2",
          code = { "dois alterado" },
          text = "do working tree",
          not_found = false,
        },
      }
    end)

    it("não grava nada quando a revisão não tem anotação nenhuma", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.feed "R"
      panel.feed "M"

      assert.is_false(report.exists())
      assert.same({}, quickfix.items())
    end)

    it("leva embora os relatórios anteriores, dos dois formatos, quando a revisão fica sem anotação", function()
      -- O relatório é sobre a revisão de agora: um documento com a observação
      -- que o revisor tirou de volta diria o que a revisão não diz mais, e é
      -- ele que sai do editor para o agente.
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "escrita sem querer")
      panel.feed "R"
      panel.feed "M"
      assert.is_true(report.exists "xml")
      assert.is_true(report.exists "markdown")

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
      panel.feed "M"

      assert.equals(1, #vim.fn.glob(elsewhere .. "/*.xml", false, true))
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
      review.report { format = "markdown" }

      assert.equals(elsewhere.root, report.header("xml").root)
      assert.equals("sobre este aqui", report.items("xml")[1].text)
      assert.equals("sobre este aqui", report.items("markdown")[1].text)
    end)

    it("é regravado no mesmo lugar quando o revisor gera de novo", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "primeira leitura")
      panel.feed "R"
      local first = report.path "xml"

      annotate_line("Unstaged", "a%.txt", 3, "segunda leitura")
      panel.feed "R"

      assert.equals(first, report.path "xml")
      assert.same({ "primeira leitura", "segunda leitura" }, {
        report.items("xml")[1].text,
        report.items("xml")[2].text,
      })
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

      generate_both_and_expect_items {
        {
          id = 1,
          type = "issue",
          file = "a.txt",
          lines = "4",
          code = { "dois alterado" },
          text = "arrumar isso",
          not_found = false,
        },
      }
      assert.same({ { file = repo.root .. "/a.txt", lnum = 4, text = "#1 issue · arrumar isso" } }, quickfix.items())
    end)

    it("entrega na mesma lista, marcada como não encontrada, a anotação cuja âncora sumiu", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 3, "esta continua onde estava")
      annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")
      -- A linha anotada some do arquivo: a anotação não é descartada nem
      -- apontada para a linha errada (ADR-0003). Ela vai no lugar em que foi
      -- escrita, sem linha, com o código que havia quando foi escrita.
      repo:write("a.txt", "um\noutra coisa no lugar\ntrês\n")

      generate_both_and_expect_items {
        { id = 1, type = "issue", file = "a.txt", code = { "dois alterado" }, text = "arrumar isso", not_found = true },
        {
          id = 2,
          type = "issue",
          file = "a.txt",
          lines = "3",
          code = { "três" },
          text = "esta continua onde estava",
          not_found = false,
        },
      }
    end)

    it("só com um trecho não encontrado o preâmbulo diz o que fazer com ele", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")
      repo:write("a.txt", "um\noutra coisa no lugar\ntrês\n")
      panel.feed "R"
      panel.feed "M"

      local instructions = report.instructions "xml"
      assert.equals(instructions, report.instructions "markdown")
      assert.is_truthy(instructions:find("trecho não encontrado", 1, true), instructions)
    end)

    it("reancora o trecho onde as linhas dele estão juntas, e não onde uma delas está sozinha", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_selection("Unstaged", "a%.txt", 2, 3, "estas duas andam juntas")
      -- A primeira linha do trecho entra solta no topo, mais perto de onde ele
      -- estava do que o próprio trecho, que desceu duas linhas: sozinha ela não
      -- é o trecho sobre o qual a anotação foi escrita.
      repo:write("a.txt", "dois alterado\nzero\num\ndois alterado\ntrês\n")

      generate_both_and_expect_items {
        {
          id = 1,
          type = "issue",
          file = "a.txt",
          lines = "4-5",
          code = { "dois alterado", "três" },
          text = "estas duas andam juntas",
          not_found = false,
        },
      }
    end)

    it("entrega não encontrado o trecho em que uma das linhas mudou", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_selection("Unstaged", "a%.txt", 2, 3, "estas duas andam juntas")
      repo:write("a.txt", "um\ndois alterado\ntrês mudou\n")

      generate_both_and_expect_items {
        {
          id = 1,
          type = "issue",
          file = "a.txt",
          code = { "dois alterado", "três" },
          text = "estas duas andam juntas",
          not_found = true,
        },
      }
    end)
  end)

  describe("tipo da anotação", function()
    it("sai em cada item dos dois formatos e da quickfix", function()
      local repo = repo_with_a_change()
      repo:write("b.txt", "outro arquivo\n")

      open_in(repo.root)
      confirm.answer_matching "^question "
      annotate_line("Unstaged", "a%.txt", 2, "por que mudou?")
      confirm.answer_matching "^revert "
      annotate_file("Untracked", "b%.txt", "este nem devia estar aqui")

      generate_both_and_expect_items {
        {
          id = 1,
          type = "question",
          file = "a.txt",
          lines = "2",
          code = { "dois alterado" },
          text = "por que mudou?",
          not_found = false,
        },
        { id = 2, type = "revert", file = "b.txt", text = "este nem devia estar aqui", not_found = false },
      }
      assert.same({
        { file = repo.root .. "/a.txt", lnum = 2, text = "#1 question · por que mudou?" },
        { file = repo.root .. "/b.txt", lnum = 0, text = "#2 revert · este nem devia estar aqui" },
      }, quickfix.items())
    end)

    it("lista no preâmbulo só as instruções dos tipos usados, na ordem da configuração", function()
      review.setup { annotation_types = { { name = "praise", instruction = "não mexa nisto." } } }
      local repo = repo_with_a_change()

      open_in(repo.root)
      confirm.answer_matching "^praise "
      annotate_line("Unstaged", "a%.txt", 1, "ficou bom")
      confirm.answer_matching "^refactor "
      annotate_line("Unstaged", "a%.txt", 3, "extraia isto")
      panel.feed "R"
      panel.feed "M"

      local instructions = report.instructions "xml"
      assert.equals(instructions, report.instructions "markdown")
      local refactor = instructions:find("- `refactor`: refatore", 1, true)
      local praise = instructions:find("- `praise`: não mexa nisto.", 1, true)
      assert.is_truthy(refactor and praise and refactor < praise, instructions)
      for _, unused in ipairs { "`issue`", "`test`", "`revert`", "`question`", "`suggestion`", "`nitpick`" } do
        assert.is_nil(instructions:find(unused, 1, true), ("o preâmbulo fala de %s:\n%s"):format(unused, instructions))
      end
    end)

    it("conta como issue a anotação gravada antes de haver tipo", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      confirm.answer_matching "^praise "
      annotate_line("Unstaged", "a%.txt", 3, "ficou bom")
      document.plant {
        path = "a.txt",
        mode = "worktree",
        line = 1,
        anchor = "um",
        text = "gravada antes do tipo",
        at = "2026-01-01T00:00:00Z",
      }

      generate_both_and_expect_items {
        {
          id = 1,
          type = "issue",
          file = "a.txt",
          lines = "1",
          code = { "um" },
          text = "gravada antes do tipo",
          not_found = false,
        },
        {
          id = 2,
          type = "praise",
          file = "a.txt",
          lines = "3",
          code = { "três" },
          text = "ficou bom",
          not_found = false,
        },
      }
      assert.is_truthy(report.instructions("xml"):find("- `issue`: corrija", 1, true))
      assert.equals("#1 issue · gravada antes do tipo", quickfix.items()[1].text)
    end)
  end)

  describe("quickfix", function()
    it("recebe os pontos anotados com o id e o tipo, e abre para o revisor percorrê-los", function()
      -- O `#id type` é o que liga o ponto da lista à linha de resposta do agente.
      local repo = repo_with_a_change()
      repo:write("b.txt", "outro arquivo\n")

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")
      annotate_file("Untracked", "b%.txt", "este nem devia estar aqui")
      panel.feed "R"

      -- Sem linha a anotação de arquivo é do arquivo: a quickfix a leva para o
      -- topo dele, que é onde ela está presa.
      assert.same({
        { file = repo.root .. "/a.txt", lnum = 2, text = "#1 issue · arrumar isso" },
        { file = repo.root .. "/b.txt", lnum = 0, text = "#2 issue · este nem devia estar aqui" },
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

    it("leva a anotação não encontrada sem linha, e dizendo que não está no disco", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      annotate_line("Unstaged", "a%.txt", 2, "arrumar isso")
      repo:write("a.txt", "um\noutra coisa no lugar\ntrês\n")
      panel.feed "M"

      assert.same(
        { { file = repo.root .. "/a.txt", lnum = 0, text = "#1 issue · não está no disco · arrumar isso" } },
        quickfix.items()
      )
    end)

    it("resume numa linha a anotação que tem várias", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "A"
      entry.type "primeira linha\nsegunda linha"
      entry.save()
      panel.feed "R"

      assert.same(
        { { file = repo.root .. "/a.txt", lnum = 0, text = "#1 issue · primeira linha …" } },
        quickfix.items()
      )
    end)
  end)
end)
