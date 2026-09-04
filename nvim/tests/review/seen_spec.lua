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

  describe("marcar e ir à próxima", function()
    it("v marca e deixa o cursor na linha onde ele estava", function()
      -- Desmarcar é feito olhando para o arquivo: a tecla que marca e desmarca
      -- não sai de cima dele, ou desfazer a marca esconderia o que foi desfeito.
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:commit_file("b.txt", "b v1\n")
      repo:write("a.txt", "a v2\n")
      repo:write("b.txt", "b v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      local line = panel.cursor()
      panel.feed "v"

      assert.equals(line, panel.cursor())
      assert.equals(1, panel.section_count "Vistos")
    end)

    it("marca o arquivo e leva o cursor à próxima não vista", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:commit_file("b.txt", "b v1\n")
      repo:write("a.txt", "a v2\n")
      repo:write("b.txt", "b v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<Space>"

      assert.equals("  M  b.txt", panel.current())
      assert.same({ "M  b.txt" }, panel.section "Unstaged")
      assert.equals(1, panel.section_count "Vistos")
    end)

    it("desce na ordem renderizada, atravessando as seções", function()
      -- A próxima é a próxima da lista que está na tela — Conflitos, Staged,
      -- Unstaged, Untracked —, e não a próxima da ordem em que o git respondeu.
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:commit_file("b.txt", "b v1\n")
      repo:write("b.txt", "b v2\n")
      repo:add "b.txt"
      repo:write("a.txt", "a v2\n")
      repo:write("z.txt", "z\n")

      open_in(repo.root)
      panel.focus("Staged", "b%.txt")
      panel.feed "<Space>"
      assert.equals("  M  a.txt", panel.current())

      panel.feed "<Space>"
      assert.equals("  ?  z.txt", panel.current())
    end)

    it("pula os outros arquivos de mesmo conteúdo, que a marca levou junto", function()
      -- A marca é do conteúdo e não do caminho (ADR-0002): marcar um arquivo
      -- marca todos os que têm o mesmo texto, e nenhum deles é um arquivo que
      -- ficou por ler.
      local repo = fixture.repo()
      repo:write("outro.txt", "idêntico\n")
      repo:write("um.txt", "idêntico\n")
      repo:write("z.txt", "z\n")

      open_in(repo.root)
      panel.focus("Untracked", "outro%.txt")
      panel.feed "<Space>"

      assert.equals("  ?  z.txt", panel.current())
      assert.equals(2, panel.section_count "Vistos")
    end)

    it("pula o mesmo conteúdo também quando os vistos ficam esmaecidos no lugar", function()
      -- Na apresentação em que nada sai do lugar, o arquivo levado junto pela
      -- marca continua na linha dele, esmaecido: a tecla tem que passar por ele
      -- como passa pela seção Vistos.
      review.setup { seen_display = "dimmed" }
      local repo = fixture.repo()
      repo:write("outro.txt", "idêntico\n")
      repo:write("um.txt", "idêntico\n")
      repo:write("z.txt", "z\n")

      open_in(repo.root)
      panel.focus("Untracked", "outro%.txt")
      panel.feed "<Space>"

      assert.equals("  ?  z.txt", panel.current())
      assert.same({ "?  outro.txt", "?  um.txt" }, panel.dimmed())
    end)

    it("pula a seção Vistos ao procurar a próxima", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:commit_file("b.txt", "b v1\n")
      repo:commit_file("c.txt", "c v1\n")
      repo:write("a.txt", "a v2\n")
      repo:write("b.txt", "b v2\n")
      repo:write("c.txt", "c v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "c%.txt")
      panel.feed "v"
      panel.focus_section "Vistos"
      panel.feed "<CR>"
      assert.same({ "M  c.txt" }, panel.section "Vistos")

      panel.focus("Unstaged", "b%.txt")
      panel.feed "<Space>"

      assert.equals("Revisão · main · 2/3 vistos", panel.current())
    end)

    it("não dá a volta: sem próxima abaixo, o cursor vai ao cabeçalho", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:commit_file("b.txt", "b v1\n")
      repo:write("a.txt", "a v2\n")
      repo:write("b.txt", "b v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "b%.txt")
      panel.feed "<Space>"

      -- a.txt está acima e continua por ler: a tecla não volta para ela.
      assert.equals("Revisão · main · 1/2 vistos", panel.current())
      assert.same({ "M  a.txt" }, panel.section "Unstaged")
    end)

    it("espera, e não engole os comandos de Leader de quem tem o espaço como Leader", function()
      -- A tecla é local ao buffer do painel e os comandos de Leader são globais:
      -- uma tecla que agisse na hora tiraria todos eles do revisor justamente
      -- onde ele mais fica, que é na lista. O que se lê é a tabela de
      -- mapeamentos do próprio editor, que é quem espera ou não espera; que a
      -- espera de fato acontece é verificado à mão, num editor com terminal.
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:write("a.txt", "a v2\n")

      local leader = vim.g.mapleader
      vim.g.mapleader = " "
      open_in(repo.root)
      vim.g.mapleader = leader

      local waits = {}
      local win = panel.win()
      assert.is_not_nil(win)
      for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(vim.api.nvim_win_get_buf(win), "n")) do
        waits[mapping.lhs] = mapping.nowait == 0
      end

      assert.is_true(waits[" "])
      -- E só ela: as outras teclas do painel continuam agindo na hora.
      assert.is_false(waits["q"])
    end)

    it("em cima de um arquivo já visto, desmarca e não avança", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:commit_file("b.txt", "b v1\n")
      repo:commit_file("c.txt", "c v1\n")
      repo:write("a.txt", "a v2\n")
      repo:write("b.txt", "b v2\n")
      repo:write("c.txt", "c v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "v"
      panel.focus("Unstaged", "b%.txt")
      panel.feed "v"
      panel.focus_section "Vistos"
      panel.feed "<CR>"

      panel.focus("Vistos", "a%.txt")
      local line = panel.cursor()
      panel.feed "<Space>"

      assert.equals(line, panel.cursor())
      assert.equals("Revisão · main · 1/3 vistos", panel.lines()[1])
      assert.same({ "M  a.txt", "M  c.txt" }, panel.section "Unstaged")
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

  describe("a linha do próximo passo", function()
    it("com tudo visto, diz para commitar no neogit", function()
      -- O fim da revisão é uma linha que diz o próximo passo, e não um estado
      -- novo: nada é iniciado, nada é finalizado (ADR-0002).
      local repo = fixture.repo()
      repo:write("um.txt", "um\n")
      repo:write("dois.txt", "dois\n")

      open_in(repo.root)
      assert.is_nil(panel.line_matching "neogit")

      panel.focus("Untracked", "um%.txt")
      panel.feed "v"
      assert.is_nil(panel.line_matching "neogit")

      panel.focus("Untracked", "dois%.txt")
      panel.feed "v"

      assert.is_not_nil(panel.line_matching "neogit: <Leader>gnc")
      assert.is_nil(panel.line_matching "Nenhuma mudança")
    end)

    it("não aparece onde não há mudança nenhuma para ver", function()
      -- Sem nada na lista não há revisão de que falar, e a mensagem de sempre é
      -- o que o painel tem a dizer.
      local repo = fixture.repo()

      open_in(repo.root)

      assert.is_not_nil(panel.line_matching "Nenhuma mudança")
      assert.is_nil(panel.line_matching "neogit")
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
