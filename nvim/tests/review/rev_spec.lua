local confirm = require "tests.helpers.confirm"
local diff = require "tests.helpers.diff"
local editor = require "tests.helpers.editor"
local fixture = require "tests.helpers.fixture"
local graph = require "tests.helpers.graph"
local panel = require "tests.helpers.panel"
local review = require "review"

local config_root = vim.fn.getcwd()

---Open the review panel with the editor sitting inside `dir`.
---@param dir string
local function open_in(dir)
  vim.fn.chdir(dir)
  review.open()
end

---Paths compare only after resolving: the fixture lives under a temporary
---directory, which is a symlink on some machines.
---@param path string
---@return string
local function resolved(path) return vim.fn.resolve(path) end

---@return integer how many windows the tabpage has
local function window_count() return #vim.api.nvim_tabpage_list_wins(0) end

---What the window beside the panel is showing, which is where everything the
---panel opens lands.
---@return integer bufnr
local function buf_beside_the_panel()
  local win = assert(panel.win(), "o painel não está aberto")
  for _, other in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if other ~= win then return vim.api.nvim_win_get_buf(other) end
  end
  error "não há janela ao lado do painel"
end

---@return string the name of the buffer beside the panel
local function name_beside_the_panel() return vim.api.nvim_buf_get_name(buf_beside_the_panel()) end

---Send keys to the window the reviewer is in, which after opening a rev is the
---read-only view itself.
---@param keys string
local function feed(keys) vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false) end

---A repository with history in one file: `a.txt` committed twice and changed
---again on disk, plus a commit that never touched it.
---@return FixtureRepo
local function repo_with_history()
  local repo = fixture.repo()
  repo:commit_file("a.txt", "a v1\n", "primeiro")
  repo:commit_file("b.txt", "b\n", "só o b")
  repo:write("a.txt", "a v2\n")
  repo:add "a.txt"
  repo:commit "segundo"
  repo:write("a.txt", "a v3\n")
  return repo
end

---A repository where the other version of `a.txt` is on a branch of its own,
---and the working tree has a third one: the change the panel is listing.
---@return FixtureRepo
local function repo_with_a_branch()
  local repo = fixture.repo()
  repo:commit_file("a.txt", "a v1\n", "primeiro")
  repo:git { "checkout", "--quiet", "-b", "outra" }
  repo:commit_file("a.txt", "a na outra\n", "commit da outra")
  repo:git { "checkout", "--quiet", "main" }
  repo:write("a.txt", "a v3\n")
  return repo
end

---The short name git gives a rev, which is what the buffer of a view is named
---after.
---@param repo FixtureRepo
---@param rev string
---@return string
local function short(repo, rev) return vim.trim(repo:git { "rev-parse", "--short=7", rev }) end

describe("o arquivo em outro rev", function()
  before_each(function()
    review.setup {}
    fixture.data_dir()
    -- A busca do rev é a UI de seleção do editor, a mesma por onde o descartar
    -- pergunta e por onde a branch do filtro é escolhida.
    confirm.install()
  end)

  after_each(function()
    editor.reset()
    confirm.restore()
    -- `cd`, not `chdir`: a tabpage local directory of a test would otherwise
    -- outlive it.
    vim.cmd.cd(vim.fn.fnameescape(config_root))
    fixture.cleanup()
  end)

  describe("a busca do rev", function()
    it("lista as branches do repositório e os commits daquele arquivo", function()
      local repo = repo_with_history()
      repo:git { "branch", "outra" }

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "e"

      local offered = confirm.offered()
      assert.is_true(vim.tbl_contains(offered, "main"), vim.inspect(offered))
      assert.is_true(vim.tbl_contains(offered, "outra"), vim.inspect(offered))
      assert.is_truthy(
        vim.tbl_filter(function(item) return item:match "primeiro" end, offered)[1],
        vim.inspect(offered)
      )
      assert.is_truthy(vim.tbl_filter(function(item) return item:match "segundo" end, offered)[1], vim.inspect(offered))
      -- O commit que não tocou o arquivo não é história dele.
      assert.same({}, vim.tbl_filter(function(item) return item:match "só o b" end, offered))
    end)

    it("mostra o commit com o sha curto, a data e o assunto, para não digitar sha", function()
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "e"

      local offered = confirm.offered()
      local line = vim.tbl_filter(function(item) return item:match "primeiro" end, offered)[1]
      assert.equals(("%s 2026-01-01 primeiro"):format(short(repo, "HEAD~2")), line)
    end)

    it("diz na pergunta qual arquivo está sendo visto, e qual comparado", function()
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "e"
      panel.focus("Unstaged", "a%.txt")
      panel.feed "E"

      assert.same({ "Ver a.txt em outro rev", "Comparar a.txt com outro rev" }, confirm.prompts())
    end)

    it("não abre busca nenhuma num repositório sem commits", function()
      -- Não há branch nem commit para escolher: uma busca vazia é pior do que
      -- uma tecla que diz por que não fez nada.
      local repo = fixture.repo_without_commits()
      repo:write("novo.txt", "novo\n")

      open_in(repo.root)
      panel.focus("Untracked", "novo%.txt")

      assert.has_no.errors(function() panel.feed "e" end)
      assert.same({}, confirm.prompts())
    end)

    it("oferece as branches também para um arquivo que o git nunca viu", function()
      local repo = repo_with_history()
      repo:write("novo.txt", "novo\n")

      open_in(repo.root)
      panel.focus("Untracked", "novo%.txt")
      panel.feed "e"

      assert.is_true(vim.tbl_contains(confirm.offered(), "main"), vim.inspect(confirm.offered()))
    end)
  end)

  describe("ver o arquivo no rev escolhido", function()
    it("abre o conteúdo daquele commit, e não o do disco", function()
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      confirm.answer_matching "primeiro"
      panel.feed "e"

      assert.same({ "a v1" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
    end)

    it("abre somente leitura: é uma consulta, não um arquivo para editar", function()
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      confirm.answer_matching "primeiro"
      panel.feed "e"

      assert.is_false(vim.bo[0].modifiable)
      assert.equals("nofile", vim.bo[0].buftype)
    end)

    it("identifica o buffer pelo rev, que é como o revisor sabe o que está lendo", function()
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      confirm.answer_matching "primeiro"
      panel.feed "e"

      assert.equals(("review://%s/a.txt"):format(short(repo, "HEAD~2")), vim.api.nvim_buf_get_name(0))
    end)

    it("abre no rev de uma branch, com o nome dela no buffer", function()
      local repo = repo_with_a_branch()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      confirm.answer "outra"
      panel.feed "e"

      assert.same({ "a na outra" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      assert.equals("review://outra/a.txt", vim.api.nvim_buf_get_name(0))
    end)

    it("abre ao lado do painel, na mesma aba, com a lista ainda visível", function()
      local repo = repo_with_history()
      local tabpage = vim.api.nvim_get_current_tabpage()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      confirm.answer_matching "primeiro"
      panel.feed "e"

      assert.equals(tabpage, vim.api.nvim_get_current_tabpage())
      assert.equals(1, #vim.api.nvim_list_tabpages())
      assert.is_true(panel.is_open())
      assert.equals(2, window_count())
    end)

    it("não abre buffer nenhum quando o rev não tem o arquivo", function()
      local repo = repo_with_history()
      repo:write("novo.txt", "novo\n")

      open_in(repo.root)
      panel.focus("Untracked", "novo%.txt")
      confirm.answer "main"

      assert.has_no.errors(function() panel.feed "e" end)
      assert.is_not.matches("^review://", name_beside_the_panel())
    end)

    it("continua nomeando o buffer ao ver o mesmo rev de novo", function()
      -- O rev é o que distingue a vista, e o nome de um buffer é único no
      -- editor: a vista anterior tem que sair da frente antes da nova.
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      confirm.answer "main"
      panel.feed "e"
      panel.focus("Unstaged", "a%.txt")
      panel.feed "e"

      assert.equals("review://main/a.txt", vim.api.nvim_buf_get_name(0))
      assert.equals(2, window_count())
    end)

    it("um diff aberto depois dela não fica sem nome nem deixa janela órfã", function()
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      confirm.answer "main"
      panel.feed "e"
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"

      assert.same({ { "a v2" }, { "a v3" } }, diff.sides())
      assert.equals(3, window_count())
    end)

    it("não faz nada numa linha que não é arquivo", function()
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus_header()
      confirm.answer "main"

      assert.has_no.errors(function() panel.feed "e" end)
      assert.same({}, confirm.prompts())
    end)

    it("não abre nada quando a busca é cancelada", function()
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "e"

      assert.is_not.matches("^review://", name_beside_the_panel())
      assert.equals(2, window_count())
    end)
  end)

  describe("um arquivo renomeado", function()
    it("procura a história dele também pelo nome antigo", function()
      -- A renomeação ainda não está commitada: pelo nome novo o git não tem
      -- história nenhuma, e uma busca só com as branches seria a resposta errada.
      local repo = repo_with_history()
      repo:git { "mv", "a.txt", "renomeado.txt" }

      open_in(repo.root)
      panel.focus("Staged", "renomeado%.txt")
      panel.feed "e"

      local offered = confirm.offered()
      assert.is_truthy(
        vim.tbl_filter(function(item) return item:match "primeiro" end, offered)[1],
        vim.inspect(offered)
      )
    end)

    it("abre no rev o conteúdo que estava sob o nome antigo", function()
      local repo = repo_with_history()
      repo:git { "mv", "a.txt", "renomeado.txt" }

      open_in(repo.root)
      panel.focus("Staged", "renomeado%.txt")
      confirm.answer_matching "primeiro"
      panel.feed "e"

      assert.same({ "a v1" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      -- Nomeado pelo caminho que o rev tem, que é como o revisor sabe que está
      -- lendo o arquivo de antes da renomeação.
      assert.equals(("review://%s/a.txt"):format(short(repo, "HEAD~2")), vim.api.nvim_buf_get_name(0))
    end)

    it("compara a versão do nome antigo com o arquivo de agora", function()
      local repo = repo_with_history()
      repo:git { "mv", "a.txt", "renomeado.txt" }

      open_in(repo.root)
      panel.focus("Staged", "renomeado%.txt")
      confirm.answer_matching "primeiro"
      panel.feed "E"

      assert.same({ { "a v1" }, { "a v3" } }, diff.sides())
    end)
  end)

  describe("no modo commit", function()
    it("são as mesmas duas teclas, sobre o arquivo daquele commit", function()
      -- O painel tem um modo, e as teclas são as mesmas nos dois (ADR-0001):
      -- revisando um commit, perguntar como o arquivo era em outro rev é a
      -- mesma pergunta.
      local repo = repo_with_history()

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      panel.focus("Mudanças", "a%.txt")
      confirm.answer_matching "primeiro"
      panel.feed "e"

      assert.same({ "a v1" }, vim.api.nvim_buf_get_lines(0, 0, -1, false))
      assert.equals(("review://%s/a.txt"):format(short(repo, "HEAD~2")), vim.api.nvim_buf_get_name(0))
    end)

    it("compara com a versão do commit em revisão, e não com o disco", function()
      -- No modo commit os dois lados são história, como no diff da linha: o que
      -- está no disco hoje não é o que a linha está mostrando, e o arquivo pode
      -- nem existir mais.
      local repo = repo_with_history()

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      panel.focus("Mudanças", "a%.txt")
      confirm.answer_matching "primeiro"
      panel.feed "E"

      assert.same({ { "a v1" }, { "a v2" } }, diff.sides())
      assert.same({
        ("review://%s/a.txt"):format(short(repo, "HEAD~2")),
        ("review://%s/a.txt"):format(short(repo, "HEAD")),
      }, diff.names())
    end)
  end)

  describe("a volta", function()
    it("devolve à janela o arquivo que estava sendo lido, e o cursor ao painel", function()
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "o"
      panel.focus("Unstaged", "a%.txt")
      confirm.answer_matching "primeiro"
      panel.feed "e"
      feed "q"

      assert.equals(resolved(repo.root .. "/a.txt"), resolved(name_beside_the_panel()))
      assert.same({ "a v3" }, vim.api.nvim_buf_get_lines(buf_beside_the_panel(), 0, -1, false))
      assert.equals(panel.win(), vim.api.nvim_get_current_win())
    end)

    it("devolve à janela o arquivo do working tree que o diff estava mostrando", function()
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      panel.focus("Unstaged", "a%.txt")
      confirm.answer_matching "primeiro"
      panel.feed "e"
      feed "q"

      assert.equals(resolved(repo.root .. "/a.txt"), resolved(name_beside_the_panel()))
      assert.same({}, diff.sides())
      assert.equals(2, window_count())
    end)

    it("devolve o mesmo arquivo depois de duas consultas seguidas", function()
      -- A segunda vista abre por cima da primeira, e aí o arquivo já não está
      -- na tela para a janela ser perguntada sobre ele: o que a primeira ia
      -- devolver é o que a segunda devolve.
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "o"
      panel.focus("Unstaged", "a%.txt")
      confirm.answer_matching "primeiro"
      panel.feed "e"
      panel.focus("Unstaged", "a%.txt")
      confirm.answer "main"
      panel.feed "e"
      feed "q"

      assert.equals(resolved(repo.root .. "/a.txt"), resolved(name_beside_the_panel()))
      assert.equals(panel.win(), vim.api.nvim_get_current_win())
    end)

    it("tira a vista da tela mesmo sem nada aberto antes dela", function()
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      confirm.answer_matching "primeiro"
      panel.feed "e"
      feed "q"

      assert.is_not.matches("^review://", name_beside_the_panel())
      assert.is_true(panel.is_open())
      assert.equals(panel.win(), vim.api.nvim_get_current_win())
    end)
  end)

  describe("comparar o arquivo com o rev escolhido", function()
    it("põe a versão daquele rev contra o arquivo atual", function()
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      confirm.answer_matching "primeiro"
      panel.feed "E"

      assert.same({ { "a v1" }, { "a v3" } }, diff.sides())
    end)

    it("nomeia o lado esquerdo pelo rev, e deixa o arquivo de verdade do direito", function()
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      confirm.answer_matching "primeiro"
      panel.feed "E"

      local names = diff.names()
      assert.equals(("review://%s/a.txt"):format(short(repo, "HEAD~2")), names[1])
      assert.equals(resolved(repo.root .. "/a.txt"), resolved(names[2]))

      local right = assert(diff.right(), "o diff não abriu")
      local bufnr = vim.api.nvim_win_get_buf(right)
      assert.equals("", vim.bo[bufnr].buftype)
      assert.is_true(vim.bo[bufnr].modifiable)
    end)

    it("compara com a versão da branch escolhida", function()
      local repo = repo_with_a_branch()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      confirm.answer "outra"
      panel.feed "E"

      assert.same({ { "a na outra" }, { "a v3" } }, diff.sides())
    end)

    it("compara com um lado vazio o arquivo que o rev não tem", function()
      -- Um arquivo que ainda não existia naquele rev é um lado vazio do diff,
      -- que é o que ele é — ao contrário da vista, que não teria o que mostrar.
      local repo = repo_with_history()
      repo:write("novo.txt", "novo\n")

      open_in(repo.root)
      panel.focus("Untracked", "novo%.txt")
      confirm.answer "main"
      panel.feed "E"

      assert.same({ { "" }, { "novo" } }, diff.sides())
    end)

    it("abre ao lado do painel, na mesma aba, com a lista ainda visível", function()
      local repo = repo_with_history()
      local tabpage = vim.api.nvim_get_current_tabpage()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      confirm.answer_matching "primeiro"
      panel.feed "E"

      assert.equals(tabpage, vim.api.nvim_get_current_tabpage())
      assert.is_true(panel.is_open())
      assert.equals(3, window_count())
    end)

    it("não abre nada quando a busca é cancelada", function()
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "E"

      assert.same({}, diff.sides())
      assert.equals(2, window_count())
    end)

    it("não faz nada numa linha que não é arquivo", function()
      local repo = repo_with_history()

      open_in(repo.root)
      panel.focus_header()
      confirm.answer "main"

      assert.has_no.errors(function() panel.feed "E" end)
      assert.same({}, diff.sides())
    end)
  end)
end)
