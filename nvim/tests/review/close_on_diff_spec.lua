local confirm = require "tests.helpers.confirm"
local diff = require "tests.helpers.diff"
local editor = require "tests.helpers.editor"
local fixture = require "tests.helpers.fixture"
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

---A repository with one file changed in the working tree.
---@return FixtureRepo
local function repo_with_a_change()
  local repo = fixture.repo()
  repo:commit_file("a.txt", "um\ndois\n")
  repo:write("a.txt", "um\ndois alterado\n")
  return repo
end

---Wait for the list to be on screen or off it: it leaves on the turn of the
---loop after the reviewer went into the diff, and a test waits for what the
---screen shows rather than for a length of time.
---@param open boolean
local function until_panel(open)
  assert(
    vim.wait(1000, function() return panel.is_open() == open end),
    open and "o painel não voltou para a tela" or "o painel não saiu da tela"
  )
end

---Let the editor take its turn where what is asserted is that nothing happens:
---there is no condition to wait for, so the wait is the turn of the loop in
---which the list would have left.
local function settle()
  vim.wait(200, function() return false end)
end

describe("o painel sai da tela quando o revisor entra no diff", function()
  before_each(function()
    review.setup { close_on_diff = true }
    fixture.data_dir()
    -- A busca do rev é a UI de seleção do editor.
    confirm.install()
  end)

  after_each(function()
    confirm.restore()
    editor.reset()
    vim.cmd.cd(vim.fn.fnameescape(config_root))
    fixture.cleanup()
  end)

  it("no <CR> de um arquivo, e o diff fica com o foco", function()
    local repo = repo_with_a_change()

    open_in(repo.root)
    panel.focus("Unstaged", "a%.txt")
    panel.feed "<CR>"
    until_panel(false)

    assert.equals(2, #diff.windows())
    assert.is_true(diff.focused())
  end)

  it("ao pular para o diff que o preview desenhou, e não enquanto a lista é varrida", function()
    local repo = repo_with_a_change()

    open_in(repo.root)
    panel.focus("Unstaged", "a%.txt")
    panel.feed "p"
    settle()
    -- O preview desenha sem o foco sair da lista: varrer não é ler.
    assert.is_true(panel.is_open())
    assert.equals(2, #diff.windows())

    vim.api.nvim_set_current_win(diff.windows()[2])
    until_panel(false)
  end)

  it("não nas três versões de um conflito, que são para ler com a lista na tela", function()
    local repo = fixture.repo()
    repo:conflict "conflito.txt"

    open_in(repo.root)
    panel.focus("Conflitos", "conflito%.txt")
    panel.feed "D"
    settle()

    assert.is_true(panel.is_open())
  end)

  it("não no arquivo lido em outro rev, que também é para ler com a lista na tela", function()
    local repo = fixture.repo()
    repo:commit_file("a.txt", "a v1\n", "primeiro")
    repo:commit_file("a.txt", "a v2\n", "segundo")
    repo:write("a.txt", "a v3\n")

    open_in(repo.root)
    panel.focus("Unstaged", "a%.txt")
    confirm.answer_matching "primeiro"
    panel.feed "e"
    settle()

    assert.is_true(panel.is_open())
  end)

  describe("o q do diff", function()
    it("traz o painel de volta com a largura dele, ao lado do que o diff deixou", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      until_panel(false)
      diff.feed "q"
      until_panel(true)

      assert.same({}, diff.windows())
      assert.equals(panel.win(), vim.api.nvim_get_current_win())
      -- Sozinho na aba o painel tomaria a tela inteira: o que o diff deixa é a
      -- janela ao lado dele.
      assert.equals(2, #vim.api.nvim_tabpage_list_wins(0))
      assert.equals(40, panel.width())
    end)

    it("põe o cursor no arquivo que era lido, também depois de andar a revisão", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a\n")
      repo:commit_file("b.txt", "b\n")
      repo:write("a.txt", "a alterado\n")
      repo:write("b.txt", "b alterado\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      until_panel(false)
      diff.feed "]f"
      assert.equals("b.txt", diff.reading())
      diff.feed "q"
      until_panel(true)

      assert.matches("b%.txt", panel.current())
    end)

    it("não reabre a lista que o revisor fechou por conta própria", function()
      -- Ele a tirou para ler com a largura do editor: fechar o diff não é
      -- pedir a lista de novo.
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      until_panel(false)
      review.open()
      review.close()
      vim.api.nvim_set_current_win(diff.windows()[2])
      settle()
      diff.feed "q"
      settle()

      assert.is_false(panel.is_open())
    end)
  end)

  it("desligada, a lista fica na tela", function()
    review.setup {}
    local repo = repo_with_a_change()

    open_in(repo.root)
    panel.focus("Unstaged", "a%.txt")
    panel.feed "<CR>"
    settle()

    assert.is_true(panel.is_open())
  end)

  it("recusa um valor que não é booleano", function()
    assert.has_error(function() review.setup { close_on_diff = "sim" } end)
  end)
end)
