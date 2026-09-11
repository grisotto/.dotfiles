local confirm = require "tests.helpers.confirm"
local diff = require "tests.helpers.diff"
local document = require "tests.helpers.document"
local fixture = require "tests.helpers.fixture"
local graph = require "tests.helpers.graph"
local input = require "tests.helpers.input"
local menu = require "tests.helpers.menu"
local panel = require "tests.helpers.panel"
local report = require "tests.helpers.report"
local review = require "review"

local config_root = vim.fn.getcwd()

---What the branch search offers to take the filter off, read exactly as the
---reviewer reads it in the list.
local EVERY_BRANCH = "todas as branches"

---Open the review panel on `dir`, in a tabpage of its own — the way a reviewer
---with one repository per tab does it. Each test gets a panel that was never
---opened before, so what it observes is the state on disk and not the mode a
---previous test left this one in.
---@param dir string
local function open_in(dir)
  vim.cmd "tabnew"
  vim.cmd.tcd(vim.fn.fnameescape(dir))
  review.open()
end

---A repository with something to look at in the graph: two commits on the
---branch it is on and one on a branch of its own, which is what "all the
---branches" means when there is more than one.
---@return FixtureRepo
local function repo_with_branches()
  local repo = fixture.repo()
  repo:commit_file("a.txt", "a v1\n", "primeiro")
  repo:git { "checkout", "-b", "outra" }
  repo:commit_file("so-na-outra.txt", "outra\n", "commit da outra branch")
  repo:git { "checkout", "main" }
  repo:write("a.txt", "a v2\n")
  repo:write("novo.txt", "novo\n")
  repo:add("a.txt", "novo.txt")
  repo:commit "segundo"
  return repo
end

---A history in a row, which is what a range covers and a single commit does
---not: three commits in a line, with a file that is born in the middle one and
---is already gone by the last.
---@return FixtureRepo
local function repo_with_a_series()
  local repo = fixture.repo()
  repo:commit_file("a.txt", "a v1\n", "primeiro")
  repo:write("a.txt", "a v2\n")
  repo:write("passageiro.txt", "passa\n")
  repo:add("a.txt", "passageiro.txt")
  repo:commit "segundo"
  repo:write("a.txt", "a v3\n")
  repo:write("b.txt", "b\n")
  repo:delete "passageiro.txt"
  repo:add("a.txt", "b.txt", "passageiro.txt")
  repo:commit "terceiro"
  return repo
end

describe("modo commit", function()
  before_each(function()
    review.setup {}
    fixture.data_dir()
    input.install()
    -- A busca de branch é a UI de seleção do editor, a mesma por onde o
    -- descartar pergunta: aqui ela é lida e respondida como lá.
    confirm.install()
    -- A anotação pede o tipo nessa mesma UI, antes do texto; quem não fala dele
    -- escolhe `issue`, que é o `<CR>` do revisor numa anotação nova.
    confirm.answer_matching "^issue "
  end)

  after_each(function()
    review.close()
    input.restore()
    confirm.restore()
    -- Back to the first tabpage before dropping the others: `tabonly!` keeps
    -- the current one, and keeping a tabpage of the test would carry its panel
    -- — and the mode it is in — into the next one.
    vim.cmd "tabfirst"
    vim.cmd "tabonly!"
    vim.cmd.cd(vim.fn.fnameescape(config_root))
    fixture.cleanup()
  end)

  describe("o grafo", function()
    it("mostra os commits de todas as branches", function()
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"

      assert.is_not_nil(graph.line_matching "segundo")
      assert.is_not_nil(graph.line_matching "primeiro")
      -- O commit que só existe na outra branch é o que separa "todas as
      -- branches" de "a branch em que estou".
      assert.is_not_nil(graph.line_matching "commit da outra branch")
    end)

    it("mostra em que branch cada commit está", function()
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"

      assert.is_not_nil(graph.line_matching "%(outra%)")
      assert.is_not_nil(graph.line_matching "main%)")
    end)

    it("abre com o cursor no commit mais recente", function()
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"

      assert.is_not_nil(graph.current():match "segundo")
    end)

    it("não deixa o painel: a lista continua na tela ao lado", function()
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"

      assert.is_true(panel.is_open())
      assert.is_true(graph.is_open())
    end)

    it("desmonta o diff que estava ao lado, em vez de deixar um lado sozinho", function()
      -- O grafo toma a janela em que um dos lados do diff estava. Um lado que
      -- ficasse para trás continuaria em modo diff sem nada com que comparar:
      -- toda linha do arquivo do revisor viraria linha sem mudança, e o arquivo
      -- inteiro se fecharia numa dobra só.
      local repo = repo_with_branches()
      repo:write("a.txt", "a v3\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      assert.equals(2, #diff.windows())

      panel.feed "c"

      assert.same({}, diff.windows())
    end)

    it("diz que o repositório não tem commits em vez de falhar", function()
      local repo = fixture.repo_without_commits()

      open_in(repo.root)
      panel.feed "c"

      assert.is_not_nil(graph.line_matching "Repositório sem commits")
    end)
  end)

  describe("o filtro por branch", function()
    it("oferece as branches do repositório na busca, e a volta para todas", function()
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"
      graph.filter_by "outra"

      local offered = confirm.offered()
      assert.is_true(vim.tbl_contains(offered, "main"), vim.inspect(offered))
      assert.is_true(vim.tbl_contains(offered, "outra"), vim.inspect(offered))
      assert.is_true(vim.tbl_contains(offered, EVERY_BRANCH), vim.inspect(offered))
    end)

    it("oferece as branches do remoto, menos o ponteiro para a padrão dele", function()
      -- A branch que o revisor vai procurar é muitas vezes de outra pessoa, e
      -- está no repositório dele como branch do remoto. O que o remoto guarda
      -- como sua branch padrão não é uma delas: o git a encurta para "origin",
      -- que não é nome de branch nenhuma.
      local origin = repo_with_branches()
      local repo = fixture.repo()
      repo:git { "remote", "add", "origin", origin.root }
      repo:git { "fetch", "--quiet", "origin" }
      repo:git { "remote", "set-head", "origin", "main" }

      open_in(repo.root)
      panel.feed "c"
      graph.feed "b"

      local offered = confirm.offered()
      assert.is_true(vim.tbl_contains(offered, "origin/outra"), vim.inspect(offered))
      assert.is_false(vim.tbl_contains(offered, "origin"), vim.inspect(offered))
    end)

    it("reabre o grafo restrito à branch escolhida", function()
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"
      graph.filter_by "outra"

      assert.is_not_nil(graph.line_matching "commit da outra branch")
      assert.is_not_nil(graph.line_matching "primeiro")
      -- O commit que só existe na main é o que separa "esta branch" de "todas".
      assert.is_nil(graph.line_matching "segundo")
    end)

    it("diz no cabeçalho por qual branch está filtrado", function()
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"
      graph.filter_by "outra"

      assert.is_not_nil(graph.line_matching "^Commits · outra$")
    end)

    it("volta a mostrar todas as branches", function()
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"
      graph.filter_by "outra"
      graph.filter_by(EVERY_BRANCH)

      assert.is_not_nil(graph.line_matching "segundo")
      assert.is_not_nil(graph.line_matching "commit da outra branch")
    end)

    it("continua deixando escolher o commit que se foi procurar", function()
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"
      graph.filter_by "outra"
      graph.choose "commit da outra branch"

      assert.same({ "A  so-na-outra.txt" }, panel.section "Mudanças")
    end)

    it("não deixa o painel ao filtrar", function()
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"
      graph.filter_by "outra"

      assert.is_true(panel.is_open())
      assert.is_true(graph.is_open())
    end)
  end)

  describe("escolher um commit", function()
    it("faz o painel listar os arquivos daquele commit", function()
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"

      assert.same({ "M  a.txt", "A  novo.txt" }, panel.section "Mudanças")
    end)

    it("lista as seções do working tree, e não as do commit, ao voltar", function()
      local repo = repo_with_branches()
      repo:write("a.txt", "a v3\n")

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      panel.feed "w"

      assert.same({ "M  a.txt" }, panel.section "Unstaged")
      assert.is_nil(panel.section_count "Mudanças")
    end)

    it("identifica o commit em revisão no cabeçalho", function()
      local repo = repo_with_branches()
      local sha = vim.trim(repo:git { "rev-parse", "--short", "HEAD" })

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"

      local header = assert(panel.line_matching "^Revisão · ")
      assert.is_not_nil(header:match(sha), ("o cabeçalho %q não traz o commit %q"):format(header, sha))
      assert.is_not_nil(header:match "segundo")
    end)

    it("volta a identificar a branch no cabeçalho no working tree", function()
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      panel.feed "w"

      assert.is_not_nil(panel.line_matching "^Revisão · main")
    end)

    it("traz na segunda linha o autor, a data e os totais do commit", function()
      -- Quem revisa o commit de outra pessoa precisa saber de quem ele é e de
      -- quando: é isso que muda de modo para modo, e não as teclas (ADR-0001).
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"

      assert.equals("Fixture · 2026-01-01 · +2 −1", panel.lines()[2])
      assert.is_true(panel.is_dimmed "^Fixture · ")
    end)

    it("abre o painel no working tree quando ele está fechado", function()
      -- A volta ao working tree com o painel fechado é o pedido pela lista:
      -- redesenhar um buffer que não está na tela não mostraria nada.
      local repo = repo_with_branches()
      repo:write("a.txt", "a v3\n")

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      review.close()
      review.worktree()

      assert.is_true(panel.is_open())
      assert.same({ "M  a.txt" }, panel.section "Unstaged")
    end)

    it("conta o progresso do commit, e não o do working tree", function()
      local repo = repo_with_branches()
      repo:write("mexido.txt", "mexido\n")

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"

      -- Dois arquivos no commit, seja qual for o tamanho do working tree.
      assert.is_not_nil(panel.line_matching "0/2 vistos")
    end)

    it("lista o caminho novo de um arquivo renomeado no commit", function()
      local repo = fixture.repo()
      repo:commit_file("antigo.txt", "conteúdo que sobrevive\n", "primeiro")
      repo:git { "mv", "antigo.txt", "novo.txt" }
      repo:commit "renomeia"

      open_in(repo.root)
      panel.feed "c"
      graph.choose "renomeia"

      assert.same({ "R  novo.txt" }, panel.section "Mudanças")
    end)

    it("lista o que o primeiro commit do repositório trouxe", function()
      -- Sem o commit inicial do fixture, para que o commit revisado seja mesmo
      -- a raiz: ele não tem pai contra o qual ser comparado, e ainda assim tem
      -- o que mostrar.
      local repo = fixture.repo_without_commits()
      repo:commit_file("a.txt", "a v1\n", "primeiro")

      open_in(repo.root)
      panel.feed "c"
      graph.choose "primeiro"

      assert.same({ "A  a.txt" }, panel.section "Mudanças")
    end)

    it("lista o que um merge trouxe, e não uma lista vazia", function()
      local repo = fixture.repo()
      repo:commit_file("base.txt", "base\n", "base")
      repo:git { "checkout", "-b", "feature" }
      repo:commit_file("da-feature.txt", "feature\n", "commit da feature")
      repo:git { "checkout", "main" }
      repo:commit_file("da-main.txt", "main\n", "commit da main")
      repo:git { "merge", "--no-ff", "--no-gpg-sign", "-m", "merge da feature", "feature" }

      open_in(repo.root)
      panel.feed "c"
      graph.choose "merge da feature"

      assert.same({ "A  da-feature.txt" }, panel.section "Mudanças")
    end)
  end)

  describe("as teclas do painel no modo commit", function()
    it("abre o diff do commit contra o pai dele", function()
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      panel.focus("Mudanças", "a%.txt")
      panel.feed "<CR>"

      assert.same({ { "a v1" }, { "a v2" } }, diff.sides())
    end)

    it("diz em que rev está cada lado do diff", function()
      local repo = repo_with_branches()
      local sha = vim.trim(repo:git { "rev-parse", "--short=7", "HEAD" })

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      panel.focus("Mudanças", "a%.txt")
      panel.feed "<CR>"

      assert.same({
        diff.side_name(repo.root, "a.txt", sha .. "^"),
        diff.side_name(repo.root, "a.txt", sha),
      }, diff.names())
    end)

    it("abre o diff do primeiro commit com o lado esquerdo vazio", function()
      local repo = fixture.repo_without_commits()
      repo:commit_file("a.txt", "a v1\n", "primeiro")

      open_in(repo.root)
      panel.feed "c"
      graph.choose "primeiro"
      panel.focus("Mudanças", "a%.txt")
      panel.feed "<CR>"

      -- O commit raiz não tem pai: o lado esquerdo é o que não havia.
      assert.same({ { "" }, { "a v1" } }, diff.sides())
    end)

    it("marca um arquivo do commit como visto", function()
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      panel.focus("Mudanças", "a%.txt")
      panel.feed "v"

      assert.same({ "A  novo.txt" }, panel.section "Mudanças")
      assert.equals(1, panel.section_count "Vistos")
    end)

    it("copia o caminho do arquivo do commit", function()
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      panel.focus("Mudanças", "novo%.txt")
      panel.feed "Y"

      assert.equals(repo.root .. "/novo.txt", vim.fn.getreg '"')
    end)

    it("recusa mover para staged o que já está commitado", function()
      local repo = repo_with_branches()
      repo:write("a.txt", "a v3\n")

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      panel.focus("Mudanças", "a%.txt")
      panel.feed "s"

      -- O working tree é o que diz se a tecla mexeu no repositório: a mudança
      -- de a.txt continua fora do índice.
      panel.feed "w"
      assert.same({ "M  a.txt" }, panel.section "Unstaged")
      assert.is_nil(panel.section_count "Staged")
    end)

    it("recusa descartar o que já está commitado", function()
      local repo = repo_with_branches()
      repo:write("a.txt", "a v3\n")

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      panel.focus("Mudanças", "a%.txt")
      panel.feed "X"

      assert.equals("a v3\n", repo:read "a.txt")
    end)
  end)

  describe("o que o painel oferece no modo commit", function()
    ---As teclas do working tree que um commit não tem o que fazer com.
    local WORKTREE_ONLY = { "s", "u", "X" }

    ---A descrição que cada tecla do painel carrega, que é o que o which-key
    ---mostra.
    ---@return table<string, string> descrição por tecla
    local function described()
      local win = assert(panel.win(), "o painel não está aberto")
      local descriptions = {}
      for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(vim.api.nvim_win_get_buf(win), "n")) do
        if mapping.desc and mapping.desc ~= "" then descriptions[mapping.lhs] = mapping.desc end
      end
      return descriptions
    end

    it("não oferece stage, unstage e descartar no menu nem no which-key", function()
      -- Um menu que oferece o que vai ser recusado é pior do que não ter menu.
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"

      local offered, keys = menu.actions(), described()
      for _, key in ipairs(WORKTREE_ONLY) do
        assert.is_nil(offered[key], ("o menu do modo commit ainda oferece %q"):format(key))
        assert.is_nil(keys[key], ("a tecla %q do modo commit ainda tem descrição"):format(key))
      end
      -- O resto continua lá: o que sai é o que o modo não pode fazer, e não o
      -- menu inteiro.
      assert.equals("Abrir o diff", offered["<CR>"])
      assert.equals("Gerar o relatório em XML", offered["R"])
      assert.equals("Gerar o relatório em markdown", offered["M"])
    end)

    it("segue com as três teclas mapeadas, para a recusa continuar respondendo", function()
      -- A recusa em si é o que os testes de "as teclas do painel no modo commit"
      -- afirmam, pelo repositório que não mudou. O que se lê aqui é que a tecla
      -- continua no painel: só a descrição dela saiu.
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"

      local win = assert(panel.win(), "o painel não está aberto")
      local mapped = {}
      for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(vim.api.nvim_win_get_buf(win), "n")) do
        mapped[mapping.lhs] = true
      end
      for _, key in ipairs(WORKTREE_ONLY) do
        assert.is_true(mapped[key] == true, ("a tecla %q saiu do painel em vez de só sair do menu"):format(key))
      end
    end)

    it("volta a oferecer as três ao voltar ao working tree", function()
      local repo = repo_with_branches()
      repo:write("a.txt", "a v3\n")

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      panel.feed "w"

      local offered, keys = menu.actions(), described()
      for _, key in ipairs(WORKTREE_ONLY) do
        assert.is_not_nil(offered[key], ("o menu do working tree não oferece %q"):format(key))
        assert.is_not_nil(keys[key], ("a tecla %q do working tree ficou sem descrição"):format(key))
      end
    end)
  end)

  describe("a linha do próximo passo", function()
    it("no commit, diz para gerar o relatório", function()
      -- O fim da revisão é uma linha, e não um estado novo: nada é iniciado,
      -- nada é finalizado (ADR-0002).
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      panel.focus("Mudanças", "a%.txt")
      panel.feed "v"
      panel.focus("Mudanças", "novo%.txt")
      panel.feed "v"

      assert.is_not_nil(panel.line_matching "Gerar o relatório: R")
      assert.is_nil(panel.line_matching "Nenhuma mudança")
    end)
  end)

  describe("o modo intervalo", function()
    it("lista os arquivos do intervalo inteiro, e não os do último commit", function()
      local repo = repo_with_a_series()

      open_in(repo.root)
      panel.feed "c"
      graph.choose_range("terceiro", "segundo")

      -- passageiro.txt nasceu e morreu dentro do intervalo: quem revisa a
      -- feature inteira não tem o que ler nele.
      assert.same({ "M  a.txt", "A  b.txt" }, panel.section "Mudanças")
    end)

    it("identifica o intervalo em revisão no cabeçalho", function()
      local repo = repo_with_a_series()
      local oldest = vim.trim(repo:git { "rev-parse", "--short", "HEAD~1" })
      local newest = vim.trim(repo:git { "rev-parse", "--short", "HEAD" })

      open_in(repo.root)
      panel.feed "c"
      graph.choose_range("terceiro", "segundo")

      local header = assert(panel.line_matching "^Revisão · ")
      -- Com o `^`: o commit mais antigo entra na revisão, e `a..b` diria a quem
      -- lê git que ele está de fora.
      assert.is_not_nil(
        header:match(("%s%%^%%.%%.%s"):format(oldest, newest)),
        ("o cabeçalho %q não traz o intervalo %s^..%s"):format(header, oldest, newest)
      )
      assert.is_not_nil(header:match "2 commits", header)
    end)

    it("traz na segunda linha quantos commits o intervalo tem, e os totais dele", function()
      local repo = repo_with_a_series()

      open_in(repo.root)
      panel.feed "c"
      graph.choose_range("terceiro", "segundo")

      assert.equals("2 commits · +2 −1", panel.lines()[2])
      assert.is_true(panel.is_dimmed "^2 commits · ")
    end)

    it("recusa um intervalo entre duas branches que divergiram", function()
      -- O grafo desenha todas as branches, então duas linhas vizinhas na tela
      -- podem estar em histórias diferentes. Comparar as duas pontas listaria
      -- tudo o que difere entre as branches, que não é intervalo nenhum.
      local repo = repo_with_branches()

      open_in(repo.root)
      panel.feed "c"
      graph.choose_range("segundo", "commit da outra branch")

      assert.is_nil(panel.section_count "Mudanças")
      assert.is_not_nil(panel.line_matching "^Revisão · main")
    end)

    it("revisa um commit só quando a seleção é de uma linha", function()
      local repo = repo_with_a_series()

      open_in(repo.root)
      panel.feed "c"
      graph.choose_range("segundo", "segundo")

      assert.same({ "M  a.txt", "A  passageiro.txt" }, panel.section "Mudanças")
      assert.is_not_nil(panel.line_matching "^Revisão · %x+ segundo")
    end)

    it("lista o intervalo que chega ao primeiro commit do repositório", function()
      local repo = fixture.repo_without_commits()
      repo:commit_file("a.txt", "a v1\n", "primeiro")
      repo:commit_file("b.txt", "b\n", "segundo")

      open_in(repo.root)
      panel.feed "c"
      graph.choose_range("segundo", "primeiro")

      -- O commit mais antigo do intervalo não tem pai: o intervalo começa no
      -- que não havia.
      assert.same({ "A  a.txt", "A  b.txt" }, panel.section "Mudanças")
    end)

    it("volta ao working tree com a mesma tecla", function()
      local repo = repo_with_a_series()
      repo:write("a.txt", "a v4\n")

      open_in(repo.root)
      panel.feed "c"
      graph.choose_range("terceiro", "segundo")
      panel.feed "w"

      assert.same({ "M  a.txt" }, panel.section "Unstaged")
      assert.is_nil(panel.section_count "Mudanças")
    end)

    describe("as teclas do painel", function()
      it("abrem o diff do intervalo inteiro", function()
        local repo = repo_with_a_series()

        open_in(repo.root)
        panel.feed "c"
        graph.choose_range("terceiro", "segundo")
        panel.focus("Mudanças", "a%.txt")
        panel.feed "<CR>"

        -- O lado esquerdo é como o arquivo estava antes do intervalo começar,
        -- e não como estava no commit anterior ao último.
        assert.same({ { "a v1" }, { "a v3" } }, diff.sides())
      end)

      it("marcam um arquivo do intervalo como visto", function()
        local repo = repo_with_a_series()

        open_in(repo.root)
        panel.feed "c"
        graph.choose_range("terceiro", "segundo")
        panel.focus("Mudanças", "a%.txt")
        panel.feed "v"

        assert.same({ "A  b.txt" }, panel.section "Mudanças")
        assert.equals(1, panel.section_count "Vistos")
      end)

      it("recusam mover para staged o que já está commitado", function()
        local repo = repo_with_a_series()
        repo:write("a.txt", "a v4\n")

        open_in(repo.root)
        panel.feed "c"
        graph.choose_range("terceiro", "segundo")
        panel.focus("Mudanças", "a%.txt")
        panel.feed "s"

        panel.feed "w"
        assert.same({ "M  a.txt" }, panel.section "Unstaged")
        assert.is_nil(panel.section_count "Staged")
      end)
    end)

    it("grava as anotações sob a revisão do intervalo", function()
      local repo = repo_with_a_series()
      local oldest = vim.trim(repo:git { "rev-parse", "HEAD~1" })
      local newest = vim.trim(repo:git { "rev-parse", "HEAD" })

      open_in(repo.root)
      panel.feed "c"
      graph.choose_range("terceiro", "segundo")
      input.answer "isto veio do intervalo"
      panel.focus("Mudanças", "a%.txt")
      panel.feed "a"

      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals(("range-%s..%s"):format(oldest, newest), annotations[1].mode)
    end)

    it("saem num relatório que diz o intervalo como o git o lê, com o commit mais antigo dentro", function()
      -- `a..b` deixaria o mais antigo de fora para quem lê git; o `^` é o que diz
      -- que ele entrou na revisão.
      local repo = repo_with_a_series()
      local oldest = vim.trim(repo:git { "rev-parse", "HEAD~1" })
      local newest = vim.trim(repo:git { "rev-parse", "HEAD" })

      open_in(repo.root)
      panel.feed "c"
      graph.choose_range("terceiro", "segundo")
      input.answer "isto veio do intervalo"
      panel.focus("Mudanças", "a%.txt")
      panel.feed "a"
      panel.feed "R"
      panel.feed "M"

      local expected = { root = repo.root, branch = "main", reference = ("%s^..%s"):format(oldest, newest) }
      assert.same(expected, report.header "xml")
      assert.same(expected, report.header "markdown")
    end)
  end)

  describe("o visto atravessa os modos", function()
    it("mostra como visto no working tree o conteúdo já visto num commit", function()
      -- O visto é do conteúdo, não do caminho (ADR-0002): é esta fatia que
      -- torna isso observável, porque é a primeira em que há dois modos.
      local repo = fixture.repo()
      repo:commit_file("commitado.txt", "mesmo texto\n", "commit com o texto")
      repo:write("nao-commitado.txt", "mesmo texto\n")

      open_in(repo.root)
      panel.feed "c"
      graph.choose "commit com o texto"
      panel.focus("Mudanças", "commitado%.txt")
      panel.feed "v"
      panel.feed "w"

      -- O arquivo do working tree saiu da sua seção sem que ninguém o marcasse:
      -- o texto dele é o que já foi lido no commit.
      assert.is_nil(panel.section_count "Untracked")
      assert.equals(1, panel.section_count "Vistos")
    end)
  end)

  describe("as anotações do modo commit", function()
    it("são da revisão daquele commit, e não da do working tree", function()
      local repo = repo_with_branches()
      repo:write("a.txt", "a v3\n")

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      input.answer "isto veio do commit"
      panel.focus("Mudanças", "a%.txt")
      panel.feed "a"

      -- A contagem na linha é do modo em que ela está: no working tree o mesmo
      -- arquivo não traz nenhuma.
      assert.is_not_nil(panel.line_matching "a%.txt  ✎ 1")
      panel.feed "w"
      assert.is_nil(panel.line_matching "a%.txt  ✎ 1")
    end)

    it("gravam em que commit foram escritas", function()
      local repo = repo_with_branches()
      local sha = vim.trim(repo:git { "rev-parse", "HEAD" })

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      input.answer "isto veio do commit"
      panel.focus("Mudanças", "a%.txt")
      panel.feed "a"

      local annotations = document.annotations()
      assert.equals(1, #annotations)
      assert.equals("commit-" .. sha, annotations[1].mode)
    end)

    it("saem num relatório que diz de que commit ele é, pelo sha inteiro e pelo assunto", function()
      -- O sha inteiro é o que nenhum commit posterior torna ambíguo para o
      -- agente.
      local repo = repo_with_branches()
      local sha = vim.trim(repo:git { "rev-parse", "HEAD" })

      open_in(repo.root)
      panel.feed "c"
      graph.choose "segundo"
      input.answer "isto veio do commit"
      panel.focus("Mudanças", "a%.txt")
      panel.feed "a"
      panel.feed "R"
      panel.feed "M"

      local expected = { root = repo.root, branch = "main", reference = sha .. " segundo" }
      assert.same(expected, report.header "xml")
      assert.same(expected, report.header "markdown")
      assert.equals("isto veio do commit", report.items("xml")[1].text)
      assert.is_not_nil(report.path("xml"):match "%-commit%-%x+%.xml$")
    end)
  end)
end)
