local confirm = require "tests.helpers.confirm"
local diff = require "tests.helpers.diff"
local document = require "tests.helpers.document"
local editor = require "tests.helpers.editor"
local entry = require "tests.helpers.entry"
local fixture = require "tests.helpers.fixture"
local graph = require "tests.helpers.graph"
local help = require "tests.helpers.help"
local input = require "tests.helpers.input"
local notify = require "tests.helpers.notify"
local panel = require "tests.helpers.panel"
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

---A repository with one file staged and changed again on disk, one line above
---the staged change: line 2 of the index is line 3 of the disk, and line 2 of
---the disk is a line the index does not have.
---@return FixtureRepo
local function repo_with_a_staged_change()
  local repo = fixture.repo()
  repo:commit_file("a.txt", "um\ndois\ntrês\n")
  repo:write("a.txt", "um\ndois staged\ntrês\n")
  repo:add "a.txt"
  repo:write("a.txt", "zero\num\ndois staged\ntrês\n")
  return repo
end

---A repository whose last commit changed a file that the disk has moved on
---from since: a line went in above the one the commit changed, so line 2 of the
---commit is line 3 of the disk.
---@return FixtureRepo
local function repo_with_a_commit_moved_on()
  local repo = fixture.repo()
  repo:commit_file("a.txt", "um\ndois\ntrês\n", "primeiro")
  repo:commit_file("a.txt", "um\ndois no commit\ntrês\n", "segundo")
  repo:write("a.txt", "zero\num\ndois no commit\ntrês\n")
  return repo
end

---Read the diff of an entry the way the reviewer does — `<CR>` on its line —
---and put the cursor on `line` of one side of it: the right one, which is the
---side after the change, unless `side` says otherwise.
---@param section string e.g. "Staged"
---@param pattern string a Lua pattern matching the entry
---@param line integer
---@param side "left"|"right"|nil
local function read_diff(section, pattern, line, side)
  panel.focus(section, pattern)
  panel.feed "<CR>"
  local wins = diff.windows()
  local win = assert(side == "left" and wins[1] or wins[#wins], "o diff não abriu")
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { line, 0 })
end

---Select lines `first` to `last` of the file being read and press the key that
---annotates on them — the real one, which `review.setup` maps.
---@param first integer
---@param last integer
---@param opts { long: boolean|nil }|nil
local function annotate_selection(first, last, opts)
  visual.press_on_lines(first, last, opts and opts.long and "<Leader>gA" or "<Leader>ga")
end

describe("anotação", function()
  before_each(function()
    review.setup {}
    fixture.data_dir()
    input.install()
    -- O tipo é pedido antes do texto em toda anotação. Quem não fala dele
    -- escolhe `issue`, que é o `<CR>` do revisor numa anotação nova.
    confirm.install()
    confirm.answer_matching "^issue "
  end)

  after_each(function()
    input.restore()
    confirm.restore()
    notify.restore()
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

  describe("anotação de trecho", function()
    it("prende a anotação às linhas selecionadas, com o texto delas como âncora", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 1)
      input.answer "estas duas andam juntas"
      annotate_selection(2, 3)

      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals(2, annotations[1].line)
      assert.equals(3, annotations[1].end_line)
      assert.equals("dois alterado\ntrês", annotations[1].anchor)
      assert.equals("estas duas andam juntas", annotations[1].text)
      -- A entrada diz o trecho, como diz a linha: quem selecionou demais vê
      -- isso antes de escrever.
      assert.is_truthy(input.prompts()[1]:match "a%.txt:2%-3")
    end)

    it("sai do modo visual antes de perguntar", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 1)
      input.answer "fora da seleção"
      annotate_selection(1, 2)

      assert.equals("n", vim.fn.mode())
    end)

    it("vale na seleção feita de baixo para cima", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 1)
      input.answer "de trás para frente"
      annotate_selection(3, 2)

      local annotations = document.annotations()
      assert.same({ 2, 3 }, { annotations[1].line, annotations[1].end_line })
    end)

    it("é a anotação da linha quando a seleção tem uma linha só", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      input.answer "primeira"
      annotate_selection(2, 2)
      input.answer "segunda"
      review.annotate()

      assert.same({ "", "primeira" }, input.defaults())
      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.is_nil(annotations[1].end_line)
      assert.equals("segunda", annotations[1].text)
    end)

    it("edita o trecho já anotado, e é outra anotação que a da primeira linha dele", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      input.answer "só a linha"
      review.annotate()
      input.answer "o trecho"
      annotate_selection(2, 3)
      input.answer "o trecho, corrigido"
      annotate_selection(2, 3)

      assert.same({ "", "", "o trecho" }, input.defaults())
      local texts = vim.tbl_map(function(written) return written.text end, document.annotations())
      table.sort(texts)
      assert.same({ "o trecho, corrigido", "só a linha" }, texts)
    end)

    it("abre a entrada longa sobre a seleção", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 1)
      annotate_selection(1, 3, { long = true })

      assert.is_true(entry.is_open())
      assert.equals("issue em a.txt:1-3", entry.title())
      entry.type "três linhas\nde uma vez"
      entry.save()

      assert.same({ 1, 3 }, { document.annotations()[1].line, document.annotations()[1].end_line })
    end)
  end)

  describe("no diff de staged", function()
    it("anota a linha no lado de depois, o índice, com a âncora lida dele", function()
      local repo = repo_with_a_staged_change()

      open_in(repo.root)
      read_diff("Staged", "a%.txt", 2)
      input.answer "no índice"
      review.annotate()

      assert.same({ "issue em a.txt:2: " }, input.prompts())
      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals("a.txt", annotations[1].path)
      assert.equals("worktree", annotations[1].mode)
      assert.equals("index", annotations[1].version)
      assert.equals(2, annotations[1].line)
      assert.equals("dois staged", annotations[1].anchor)
      assert.equals("no índice", annotations[1].text)
    end)

    it("anota o trecho no lado de depois, com todas as linhas dele no índice", function()
      local repo = repo_with_a_staged_change()

      open_in(repo.root)
      read_diff("Staged", "a%.txt", 1)
      input.answer "estas duas andam juntas"
      annotate_selection(1, 2)

      assert.same({ "issue em a.txt:1-2: " }, input.prompts())
      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals("index", annotations[1].version)
      assert.same({ 1, 2 }, { annotations[1].line, annotations[1].end_line })
      assert.equals("um\ndois staged", annotations[1].anchor)
    end)

    it("é outro ponto que a mesma linha do arquivo no disco", function()
      -- A linha 2 do índice e a linha 2 do disco são linhas diferentes: anotar
      -- uma não edita a outra.
      local repo = repo_with_a_staged_change()

      open_in(repo.root)
      read_diff("Staged", "a%.txt", 2)
      input.answer "no índice"
      review.annotate()
      read_file("Unstaged", "a%.txt", 2)
      input.answer "no disco"
      review.annotate()
      read_diff("Staged", "a%.txt", 2)
      input.answer "no índice, corrigida"
      review.annotate()

      assert.same({ "", "", "no índice" }, input.defaults())
      local annotations = document.annotations()
      assert.equals(2, #annotations)
      local by_version = {}
      for _, written in ipairs(annotations) do
        by_version[written.version] = written
      end
      assert.equals("no índice, corrigida", by_version.index.text)
      assert.equals("dois staged", by_version.index.anchor)
      assert.equals("no disco", by_version.disk.text)
      assert.equals("um", by_version.disk.anchor)
    end)

    it("conta a anotação do working tree gravada sem versão como a do disco", function()
      local repo = repo_with_a_staged_change()

      open_in(repo.root)
      -- A anotação legada é plantada num documento que já existe, e é anotar
      -- alguma coisa que o faz existir.
      panel.focus("Unstaged", "a%.txt")
      input.answer "o arquivo todo"
      panel.feed "a"
      document.plant {
        path = "a.txt",
        mode = "worktree",
        line = 2,
        anchor = "um",
        text = "antiga, sem versão",
        at = "2026-01-01T00:00:00Z",
      }
      read_diff("Staged", "a%.txt", 2)
      input.answer "no índice"
      review.annotate()
      read_file("Unstaged", "a%.txt", 2)
      input.answer "antiga, corrigida"
      review.annotate()

      assert.same({ "", "", "antiga, sem versão" }, input.defaults())
      local on_lines = vim.tbl_filter(function(written) return written.line ~= nil end, document.annotations())
      assert.equals(2, #on_lines)
      local texts = vim.tbl_map(function(written) return written.version .. " " .. written.text end, on_lines)
      table.sort(texts)
      assert.same({ "disk antiga, corrigida", "index no índice" }, texts)
    end)
  end)

  describe("no diff de commit e de intervalo", function()
    it("anota a linha no lado de depois, o commit, com o sha como versão e a âncora lida dele", function()
      local repo = repo_with_a_commit_moved_on()
      local sha = vim.trim(repo:git { "rev-parse", "HEAD" })

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      read_diff("Mudanças", "a%.txt", 2)
      input.answer "no commit"
      review.annotate()

      assert.same({ "issue em a.txt:2: " }, input.prompts())
      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals("commit-" .. sha, annotations[1].mode)
      assert.equals(sha, annotations[1].version)
      assert.equals(2, annotations[1].line)
      assert.equals("dois no commit", annotations[1].anchor)
      assert.equals("no commit", annotations[1].text)
    end)

    it("anota o trecho no lado de depois do intervalo, que é o commit mais novo", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "um\ndois\ntrês\n", "primeiro")
      repo:commit_file("a.txt", "um\ndois do meio\ntrês\n", "segundo")
      repo:commit_file("a.txt", "um\ndois do fim\ntrês do fim\n", "terceiro")
      local oldest = vim.trim(repo:git { "rev-parse", "HEAD~1" })
      local newest = vim.trim(repo:git { "rev-parse", "HEAD" })

      open_in(repo.root)
      panel.feed "c"
      graph.choose_range("terceiro", "segundo")
      read_diff("Mudanças", "a%.txt", 1)
      input.answer "estas duas andam juntas"
      annotate_selection(2, 3)

      assert.same({ "issue em a.txt:2-3: " }, input.prompts())
      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals(("range-%s..%s"):format(oldest, newest), annotations[1].mode)
      assert.equals(newest, annotations[1].version)
      assert.same({ 2, 3 }, { annotations[1].line, annotations[1].end_line })
      assert.equals("dois do fim\ntrês do fim", annotations[1].anchor)
    end)
  end)

  describe("onde a anotação de linha é recusada", function()
    before_each(function() notify.install() end)

    ---Press the key that annotates where the cursor is, and assert it said no:
    ---nothing asked — the search that opened a rev asked before it —, nothing
    ---written, and the warning about why.
    ---@param said string a Lua pattern of the warning
    local function assert_refused(said)
      local asked_before = #confirm.prompts()
      input.answer "não tem onde prender isto"
      review.annotate()

      assert.equals(asked_before, #confirm.prompts())
      assert.same({}, input.prompts())
      assert.same({}, vim.tbl_filter(function(written) return written.line ~= nil end, document.annotations()))
      assert.matches(said, notify.last())
    end

    it("no lado de antes do diff de staged, que é o HEAD", function()
      local repo = repo_with_a_staged_change()

      open_in(repo.root)
      read_diff("Staged", "a%.txt", 2, "left")

      assert_refused "lado de antes"
    end)

    it("no lado de antes do diff de unstaged, que é o índice", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_diff("Unstaged", "a%.txt", 2, "left")

      assert_refused "lado de antes"
    end)

    it("no lado de antes da comparação com outro rev, e não no arquivo ao lado dele", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      confirm.answer "main"
      panel.feed "E"
      local wins = diff.windows()
      vim.api.nvim_set_current_win(wins[1])
      vim.api.nvim_win_set_cursor(wins[1], { 1, 0 })
      assert_refused "lado de antes"

      confirm.answer_matching "^issue "
      vim.api.nvim_set_current_win(wins[2])
      vim.api.nvim_win_set_cursor(wins[2], { 2, 0 })
      input.answer "o arquivo aceita"
      review.annotate()
      assert.equals("disk", document.annotations()[1].version)
    end)

    it("no arquivo de hoje, aberto do diff de commit, apontando a volta ao diff", function()
      -- Um relatório de commit tem uma referência só, o commit (ADR-0011).
      local repo = repo_with_a_commit_moved_on()

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      read_diff("Mudanças", "a%.txt", 2)
      diff.feed "go"
      assert.equals(repo.root .. "/a.txt", vim.api.nvim_buf_get_name(0))

      assert_refused "<C%-o>"
    end)

    it("no arquivo de hoje, no intervalo", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "um\n", "primeiro")
      repo:commit_file("a.txt", "dois\n", "segundo")
      repo:commit_file("a.txt", "três\n", "terceiro")

      open_in(repo.root)
      panel.feed "c"
      graph.choose_range("terceiro", "segundo")
      read_diff("Mudanças", "a%.txt", 1)
      diff.feed "go"

      assert_refused "<C%-o>"
    end)

    it("nas três versões de um conflito", function()
      local repo = fixture.repo()
      repo:conflict "conflito.txt"

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "D"

      local wins = diff.windows()
      assert.equals(3, #wins)
      for _, win in ipairs(wins) do
        vim.api.nvim_set_current_win(win)
        assert_refused "arquivo em si"
      end
    end)

    it("na vista do arquivo em outro rev", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      confirm.answer "main"
      panel.feed "e"

      assert.is_true(diff.is_side(vim.api.nvim_buf_get_name(0)))
      assert_refused "arquivo em si"
    end)
  end)

  describe("na ajuda do diff", function()
    it("lista as teclas de anotar quando o lado da direita é o arquivo do revisor", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      diff.feed "g?"

      local keys = help.keys()
      assert.matches("^Anotar a linha", keys["<Leader>ga"])
      assert.matches("várias linhas", keys["<Leader>gA"])
    end)

    it("lista as teclas de anotar no diff de staged, cujo lado da direita é o índice", function()
      local repo = repo_with_a_change()
      repo:add "a.txt"

      open_in(repo.root)
      panel.focus("Staged", "a%.txt")
      panel.feed "<CR>"
      diff.feed "g?"

      local keys = help.keys()
      assert.matches("^Anotar a linha", keys["<Leader>ga"])
      assert.matches("várias linhas", keys["<Leader>gA"])
    end)

    it("lista as teclas de anotar no diff de commit, cujo lado da direita é o commit", function()
      local repo = repo_with_a_commit_moved_on()

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      panel.focus("Mudanças", "a%.txt")
      panel.feed "<CR>"
      diff.feed "g?"

      local keys = help.keys()
      assert.matches("^Anotar a linha", keys["<Leader>ga"])
      assert.matches("várias linhas", keys["<Leader>gA"])
    end)

    it("não oferece anotar nas três versões de um conflito", function()
      -- A anotação ali seria recusada, e uma tecla oferecida para ser recusada é
      -- pior que nenhuma.
      local repo = fixture.repo()
      repo:conflict "conflito.txt"

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "D"
      diff.feed "g?"

      local keys = help.keys()
      assert.is_not_nil(keys["<Leader>gv"])
      assert.is_nil(keys["<Leader>ga"])
      assert.is_nil(keys["<Leader>gA"])
    end)

    it("não toma para o diff as teclas de anotar, que são do editor inteiro", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"

      -- The two values `assert` hands back would both go into the call.
      local win = assert(diff.right(), "o diff não abriu")
      vim.api.nvim_set_current_win(win)
      -- A tecla que responde no arquivo do revisor continua sendo a global:
      -- `buffer` é 0 num mapeamento global e 1 num local, que é o que o diff
      -- poria por cima dela.
      for _, key in ipairs { "<Leader>ga", "<Leader>gA" } do
        local map = vim.fn.maparg(key, "n", false, true)
        assert.equals("Anotar", (map.desc or ""):match "^Anotar")
        assert.equals(0, map.buffer)
      end
    end)

    it("lista a tecla que está mapeada, também quando o revisor a troca", function()
      review.setup { mappings = { annotate_line = "<Leader>n", annotate_line_long = "<Leader>N" } }
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      diff.feed "g?"

      local keys = help.keys()
      assert.is_not_nil(keys["<Leader>n"])
      assert.is_nil(keys["<Leader>ga"])
      help.feed "q"
      -- A tecla antiga sai, nos dois modos: trocar é mover, e não somar.
      assert.equals("", vim.fn.maparg("<Leader>ga", "n"))
      assert.equals("", vim.fn.maparg("<Leader>ga", "x"))
      assert.is_not.equals("", vim.fn.maparg("<Leader>n", "n"))
      assert.is_not.equals("", vim.fn.maparg("<Leader>n", "x"))
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
      assert.equals("issue em a.txt:2", entry.title())
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
      assert.equals("issue em a.txt", entry.title())
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

  describe("tipo da anotação", function()
    ---The names the selector offered, in the order it offered them.
    ---@return string[]
    local function offered_names()
      return vim.tbl_map(function(item) return item:match "^(%S+) — " end, confirm.offered())
    end

    it("é escolhido num seletor antes do texto, com o nome e a instrução de cada tipo", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      confirm.answer_matching "^question "
      input.answer "por que mudou?"
      review.annotate()

      assert.same(
        { "issue", "refactor", "test", "revert", "question", "suggestion", "nitpick", "praise" },
        offered_names()
      )
      assert.matches("^issue — corrija", confirm.offered()[1])
      assert.matches("^question — responda", confirm.offered()[5])
      -- A entrada diz o tipo escolhido e o ponto, antes de o revisor escrever.
      assert.same({ "question em a.txt:2: " }, input.prompts())
      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals("question", annotations[1].type)
      assert.equals("por que mudou?", annotations[1].text)
    end)

    it("é escolhido também antes da entrada longa, que diz o tipo na borda", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 1)
      confirm.answer_matching "^praise "
      annotate_selection(1, 3, { long = true })

      assert.equals(1, #confirm.prompts())
      assert.matches("a%.txt:1%-3", confirm.prompts()[1])
      assert.equals("praise em a.txt:1-3", entry.title())
      entry.type "isto ficou bom"
      entry.save()

      assert.equals("praise", document.annotations()[1].type)
    end)

    it("vem com o tipo atual primeiro quando a anotação é editada, e pode ser trocado", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      confirm.answer_matching "^test "
      input.answer "falta teste"
      review.annotate()
      confirm.answer_matching "^question "
      input.answer "isto tem teste?"
      review.annotate()

      assert.same(
        { "test", "issue", "refactor", "revert", "question", "suggestion", "nitpick", "praise" },
        offered_names()
      )
      assert.same({ "test em a.txt:2: ", "question em a.txt:2: " }, input.prompts())
      assert.same({ "", "falta teste" }, input.defaults())
      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals("question", annotations[1].type)
      assert.equals("isto tem teste?", annotations[1].text)
    end)

    it("desiste da anotação nova quando o seletor é cancelado", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      confirm.answer(nil)
      input.answer "não chega a ser pedido"
      review.annotate()
      review.annotate { long = true }

      assert.same({}, input.prompts())
      assert.is_false(entry.is_open())
      assert.same({}, document.annotations())
    end)

    it("deixa a anotação editada como estava quando o seletor é cancelado", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      confirm.answer_matching "^nitpick "
      input.answer "espaço sobrando"
      review.annotate()
      confirm.answer(nil)
      input.answer "reescrita que não vai"
      review.annotate()

      assert.equals(1, #input.prompts())
      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals("nitpick", annotations[1].type)
      assert.equals("espaço sobrando", annotations[1].text)
    end)

    it("oferece os tipos da configuração: um nome novo no fim, um existente com a instrução trocada", function()
      review.setup {
        annotation_types = {
          { name = "security", instruction = "trate como falha de segurança." },
          { name = "question", instruction = "responda aqui, sem tocar no código." },
        },
      }
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      confirm.answer_matching "^security "
      input.answer "o segredo está no código"
      panel.feed "a"

      assert.same(
        { "issue", "refactor", "test", "revert", "question", "suggestion", "nitpick", "praise", "security" },
        offered_names()
      )
      assert.equals("question — responda aqui, sem tocar no código.", confirm.offered()[5])
      assert.equals("security — trate como falha de segurança.", confirm.offered()[9])
      assert.equals("security", document.annotations()[1].type)
    end)

    it("recusa na configuração um tipo sem nome ou sem instrução", function()
      assert.has_error(function() review.setup { annotation_types = { { name = "security" } } } end)
      assert.has_error(function() review.setup { annotation_types = { { instruction = "sem nome." } } } end)
      assert.has_error(function() review.setup { annotation_types = { { name = "", instruction = "vazio." } } } end)
    end)
  end)

  describe("tipo da anotação pelo prefixo", function()
    before_each(function() review.setup { annotation_type_entry = "prefix" } end)

    it("não mostra seletor, e o prefixo define o tipo e sai do texto", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      input.answer "question: por que isto?"
      review.annotate()

      assert.same({}, confirm.prompts())
      assert.same({ "a.txt:2: " }, input.prompts())
      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals("question", annotations[1].type)
      assert.equals("por que isto?", annotations[1].text)
    end)

    it("grava issue com o texto intacto sem prefixo, com prefixo desconhecido ou abreviado", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 1)
      input.answer "sem prefixo nenhum"
      review.annotate()
      vim.api.nvim_win_set_cursor(0, { 2, 0 })
      input.answer "nota: isto é uma frase minha"
      review.annotate()
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      input.answer "quest: não é abreviação de tipo"
      review.annotate()

      local annotations = document.annotations()
      assert.same({ "issue", "issue", "issue" }, vim.tbl_map(function(written) return written.type end, annotations))
      assert.same(
        { "sem prefixo nenhum", "nota: isto é uma frase minha", "quest: não é abreviação de tipo" },
        vim.tbl_map(function(written) return written.text end, annotations)
      )
    end)

    it("edita com o prefixo do tipo na frente, e trocar o prefixo troca o tipo", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      input.answer "question: por que isto?"
      review.annotate()
      input.answer "test: falta o teste disto"
      review.annotate()
      input.answer "agora é só um problema"
      review.annotate()
      input.answer "e continua sendo"
      review.annotate()

      -- O `issue` não vem com prefixo: é o que o texto sem prefixo já é.
      assert.same(
        { "", "question: por que isto?", "test: falta o teste disto", "agora é só um problema" },
        input.defaults()
      )
      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals("issue", annotations[1].type)
      assert.equals("e continua sendo", annotations[1].text)
    end)

    it("vale na entrada longa, que vem preenchida com o prefixo", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      input.answer "praise: ficou bom"
      review.annotate()
      review.annotate { long = true }

      assert.same({}, confirm.prompts())
      assert.equals("a.txt:2", entry.title())
      assert.same({ "praise: ficou bom" }, entry.lines())
      entry.feed "ggdG"
      entry.type "refactor: extraia\numa função"
      entry.save()

      local annotations = document.annotations()
      assert.equals("refactor", annotations[1].type)
      assert.equals("extraia\numa função", annotations[1].text)
    end)

    it("põe issue na frente do issue cujo texto começa com o nome de um tipo", function()
      -- Escrito no seletor, `question: …` é o texto de um issue. Editado sem o
      -- prefixo dele, voltaria gravado como question.
      review.setup {}
      local repo = repo_with_a_change()

      open_in(repo.root)
      read_file("Unstaged", "a%.txt", 2)
      input.answer "question: é o texto, não o tipo"
      review.annotate()
      review.setup { annotation_type_entry = "prefix" }
      input.answer "issue: question: é o texto, não o tipo"
      review.annotate()

      -- O mesmo vale para o texto que começa com o nome do próprio issue: sem
      -- outro prefixo na frente, gravar sem mexer levaria o `issue: ` embora.
      review.setup {}
      vim.api.nvim_win_set_cursor(0, { 3, 0 })
      input.answer "issue: também é o texto"
      review.annotate()
      review.setup { annotation_type_entry = "prefix" }
      input.answer "issue: issue: também é o texto"
      review.annotate()

      assert.same({
        "",
        "issue: question: é o texto, não o tipo",
        "",
        "issue: issue: também é o texto",
      }, input.defaults())
      local annotations = document.annotations()
      assert.same({ "issue", "issue" }, vim.tbl_map(function(written) return written.type end, annotations))
      assert.same(
        { "question: é o texto, não o tipo", "issue: também é o texto" },
        vim.tbl_map(function(written) return written.text end, annotations)
      )
    end)

    it("recusa na configuração uma entrada do tipo que não é select nem prefix", function()
      assert.has_error(function() review.setup { annotation_type_entry = "prefixo" } end)
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
