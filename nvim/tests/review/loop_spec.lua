local diff = require "tests.helpers.diff"
local fixture = require "tests.helpers.fixture"
local help = require "tests.helpers.help"
local notify = require "tests.helpers.notify"
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

---The buffer local mappings a key has, which is what the editor kept on the
---reviewer's own file after the diff came and went.
---@param bufnr integer
---@param lhs string
---@return table[]
local function mappings(bufnr, lhs)
  return vim.tbl_filter(function(map) return map.lhs == lhs end, vim.api.nvim_buf_get_keymap(bufnr, "n"))
end

---A repository with three changed files, which is a list to walk.
---@return table repo
local function repo_with_three_changes()
  local repo = fixture.repo()
  repo:commit_file("a.txt", "a v1\n")
  repo:commit_file("b.txt", "b v1\n")
  repo:commit_file("c.txt", "c v1\n")
  repo:write("a.txt", "a v2\n")
  repo:write("b.txt", "b v2\n")
  repo:write("c.txt", "c v2\n")
  return repo
end

---The file every repository below is made of: twelve lines with the second and
---the tenth changed, which is a file with two changes to walk between.
---@param mark string what tells this file's version from the others'
---@return string original
---@return string changed
local function two_changes(mark)
  local lines = {}
  for number = 1, 12 do
    lines[number] = ("%s %d"):format(mark, number)
  end
  local original = table.concat(lines, "\n") .. "\n"
  lines[2], lines[10] = "mudou a segunda", "mudou a décima"
  return original, table.concat(lines, "\n") .. "\n"
end

---A repository whose files have two changes each: a list to walk, and inside
---each line of it a file to walk.
---@param names string[]
---@return table repo
local function repo_with_changes_inside(names)
  local repo = fixture.repo()
  for _, name in ipairs(names) do
    local original, changed = two_changes(name)
    repo:commit_file(name, original)
    repo:write(name, changed)
  end
  return repo
end

describe("o laço de dentro do diff", function()
  before_each(function()
    review.setup {}
    fixture.data_dir()
    notify.install()
  end)

  after_each(function()
    notify.restore()
    review.close()
    -- Back to the first tabpage before dropping the others: `tabonly!` keeps
    -- the current one, and keeping a tabpage of the test would carry its panel
    -- — and the state of its sections — into the next one.
    vim.cmd "tabfirst"
    vim.cmd "tabonly!"
    vim.cmd.cd(vim.fn.fnameescape(config_root))
    fixture.cleanup()
  end)

  describe("]f e [f", function()
    it("abrem a próxima e a anterior sem passar pela lista", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "b%.txt")
      panel.feed "<CR>"

      diff.feed "]f"
      assert.equals("c.txt", diff.reading())

      diff.feed "[f"
      assert.equals("b.txt", diff.reading())
    end)

    it("movem o cursor do painel e deixam o foco no diff", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"

      diff.feed "]f"

      assert.equals("  M  b.txt", panel.current())
      assert.is_true(diff.focused())
    end)

    it("pulam o arquivo já visto", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "b%.txt")
      panel.feed "v"
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"

      diff.feed "]f"

      assert.equals("c.txt", diff.reading())
    end)

    it("não fazem nada numa janela que não é lado deste diff", function()
      -- As teclas são locais ao buffer, e o do lado do working tree é o arquivo
      -- do revisor: elas existem em toda janela que mostre esse arquivo,
      -- inclusive em outra aba. Fora do diff não há revisão para andar, como
      -- não há diff para fechar.
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      local line = panel.cursor()
      local bufnr = vim.api.nvim_win_get_buf(diff.windows()[2])

      -- Numa aba que revisa outro repositório: o buffer é o mesmo, a revisão
      -- não é. Andar aqui moveria a revisão que o revisor não está lendo.
      local other = fixture.repo()
      other:commit_file("y.txt", "y v1\n")
      other:commit_file("z.txt", "z v1\n")
      other:write("y.txt", "y v2\n")
      other:write("z.txt", "z v2\n")
      open_in(other.root)
      panel.focus("Unstaged", "y%.txt")
      local other_line = panel.cursor()

      vim.cmd "split"
      vim.api.nvim_win_set_buf(0, bufnr)
      local elsewhere = vim.api.nvim_get_current_win()
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("]f", true, false, true), "x", false)

      assert.equals(elsewhere, vim.api.nvim_get_current_win())
      assert.equals(other_line, panel.cursor())
      assert.same({}, diff.windows())

      vim.cmd "tabprevious"
      assert.equals("a.txt", diff.reading())
      assert.equals(line, panel.cursor())
    end)

    it("não dão a volta: no fim da lista o diff fica onde está", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "c%.txt")
      panel.feed "<CR>"
      local line = panel.cursor()

      diff.feed "]f"

      assert.equals("c.txt", diff.reading())
      assert.equals(line, panel.cursor())
    end)
  end)

  describe("]F e [F", function()
    it("andam por todos os arquivos, vistos inclusive", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "b%.txt")
      panel.feed "v"
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"

      -- b.txt está visto e por isso fora do caminho de `]f`; é por `]F` que se
      -- chega nele.
      diff.feed "]F"

      assert.equals("b.txt", diff.reading())
      assert.is_true(diff.focused())
    end)

    it("[F é como se volta a um arquivo já visto", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<Space>"
      panel.feed "<CR>"
      assert.equals("b.txt", diff.reading())

      diff.feed "[F"

      assert.equals("a.txt", diff.reading())
      assert.equals("  M  a.txt", panel.current())
    end)

    it("não dão a volta pelo cabeçalho, onde o fim da revisão deixa o cursor", function()
      -- Marcar o último arquivo leva o cursor do painel ao cabeçalho, que é
      -- onde está escrito `N/N vistos`. Dali a revisão não está em arquivo
      -- nenhum, e a tecla não a recomeça pelo primeiro.
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "v"
      panel.focus("Unstaged", "b%.txt")
      panel.feed "v"
      panel.focus("Unstaged", "c%.txt")
      panel.feed "<CR>"
      panel.feed "<Space>"
      assert.equals("Revisão · main · 3/3 vistos", panel.current())

      diff.feed "]F"

      assert.equals("c.txt", diff.reading())
      assert.equals("Revisão · main · 3/3 vistos", panel.current())
    end)
  end)

  describe("]c e [c", function()
    it("andam pelas mudanças de dentro do arquivo, sem trocar de arquivo", function()
      local repo = repo_with_changes_inside { "a.txt", "b.txt" }

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      diff.to_top()

      diff.feed "]c"
      assert.equals(2, diff.cursor())

      diff.feed "]c"
      assert.equals(10, diff.cursor())

      diff.feed "[c"
      assert.equals(2, diff.cursor())

      assert.equals("a.txt", diff.reading())
    end)

    it("na última mudança avisam que é a última, em vez de trocar de arquivo", function()
      local repo = repo_with_changes_inside { "a.txt", "b.txt" }

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      diff.to_top()
      diff.feed "]c"
      diff.feed "]c"

      diff.feed "]c"

      assert.equals("review: última mudança deste arquivo; ]c de novo abre o próximo por ler.", notify.last())
      assert.equals("a.txt", diff.reading())
      assert.equals(10, diff.cursor())
    end)

    it("apertada de novo na última, abrem o próximo por ler na primeira mudança dele", function()
      local repo = repo_with_changes_inside { "a.txt", "b.txt" }

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      diff.to_top()
      diff.feed "]c"
      diff.feed "]c"
      diff.feed "]c"

      diff.feed "]c"

      assert.equals("b.txt", diff.reading())
      assert.equals(2, diff.cursor())
      -- Como o `]f`: quem andou foi a revisão, e o cursor do painel é onde ela
      -- está (ADR-0009).
      assert.equals("  M  b.txt", panel.current())
      assert.is_true(diff.focused())
    end)

    it("[c volta para o arquivo anterior, na última mudança dele", function()
      local repo = repo_with_changes_inside { "a.txt", "b.txt" }

      open_in(repo.root)
      panel.focus("Unstaged", "b%.txt")
      panel.feed "<CR>"
      diff.to_top()
      diff.feed "]c"

      diff.feed "[c"
      assert.equals("review: primeira mudança deste arquivo; [c de novo abre o anterior por ler.", notify.last())
      assert.equals("b.txt", diff.reading())

      diff.feed "[c"

      assert.equals("a.txt", diff.reading())
      assert.equals(10, diff.cursor())
    end)

    it("atravessam para o próximo por ler, e não para o próximo da lista", function()
      local repo = repo_with_changes_inside { "a.txt", "b.txt", "c.txt" }

      open_in(repo.root)
      panel.focus("Unstaged", "b%.txt")
      panel.feed "v"
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      diff.to_top()
      diff.feed "]c"
      diff.feed "]c"
      diff.feed "]c"

      diff.feed "]c"

      assert.equals("c.txt", diff.reading())
    end)

    it("dizem que não há próximo quando a revisão acaba ali", function()
      local repo = repo_with_changes_inside { "a.txt" }

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      diff.to_top()
      diff.feed "]c"
      diff.feed "]c"
      diff.feed "]c"

      diff.feed "]c"

      assert.equals("review: não há próximo arquivo por ler.", notify.last())
      assert.equals("a.txt", diff.reading())
      assert.equals(10, diff.cursor())
    end)

    it("uma volta ao meio do arquivo desarma a travessia", function()
      -- Avisar é do fim: quem voltou para o meio e chegou de novo ao fim é
      -- avisado de novo, em vez de sair do arquivo na primeira tecla.
      local repo = repo_with_changes_inside { "a.txt", "b.txt" }

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      diff.to_top()
      diff.feed "]c"
      diff.feed "]c"
      diff.feed "]c"

      diff.feed "[c"
      diff.feed "]c"
      diff.feed "]c"

      assert.equals("review: última mudança deste arquivo; ]c de novo abre o próximo por ler.", notify.last())
      assert.equals("a.txt", diff.reading())
    end)
  end)

  describe("com a lista fechada", function()
    it("]f e [f andam pela revisão do mesmo jeito", function()
      -- Fechar a lista é o que o revisor faz para ler o arquivo com a tela
      -- inteira. A revisão continua a mesma, e o que diz onde ela está é o
      -- diff que está na tela.
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "b%.txt")
      panel.feed "<CR>"
      review.close()
      assert.is_false(panel.is_open())

      diff.feed "]f"
      assert.equals("c.txt", diff.reading())
      assert.is_false(panel.is_open())

      diff.feed "[f"
      assert.equals("b.txt", diff.reading())
    end)

    it("]c atravessa para o próximo arquivo com a lista fechada", function()
      local repo = repo_with_changes_inside { "a.txt", "b.txt" }

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      review.close()
      diff.to_top()
      diff.feed "]c"
      diff.feed "]c"
      diff.feed "]c"

      diff.feed "]c"

      assert.equals("b.txt", diff.reading())
      assert.equals(2, diff.cursor())
    end)

    it("reabrir o painel leva o cursor para onde a revisão chegou", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      review.close()
      diff.feed "]f"
      diff.feed "]f"

      review.open()

      assert.equals("  M  c.txt", panel.current())
    end)

    it("o fim da lista continua calado, e o diff fica onde está", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "c%.txt")
      panel.feed "<CR>"
      review.close()

      diff.feed "]f"

      assert.same({}, notify.messages())
      assert.equals("c.txt", diff.reading())
    end)

    it("sem revisão nenhuma na aba, a tecla diz isso", function()
      -- O buffer do lado do working tree é o arquivo do revisor, e a tecla
      -- está nele em qualquer aba que o mostre. Numa aba que nunca teve
      -- painel não há revisão para andar.
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"

      vim.cmd "tabnew"
      assert.is_false(require("review.panel").step { direction = 1, unseen = true })
      assert.equals("review: não há revisão nesta aba; abra o painel para começar uma.", notify.last())
    end)

    it("com a lista na tela, o fim dela continua calado", function()
      -- Ali a cursorline do painel é a resposta, e ela está ao lado do diff.
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "c%.txt")
      panel.feed "<CR>"

      diff.feed "]f"

      assert.same({}, notify.messages())
      assert.equals("c.txt", diff.reading())
    end)
  end)

  describe("a ajuda do diff", function()
    it("lista as teclas do laço com o que elas fazem", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      diff.feed "g?"

      local keys = help.keys()
      assert.matches("^Ir para a próxima mudança", keys["]c"])
      assert.matches("^Ir para a mudança anterior", keys["[c"])
      assert.matches("próxima não vista", keys["]f"])
      assert.matches("não vista anterior", keys["[f"])
      assert.matches("próximo arquivo", keys["]F"])
      assert.matches("arquivo anterior", keys["[F"])
    end)
  end)

  describe("o Leader gv", function()
    it("marca o que está sendo lido e abre o diff da próxima não vista", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"

      review.seen_and_next()

      assert.equals("b.txt", diff.reading())
      assert.is_true(diff.focused())
      assert.same({ "M  b.txt", "M  c.txt" }, panel.section "Unstaged")
      assert.equals(1, panel.section_count "Vistos")
    end)

    it("age sobre a entrada do cursor do painel, e não sobre o arquivo na tela", function()
      -- O mesmo arquivo com mudança staged e unstaged está em duas linhas da
      -- lista, e são duas revisões diferentes dele. Quem diz qual delas está
      -- sendo lida é o cursor do painel (ADR-0009).
      local repo = fixture.repo()
      repo:commit_file("a.txt", "no head\n")
      repo:write("a.txt", "no indice\n")
      repo:add "a.txt"
      repo:write("a.txt", "no working tree\n")

      open_in(repo.root)
      panel.focus("Staged", "a%.txt")
      panel.feed "<CR>"

      review.seen_and_next()

      assert.same({ "M  a.txt" }, panel.section "Unstaged")
      assert.equals(1, panel.section_count "Vistos")
      -- A entrada aberta é a de unstaged: o índice contra o disco.
      assert.same({ { "no indice" }, { "no working tree" } }, diff.sides())
    end)

    it("sem próxima, leva o cursor do painel ao cabeçalho", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "v"
      panel.focus("Unstaged", "b%.txt")
      panel.feed "v"
      panel.focus("Unstaged", "c%.txt")
      panel.feed "<CR>"

      review.seen_and_next()

      assert.equals("Revisão · main · 3/3 vistos", panel.current())
      -- O que estava sendo lido continua na tela: não há próxima para abrir.
      assert.equals("c.txt", diff.reading())
    end)

    it("em cima de um arquivo já visto, desmarca e não abre nada", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<Space>"
      panel.feed "<CR>"
      assert.equals("b.txt", diff.reading())
      panel.focus_section "Vistos"
      panel.feed "<CR>"
      panel.focus("Vistos", "a%.txt")

      review.seen_and_next()

      assert.equals("b.txt", diff.reading())
      assert.equals("Revisão · main · 0/3 vistos", panel.lines()[1])
    end)
  end)

  describe("as teclas no arquivo do revisor", function()
    it("não tira do arquivo a tecla que outro pôs nele enquanto o diff estava aberto", function()
      -- O lado do working tree é o buffer do arquivo, e `]f` é uma tecla que o
      -- editor escreve nele a cada `FileType` — um `:edit` do arquivo redispara
      -- isso por baixo do diff já montado. O que o diff tira ao sair é o que ele
      -- pôs, e não o que apareceu depois.
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      local bufnr = vim.api.nvim_win_get_buf(diff.windows()[2])
      vim.keymap.set("n", "]f", "<Cmd>echo 'de outro'<CR>", { buffer = bufnr, desc = "de outro" })

      diff.feed "q"

      local left = mappings(bufnr, "]f")
      assert.equals(1, #left)
      assert.equals("de outro", left[1].desc)
    end)

    it("não devolve ao arquivo uma tecla do próprio diff", function()
      -- Nada impede o revisor de configurar duas teclas do diff no mesmo lhs. O
      -- que não pode acontecer é a segunda ler o mapeamento que a primeira
      -- acabou de escrever e devolvê-lo ao arquivo como se fosse dele: o
      -- arquivo ficaria com uma tecla nossa para sempre.
      review.setup { mappings = { next_file = "q" } }
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      local bufnr = vim.api.nvim_win_get_buf(diff.windows()[2])

      panel.focus("Unstaged", "b%.txt")
      panel.feed "<CR>"

      assert.same({}, mappings(bufnr, "q"))
    end)
  end)

  describe("o cursor do painel é a posição da revisão", function()
    it("a tecla da lista age sobre o que o diff andou até", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      diff.feed "]f"
      diff.feed "]f"

      -- Sem tocar no cursor da lista: quem o moveu foi o diff.
      panel.feed "v"

      assert.same({ "M  a.txt", "M  b.txt" }, panel.section "Unstaged")
      assert.equals(1, panel.section_count "Vistos")
    end)
  end)
end)
