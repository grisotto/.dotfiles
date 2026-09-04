local diff = require "tests.helpers.diff"
local editor = require "tests.helpers.editor"
local fixture = require "tests.helpers.fixture"
local panel = require "tests.helpers.panel"
local review = require "review"

local config_root = vim.fn.getcwd()

---Open the review panel with the editor sitting inside `dir`.
---@param dir string
local function open_in(dir)
  vim.fn.chdir(dir)
  review.open()
end

---@return integer how many windows the tabpage has
local function window_count() return #vim.api.nvim_tabpage_list_wins(0) end

---Send keys to the window the reviewer is in, which after opening a diff is
---one of its sides.
---@param keys string
local function feed(keys) vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false) end

---The mappings of `lhs` a buffer carries, which is how a key of ours left on
---the reviewer's own file shows.
---@param bufnr integer
---@param lhs string
---@return table[]
local function mappings(bufnr, lhs)
  return vim.tbl_filter(function(map) return map.lhs == lhs end, vim.api.nvim_buf_get_keymap(bufnr, "n"))
end

---Let the editor finish what it was doing. A window leaving is the editor's own
---command, and what is left of the diff comes down on the turn of the loop after
---it — which in a headless editor has to be waited for.
local function settle()
  vim.wait(200, function() return false end)
end

---Run `command` with the reviewer sitting in `win`, the way they would type it.
---@param win integer winid
---@param command string
local function in_window(win, command)
  vim.api.nvim_set_current_win(win)
  vim.cmd(command)
end

---A repository with one file changed on disk: the line every diff here opens
---from.
---@return FixtureRepo
local function repo_with_a_change()
  local repo = fixture.repo()
  repo:commit_file("a.txt", "v1\n")
  repo:write("a.txt", "v2\n")
  return repo
end

---Open the two-way diff of the changed file, and hand back the buffer of the
---working tree side — the reviewer's own file, which is the one that must come
---out of this intact.
---@param repo FixtureRepo
---@return integer bufnr
local function open_diff(repo)
  open_in(repo.root)
  panel.focus("Unstaged", "a%.txt")
  panel.feed "<CR>"
  -- The two values `assert` hands back would both go into the call.
  local right = assert(diff.right(), "o diff não abriu")
  return vim.api.nvim_win_get_buf(right)
end

describe("fechar o diff", function()
  before_each(function() review.setup {} end)

  after_each(function()
    editor.reset()
    -- `cd`, not `chdir`: a tabpage local directory of a test would otherwise
    -- outlive it.
    vim.cmd.cd(vim.fn.fnameescape(config_root))
    fixture.cleanup()
  end)

  describe("a winbar", function()
    it("diz em cada janela qual lado ela está mostrando", function()
      local repo = repo_with_a_change()

      open_diff(repo)

      local bars = diff.winbars()
      assert.equals(2, #bars)
      assert.matches("índice", bars[1])
      assert.matches("working tree", bars[2])
    end)

    it("nomeia as três versões de um conflito, cada uma na janela dela", function()
      local repo = fixture.repo()
      repo:conflict "conflito.txt"

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "D"

      local bars = diff.winbars()
      assert.equals(3, #bars)
      assert.matches("atual", bars[1])
      assert.matches("base", bars[2])
      assert.matches("entrando", bars[3])
    end)

    it("mostra o atalho que fecha na janela mais à direita, e só nela", function()
      local repo = repo_with_a_change()

      open_diff(repo)

      local bars = diff.winbars()
      assert.matches("fechar%s+q", bars[2])
      assert.is_not.matches("fechar", bars[1])
    end)

    it("mostra o atalho na última das três versões de um conflito", function()
      local repo = fixture.repo()
      repo:conflict "conflito.txt"

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "D"

      local bars = diff.winbars()
      assert.matches("fechar%s+q", bars[3])
      assert.is_not.matches("fechar", bars[1])
      assert.is_not.matches("fechar", bars[2])
    end)
  end)

  describe("pelo q", function()
    it("fecha os dois lados e devolve o foco ao painel", function()
      local repo = repo_with_a_change()

      open_diff(repo)
      feed "q"

      assert.same({}, diff.windows())
      assert.equals(1, window_count())
      assert.equals(panel.win(), vim.api.nvim_get_current_win())
    end)

    it("fecha o diff inteiro também do lado que não é o do arquivo", function()
      local repo = repo_with_a_change()

      open_diff(repo)
      vim.api.nvim_set_current_win(diff.windows()[1])
      feed "q"

      assert.same({}, diff.windows())
      assert.equals(1, window_count())
      assert.equals(panel.win(), vim.api.nvim_get_current_win())
    end)

    it("fecha as três versões de um conflito", function()
      local repo = fixture.repo()
      repo:conflict "conflito.txt"

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "D"
      feed "q"

      assert.same({}, diff.windows())
      assert.equals(1, window_count())
      assert.equals(panel.win(), vim.api.nvim_get_current_win())
    end)

    it("deixa o arquivo do revisor sem a tecla e sem a winbar do diff", function()
      -- O lado do working tree é o buffer do arquivo, não uma cópia: o que o
      -- diff pôs nele tem que sair junto com o diff.
      local repo = repo_with_a_change()

      local bufnr = open_diff(repo)
      assert.equals(1, #mappings(bufnr, "q"))
      feed "q"

      assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
      assert.same({}, mappings(bufnr, "q"))
    end)

    it("não faz nada numa janela que não é lado deste diff", function()
      -- A tecla é local ao buffer, e o buffer do lado do working tree é o
      -- arquivo do revisor: ela existe em toda janela que mostre esse arquivo,
      -- inclusive em outra aba. Fora do diff não há o que fechar, e levar o
      -- revisor a um painel que ele não está olhando é pior do que não fazer
      -- nada.
      local repo = repo_with_a_change()

      local bufnr = open_diff(repo)
      vim.cmd "tabnew"
      vim.api.nvim_win_set_buf(0, bufnr)
      local elsewhere = vim.api.nvim_get_current_win()
      feed "q"

      assert.equals(elsewhere, vim.api.nvim_get_current_win())
      assert.equals(2, #vim.api.nvim_list_tabpages())
      vim.cmd "tabprevious"
      assert.equals(2, #diff.windows())
    end)

    it("devolve ao arquivo o mapeamento que o revisor já tinha na tecla", function()
      -- O diff escreve por cima do que estiver na tecla; o que ele devolve tem
      -- que ser o que estava lá, e não buffer nenhum.
      local repo = repo_with_a_change()

      open_in(repo.root)
      local bufnr = vim.fn.bufadd(repo.root .. "/a.txt")
      vim.fn.bufload(bufnr)
      vim.keymap.set("n", "q", "<Cmd>echo 'do revisor'<CR>", { buffer = bufnr, desc = "do revisor" })

      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      feed "q"

      local left = mappings(bufnr, "q")
      assert.equals(1, #left)
      assert.equals("do revisor", left[1].desc)
    end)

    it("não mexe no que o revisor tinha escrito do lado do working tree", function()
      local repo = repo_with_a_change()

      local bufnr = open_diff(repo)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "escrito enquanto lia" })
      feed "q"

      assert.same({ "escrito enquanto lia" }, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
    end)
  end)

  describe("fechando uma janela por fora", function()
    it("derruba a outra metade, sem deixar nada em modo diff", function()
      local repo = repo_with_a_change()

      local bufnr = open_diff(repo)
      in_window(assert(diff.right(), "o diff não abriu"), "quit")
      settle()

      assert.same({}, diff.windows())
      assert.equals(1, window_count())
      assert.same({}, mappings(bufnr, "q"))
    end)

    it("derruba a janela do arquivo quando quem fecha é o outro lado", function()
      local repo = repo_with_a_change()

      local bufnr = open_diff(repo)
      in_window(diff.windows()[1], "quit")
      settle()

      assert.same({}, diff.windows())
      assert.equals(1, window_count())
      -- O buffer é do revisor: a janela fecha, o arquivo fica.
      assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
      assert.same({}, mappings(bufnr, "q"))
    end)

    it("deixa o revisor com a janela que ele pediu ao fechar as outras", function()
      -- `:only` é um comando do editor sobre o layout inteiro: derrubar o resto
      -- do diff no meio dele aborta o comando e sobra a janela errada — a do
      -- lado que o revisor não pediu.
      local repo = repo_with_a_change()

      local bufnr = open_diff(repo)
      assert.has_no.errors(function() in_window(assert(diff.right(), "o diff não abriu"), "only") end)
      settle()

      assert.equals(1, window_count())
      assert.equals(bufnr, vim.api.nvim_win_get_buf(vim.api.nvim_get_current_win()))
      assert.same({}, diff.windows())
      assert.same({}, mappings(bufnr, "q"))
    end)

    it("não estoura ao fechar a aba inteira", function()
      local repo = repo_with_a_change()

      vim.cmd "tabnew"
      vim.cmd.tcd(vim.fn.fnameescape(repo.root))
      review.open()
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"

      assert.has_no.errors(function() vim.cmd "tabclose" end)
      settle()

      assert.equals(1, #vim.api.nvim_list_tabpages())
      assert.same({}, diff.windows())
    end)

    it("derruba as três versões de um conflito", function()
      local repo = fixture.repo()
      repo:conflict "conflito.txt"

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "D"
      in_window(diff.windows()[2], "quit")
      settle()

      assert.same({}, diff.windows())
      assert.equals(1, window_count())
    end)

    it("derruba o diff quando o outro buffer toma a janela do arquivo", function()
      -- É o que `<Leader>x` faz do lado do working tree quando o revisor tem
      -- outro buffer para o editor pôr ali: o arquivo sai, a janela fica. O que
      -- está nela agora é do revisor — fica com ele, fora do modo diff.
      local repo = repo_with_a_change()
      repo:write("b.txt", "outro arquivo\n")

      open_diff(repo)
      local right = assert(diff.right(), "o diff não abriu")
      local outro = vim.fn.bufadd(repo.root .. "/b.txt")
      vim.fn.bufload(outro)
      vim.api.nvim_win_set_buf(right, outro)
      settle()

      assert.same({}, diff.windows())
      assert.equals(2, window_count())
      assert.equals(outro, vim.api.nvim_win_get_buf(right))
      assert.equals("", vim.wo[right].winbar)
    end)

    it("não derruba o diff da outra aba", function()
      -- Uma aba por repositório: fechar uma janela aqui não é fechar o diff que
      -- o painel da outra aba montou.
      local a = fixture.repo()
      a:commit_file("a.txt", "a v1\n")
      a:write("a.txt", "a v2\n")
      local b = fixture.repo()
      b:commit_file("b.txt", "b v1\n")
      b:write("b.txt", "b v2\n")

      vim.cmd "tabnew"
      vim.cmd.tcd(vim.fn.fnameescape(a.root))
      review.open()
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"

      vim.cmd "tabnew"
      vim.cmd.tcd(vim.fn.fnameescape(b.root))
      review.open()
      panel.focus("Unstaged", "b%.txt")
      panel.feed "<CR>"
      vim.api.nvim_win_close(assert(diff.right(), "o diff não abriu"), false)

      vim.cmd "tabprevious"
      assert.same({ { "a v1" }, { "a v2" } }, diff.sides())
    end)
  end)
end)
