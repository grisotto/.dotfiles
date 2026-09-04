local diff = require "tests.helpers.diff"
local fixture = require "tests.helpers.fixture"
local menu = require "tests.helpers.menu"
local panel = require "tests.helpers.panel"
local review = require "review"

local config_root = vim.fn.getcwd()

---How long a test waits for the preview to be drawn. The preview follows the
---cursor after a pause — long enough that a `j` held down the list does not
---draw a diff per line — so what is on the screen is read after waiting for it.
local DRAWING_MS = 2000

---How long a test waits before saying that nothing was drawn: more than the
---pause the preview takes, so that a diff on its way would have arrived.
local SETTLED_MS = 400

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

---The file the diff beside the panel is of, or nil when there is no diff there.
---@return string|nil
local function drawn()
  local names = diff.names()
  if #names == 0 then return nil end
  return vim.fn.fnamemodify(names[#names], ":t")
end

---What the preview drew, once it has drawn it.
---@param path string the file it is expected to be showing
---@return string|nil what it is showing
local function previewing(path)
  vim.wait(DRAWING_MS, function() return drawn() == path end, 10)
  return drawn()
end

---What is beside the panel after the preview has had time to draw, which is how
---a test says that nothing was drawn.
---@return string|nil
local function settled()
  vim.wait(SETTLED_MS)
  return drawn()
end

---Walk the list to an entry the way the reviewer does: in the panel, with the
---editor told that the cursor moved.
---@param section string
---@param pattern string a Lua pattern
local function sweep_to(section, pattern)
  local win = assert(panel.win(), "o painel não está aberto")
  vim.api.nvim_set_current_win(win)
  panel.focus(section, pattern)
  panel.cursor_moved()
end

---The git processes that read the content of a version, which is what a diff
---costs to draw: one per side that comes out of the repository.
---@param calls fun(): string[]
---@return string[]
local function git_shows(calls)
  return vim.tbl_filter(function(call) return call:match "^show " ~= nil end, calls())
end

---A repository with three changed files, which is a list to sweep.
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

describe("o preview", function()
  before_each(function()
    review.setup {}
    fixture.data_dir()
  end)

  after_each(function()
    review.close()
    -- Back to the first tabpage before dropping the others: `tabonly!` keeps
    -- the current one, and keeping a tabpage of the test would carry its panel
    -- — and whether the preview was on in it — into the next one.
    vim.cmd "tabfirst"
    vim.cmd "tabonly!"
    vim.cmd.cd(vim.fn.fnameescape(config_root))
    fixture.cleanup()
  end)

  describe("a tecla p", function()
    it("liga o preview e desenha o diff da linha em que o cursor já está", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "b%.txt")
      panel.feed "p"

      assert.equals("b.txt", previewing "b.txt")
    end)

    it("desliga o preview, e o que estava na tela fica", function()
      -- Desligar é o revisor tendo achado o arquivo que procurava varrendo:
      -- derrubar o diff seria tirar da tela justamente o que ele acabou de
      -- achar.
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "p"
      sweep_to("Unstaged", "b%.txt")
      assert.equals("b.txt", previewing "b.txt")

      panel.feed "p"
      sweep_to("Unstaged", "c%.txt")

      assert.equals("b.txt", settled())
    end)

    it("liga de novo na mesma linha, que é onde o revisor voltou a varrer", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "p"
      assert.equals("a.txt", previewing "a.txt")

      -- Desligado, e com outra coisa na janela ao lado: o arquivo em si, que é
      -- o que a tecla de abrir põe lá.
      panel.feed "p"
      panel.focus("Unstaged", "a%.txt")
      panel.feed "o"
      assert.is_nil(drawn())

      panel.feed "p"

      assert.equals("a.txt", previewing "a.txt")
    end)

    it("é a tecla que o revisor configurou", function()
      review.setup { mappings = { preview = "P" } }
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "P"

      assert.equals("a.txt", previewing "a.txt")
    end)
  end)

  describe("o padrão", function()
    it("vem desligado, e andar pela lista não desenha nada", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      sweep_to("Unstaged", "a%.txt")

      assert.is_nil(settled())
    end)

    it("vem da opção preview, e com ela ligada o painel já abre varrendo", function()
      review.setup { preview = true }
      local repo = repo_with_three_changes()

      open_in(repo.root)
      sweep_to("Unstaged", "b%.txt")

      assert.equals("b.txt", previewing "b.txt")
    end)

    it("recusa uma opção que não é booleana, em vez de ler como ligada", function()
      assert.has_error(function() review.setup { preview = "sim" } end)
    end)
  end)

  describe("com o preview ligado", function()
    it("mover o cursor desenha o diff da entrada, sem tirar o foco da lista", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "p"
      assert.equals("a.txt", previewing "a.txt")

      panel.move "j"

      assert.equals("b.txt", previewing "b.txt")
      assert.equals(panel.win(), vim.api.nvim_get_current_win())
      assert.is_false(diff.focused())
    end)

    it("desenha as duas versões que a linha compara, como a tecla de abrir", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "no head\n")
      repo:write("a.txt", "no working tree\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "p"
      previewing "a.txt"

      assert.same({ { "no head" }, { "no working tree" } }, diff.sides())
    end)

    it("numa linha que não é arquivo, o que está ao lado fica", function()
      -- Passar pelo cabeçalho de uma seção a caminho da próxima não é pedir que
      -- o diff saia da tela.
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "p"
      assert.equals("a.txt", previewing "a.txt")

      panel.focus_header()
      panel.cursor_moved()

      assert.equals("a.txt", settled())
    end)

    it("o <CR> leva o revisor para dentro do diff que ele já está lendo", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "p"
      assert.equals("a.txt", previewing "a.txt")

      panel.feed "<CR>"

      assert.equals("a.txt", drawn())
      assert.is_true(diff.focused())
    end)
  end)

  describe("não redesenha o que já está na tela", function()
    it("o cursor andando dentro da mesma linha não custa nenhum git show", function()
      -- Cada desenho custa ler do git a versão de cada lado e redesenhar a
      -- tela. Andar dentro da linha — ou a lista sendo redesenhada sob um cursor
      -- que não saiu dela — não muda a entrada sob o cursor, e não é nada para
      -- desenhar de novo.
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "p"
      assert.equals("a.txt", previewing "a.txt")
      local calls = fixture.trace_git()

      panel.move "$"

      assert.equals("a.txt", settled())
      assert.same({}, git_shows(calls))
    end)

    it("desenha uma vez só quando o cursor passa por vários arquivos", function()
      -- O revisor descendo a lista passa pelos arquivos do caminho; o que ele
      -- está pedindo é aquele em que ele para. Uma linha unstaged tem um lado
      -- lido do git — o índice — e o outro é o arquivo no disco, então um
      -- desenho é um `git show`, e três seriam três.
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "p"
      assert.equals("a.txt", previewing "a.txt")
      local calls = fixture.trace_git()

      panel.move "j"
      panel.move "j"

      assert.equals("c.txt", previewing "c.txt")
      assert.equals(1, #git_shows(calls))
    end)
  end)

  describe("o que já foi aberto por outra tecla", function()
    it("volta a ser desenhado quando o diff dele saiu da tela", function()
      -- O que está ao lado da lista é pergunta para o diff, e não memória do
      -- painel: as teclas do laço abrem outro arquivo e o `q` derruba o que
      -- estava lá. Um painel que se lembrasse do que desenhou continuaria
      -- dizendo que o arquivo está na tela depois de ele ter saído, e recusaria
      -- justamente o arquivo a que o revisor voltou.
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "p"
      assert.equals("a.txt", previewing "a.txt")

      panel.feed "<CR>"
      diff.feed "]F"
      assert.equals("b.txt", drawn())
      diff.feed "q"
      assert.is_nil(drawn())

      sweep_to("Unstaged", "a%.txt")

      assert.equals("a.txt", previewing "a.txt")
    end)

    it("não é redesenhado ao religar o preview com ele ainda ao lado da lista", function()
      -- Desligar deixa o diff na tela, então religar na mesma linha não tem o
      -- que desenhar: o arquivo já está lá.
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "p"
      assert.equals("a.txt", previewing "a.txt")
      local calls = fixture.trace_git()

      panel.feed "p"
      panel.feed "p"

      assert.equals("a.txt", settled())
      assert.same({}, git_shows(calls))
    end)
  end)

  describe("fora da janela do painel", function()
    it("uma tecla apertada durante a pausa não perde o revisor para o preview", function()
      -- A pausa do preview é tempo em que o revisor continua digitando: a tecla
      -- que abre o arquivo, logo depois do `j`, o leva para dentro do arquivo, e
      -- um preview chegando atrasado montaria um diff por cima — derrubando as
      -- janelas em que o revisor acabou de entrar para devolvê-lo à lista de
      -- onde ele saiu.
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "p"
      assert.equals("a.txt", previewing "a.txt")

      panel.move "j"
      panel.feed "o"
      local reading = vim.api.nvim_get_current_win()

      assert.is_nil(settled())
      assert.equals(reading, vim.api.nvim_get_current_win())
      assert.matches("b%.txt$", vim.api.nvim_buf_get_name(0))
    end)

    it("não desenha nada quando o cursor da lista é movido de outro lugar", function()
      -- As teclas do laço movem o cursor do painel de dentro do diff (ADR-0009)
      -- e já abrem o que moveram: um preview desenhado dali seria um segundo
      -- diff montado por cima do que a tecla acabou de abrir.
      --
      -- O evento é disparado à mão porque um editor headless não o dispara
      -- sozinho; a guarda é o que este teste está lendo.
      local repo = repo_with_three_changes()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "p"
      assert.equals("a.txt", previewing "a.txt")

      panel.feed "<CR>"
      assert.is_true(diff.focused())
      local win = assert(panel.win(), "o painel não está aberto")
      vim.api.nvim_win_set_cursor(win, { panel.cursor() + 1, 0 })
      panel.cursor_moved()

      assert.equals("a.txt", settled())
      assert.is_true(diff.focused())
    end)
  end)

  describe("um conflito", function()
    it("mostra as três versões ao lado da lista, sem trocar de aba", function()
      local repo = fixture.repo()
      repo:conflict "conflito.txt"
      local tabpages = #vim.api.nvim_list_tabpages()

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "p"
      previewing "conflito.txt"

      assert.same({ { "atual" }, { "base" }, { "entrando" } }, diff.sides())
      assert.same({
        "review://atual/conflito.txt",
        "review://base/conflito.txt",
        "review://entrando/conflito.txt",
      }, diff.names())
      assert.equals(tabpages + 1, #vim.api.nvim_list_tabpages())
      assert.equals(panel.win(), vim.api.nvim_get_current_win())
    end)
  end)

  describe("a descoberta da tecla", function()
    it("põe a tecla no menu de contexto junto do que ela faz, como as outras", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)

      assert.is_truthy(menu.entry_matching "^Ligar ou desligar o preview%s+p$")
    end)

    it("carrega a descrição que o which-key mostra", function()
      local repo = repo_with_three_changes()

      open_in(repo.root)
      local win = assert(panel.win(), "o painel não está aberto")
      local mappings = vim.api.nvim_buf_get_keymap(vim.api.nvim_win_get_buf(win), "n")

      local described = vim.tbl_filter(function(mapping) return mapping.lhs == "p" end, mappings)
      assert.equals(1, #described)
      assert.matches("preview", described[1].desc)
    end)
  end)
end)
