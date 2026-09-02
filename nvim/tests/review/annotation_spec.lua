local document = require "tests.helpers.document"
local editor = require "tests.helpers.editor"
local entry = require "tests.helpers.entry"
local fixture = require "tests.helpers.fixture"
local input = require "tests.helpers.input"
local panel = require "tests.helpers.panel"
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

---Read a file of the review the way the reviewer does — opening it from the
---panel — and put the cursor on `line`, which is the line about to be
---annotated.
---@param section string e.g. "Unstaged"
---@param pattern string a Lua pattern matching the entry
---@param line integer
local function read_file(section, pattern, line)
  panel.focus(section, pattern)
  panel.feed "o"
  vim.api.nvim_win_set_cursor(0, { line, 0 })
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

describe("anotação", function()
  before_each(function()
    review.setup {}
    fixture.data_dir()
    input.install()
  end)

  after_each(function()
    input.restore()
    editor.reset()
    vim.cmd.cd(vim.fn.fnameescape(config_root))
    fixture.cleanup()
  end)

  describe("anotação de linha", function()
    it("grava caminho, modo, linha, âncora, texto e instante", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      input.answer "arrumar isso"
      review.annotate()

      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals("a.txt", annotations[1].path)
      assert.equals("worktree", annotations[1].mode)
      assert.equals(2, annotations[1].line)
      assert.equals("dois alterado", annotations[1].anchor)
      assert.equals("arrumar isso", annotations[1].text)
      assert.is_truthy(annotations[1].at:match "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%dZ$")
    end)

    it("pergunta numa entrada de uma linha, dizendo em que ponto está", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      input.answer "arrumar isso"
      review.annotate()

      assert.equals(1, #input.prompts())
      assert.is_truthy(input.prompts()[1]:match "a%.txt:2")
      assert.is_false(entry.is_open())
    end)

    it("edita a anotação que já está na linha em vez de empilhar outra", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      input.answer "primeira"
      review.annotate()
      input.answer "segunda"
      review.annotate()

      -- A segunda entrada chega com o que já estava escrito: é o que o revisor
      -- vê para saber que está editando, e não escrevendo do zero.
      assert.same({ "", "primeira" }, input.defaults())
      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals("segunda", annotations[1].text)
    end)

    it("anota duas linhas do mesmo arquivo como duas anotações", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 1)
      input.answer "sobre a primeira"
      review.annotate()
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      input.answer "sobre a terceira"
      review.annotate()

      local annotations = document.annotations()
      assert.equals(2, #annotations)
      assert.same({ 1, 3 }, { annotations[1].line, annotations[2].line })
    end)

    it("não grava nada quando a entrada é cancelada", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      review.annotate()

      assert.same({}, document.annotations())
    end)

    it("apaga a anotação quando o revisor esvazia o texto", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      input.answer "escrita sem querer"
      review.annotate()
      input.answer ""
      review.annotate()

      assert.same({}, document.annotations())
    end)

    it("não anota um buffer que não é arquivo do repositório", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      input.answer "não tem onde prender isto"
      review.annotate()

      assert.same({}, input.prompts())
      assert.same({}, document.annotations())
    end)
  end)

  describe("entrada longa", function()
    it("grava o texto de várias linhas escrito nela", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      review.annotate { long = true }

      assert.is_true(entry.is_open())
      assert.same({}, input.prompts())
      -- A entrada diz em que ponto está, como a de uma linha diz: quem apertou
      -- a tecla na linha errada vê isso antes de escrever.
      assert.equals("Anotação em a.txt:2", entry.title())
      entry.type "primeira linha\nsegunda linha"
      entry.save()

      assert.is_false(entry.is_open())
      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals("primeira linha\nsegunda linha", annotations[1].text)
      assert.equals(2, annotations[1].line)
    end)

    it("chega com o texto da anotação que já está na linha", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      input.answer "curta"
      review.annotate()
      review.annotate { long = true }

      assert.same({ "curta" }, entry.lines())
      entry.cancel()
    end)

    it("não muda nada quando é cancelada", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      review.annotate { long = true }
      entry.type "escrita e jogada fora"
      entry.cancel()

      assert.is_false(entry.is_open())
      assert.same({}, document.annotations())
    end)

    it("é a entrada de uma anotação que não cabe numa linha, venha por onde vier", function()
      -- Uma anotação de várias linhas prefilling uma entrada de uma linha só
      -- seria ilegível; a tecla curta cai na entrada longa quando é isso que
      -- há para editar.
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      review.annotate { long = true }
      entry.type "primeira linha\nsegunda linha"
      entry.save()

      review.annotate()

      assert.is_true(entry.is_open())
      assert.same({ "primeira linha", "segunda linha" }, entry.lines())
      entry.cancel()
    end)
  end)

  describe("anotação de arquivo", function()
    it("é criada do painel, sem linha e sem âncora", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      input.answer "o arquivo inteiro está no lugar errado"
      panel.feed "a"

      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals("a.txt", annotations[1].path)
      assert.equals("o arquivo inteiro está no lugar errado", annotations[1].text)
      assert.is_nil(annotations[1].line)
      assert.is_nil(annotations[1].anchor)
    end)

    it("edita a que já existe em vez de empilhar outra", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      input.answer "primeira"
      panel.feed "a"
      panel.focus("Unstaged", "a%.txt")
      input.answer "segunda"
      panel.feed "a"

      assert.same({ "", "primeira" }, input.defaults())
      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals("segunda", annotations[1].text)
    end)

    it("abre a entrada longa com a segunda tecla do painel", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "A"

      assert.is_true(entry.is_open())
      assert.equals("Anotação em a.txt", entry.title())
      entry.type "uma observação\nque não cabe numa frase"
      entry.save()

      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals("uma observação\nque não cabe numa frase", annotations[1].text)
      assert.is_nil(annotations[1].line)
    end)

    it("é uma anotação diferente da que está numa linha do mesmo arquivo", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      input.answer "sobre o arquivo"
      panel.feed "a"
      read_file("Unstaged", "a%.txt", 2)
      input.answer "sobre a linha"
      review.annotate()

      assert.equals(2, #document.annotations())
    end)
  end)

  describe("contagem no painel", function()
    it("mostra na linha do arquivo quantas anotações ele tem", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      assert.same({ "M  a.txt" }, panel.section "Unstaged")

      read_file("Unstaged", "a%.txt", 1)
      input.answer "uma"
      review.annotate()
      assert.same({ "M  a.txt  ✎ 1" }, panel.section "Unstaged")

      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      input.answer "outra"
      review.annotate()
      assert.same({ "M  a.txt  ✎ 2" }, panel.section "Unstaged")
    end)

    it("não marca o arquivo que não tem anotação nenhuma", function()
      local repo = repo_with_a_change()
      repo:write("b.txt", "sem anotação\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      input.answer "só neste"
      panel.feed "a"

      assert.same({ "M  a.txt  ✎ 1" }, panel.section "Unstaged")
      assert.same({ "?  b.txt" }, panel.section "Untracked")
    end)

    it("acompanha o arquivo para a seção Vistos", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      input.answer "anotado e lido"
      panel.feed "a"
      panel.focus("Unstaged", "a%.txt")
      panel.feed "v"
      panel.focus_section "Vistos"
      panel.feed "<CR>"

      assert.same({ "M  a.txt  ✎ 1" }, panel.section "Vistos")
    end)
  end)

  describe("entre sessões", function()
    it("mantém as anotações depois de fechar e reabrir o painel", function()
      -- Nada fica na memória do painel: reabrir só volta a contar a anotação
      -- se o documento gravado no diretório de dados foi lido de novo.
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      input.answer "para o dia seguinte"
      panel.feed "a"
      review.close()

      open_in(repo.root)

      assert.same({ "M  a.txt  ✎ 1" }, panel.section "Unstaged")
    end)

    it("não escreve nada dentro do repositório revisado", function()
      -- A anotação não pode sujar a lista que o painel está mostrando
      -- (ADR-0004): o que o git enxerga depois de anotar é o que ele enxergava
      -- antes.
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      input.answer "fora do repositório"
      panel.feed "a"

      assert.equals(" M a.txt\n", repo:git { "status", "--porcelain" })
      assert.is_true(document.exists())
    end)
  end)
end)
