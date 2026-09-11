local confirm = require "tests.helpers.confirm"
local diff = require "tests.helpers.diff"
local document = require "tests.helpers.document"
local editor = require "tests.helpers.editor"
local entry = require "tests.helpers.entry"
local fixture = require "tests.helpers.fixture"
local help = require "tests.helpers.help"
local input = require "tests.helpers.input"
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

    it("não oferece anotar num diff em que os dois lados são versões", function()
      -- No staged os dois lados são o HEAD e o índice: a anotação ali seria
      -- recusada, e uma tecla oferecida para ser recusada é pior que nenhuma.
      local repo = repo_with_a_change()
      repo:add "a.txt"

      open_in(repo.root)
      panel.focus("Staged", "a%.txt")
      panel.feed "<CR>"
      diff.feed "g?"

      local keys = help.keys()
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
