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

---Three lines, which is enough for a change to add some and remove others.
local THREE_LINES = "um\ndois\ntrês\n"

describe("a linha do painel", function()
  before_each(function() review.setup {} end)

  after_each(function()
    review.close()
    vim.fn.chdir(config_root)
    fixture.cleanup()
  end)

  describe("o ícone do arquivo", function()
    it("é o que o mini.icons responde para aquele caminho", function()
      -- Comparado com o que o mini.icons responde, e não com um glifo escrito
      -- aqui: o glifo é dele, e muda quando ele muda.
      local repo = fixture.repo()
      repo:write("a.lua", "local x = 1\n")
      repo:write("b.py", "x = 1\n")

      open_in(repo.root)

      local lua_icon = _G.MiniIcons.get("file", "a.lua")
      local py_icon = _G.MiniIcons.get("file", "b.py")
      assert.is_not_nil(panel.line_matching("^  " .. vim.pesc(lua_icon) .. " %?  a%.lua$"))
      assert.is_not_nil(panel.line_matching("^  " .. vim.pesc(py_icon) .. " %?  b%.py$"))
    end)

    it("é desenhado na cor que o mini.icons dá a ele", function()
      local repo = fixture.repo()
      repo:write("a.lua", "local x = 1\n")

      open_in(repo.root)

      local icon, group = _G.MiniIcons.get("file", "a.lua")
      assert.equals(group, panel.highlights("a%.lua")[icon])
    end)

    it("sem o mini.icons, a linha fica sem ele em vez de o painel quebrar", function()
      -- O painel não ganha dependência dura por causa de um glifo: sem ele a
      -- linha volta a ser o que era, com o código e o caminho.
      --
      -- O global é devolvido aconteça o que acontecer: deixá-lo nil levaria a
      -- ausência do mini.icons para todos os testes seguintes, que afirmam
      -- sobre uma tela com ícone. Lido pelas linhas cruas, e não pelo helper —
      -- é ele que tira a coluna que aqui não existe.
      local repo = fixture.repo()
      repo:write("a.txt", "novo\n")
      local icons = _G.MiniIcons
      _G.MiniIcons = nil

      local ok, line = pcall(function()
        open_in(repo.root)
        return panel.line_matching "a%.txt"
      end)
      _G.MiniIcons = icons

      assert.is_true(ok, tostring(line))
      assert.equals("  ?  a.txt", line)
    end)
  end)

  describe("o código do porcelain", function()
    it("continua na linha, colorido pelo tipo de mudança", function()
      -- As letras não saem com a chegada do ícone: `R `, `MM` e `??` dizem
      -- coisas que um ícone sozinho não diz.
      local repo = fixture.repo()
      repo:commit_file("mudado.txt", "v1\n")
      repo:commit_file("apagado.txt", "v1\n")
      repo:write("mudado.txt", "v2\n")
      repo:delete "apagado.txt"
      repo:write("novo.txt", "novo\n")

      open_in(repo.root)

      assert.equals("Changed", panel.highlights("mudado%.txt").M)
      assert.equals("Removed", panel.highlights("apagado%.txt").D)
      assert.equals("Added", panel.highlights("novo%.txt")["?"])
    end)

    it("mostra o código de duas letras de um conflito, em erro", function()
      local repo = fixture.repo()
      repo:conflict "conflito.txt"

      open_in(repo.root)

      assert.same({ "UU conflito.txt" }, panel.section "Conflitos")
      assert.equals("ErrorMsg", panel.highlights("conflito%.txt").UU)
    end)

    it("colore o arquivo que entrou no índice como adicionado", function()
      local repo = fixture.repo()
      repo:write("novo.txt", "novo\n")
      repo:add "novo.txt"

      open_in(repo.root)

      assert.equals("Added", panel.highlights("novo%.txt").A)
    end)
  end)

  describe("o +N −M da linha", function()
    it("traz quantas linhas a mudança pôs e tirou, dos dois lados do índice", function()
      local repo = fixture.repo()
      repo:commit_file("staged.txt", THREE_LINES)
      repo:commit_file("unstaged.txt", THREE_LINES)
      repo:write("staged.txt", "um\ndois\ntrês\nquatro\n")
      repo:add "staged.txt"
      repo:write("unstaged.txt", "um\n")

      open_in(repo.root)

      assert.equals("+1 −0", panel.numbers "staged%.txt")
      assert.equals("+0 −2", panel.numbers "unstaged%.txt")
    end)

    it("é desenhado à direita, sem empurrar o caminho da linha", function()
      -- Virtual text alinhado à direita: um caminho longo empurra os números
      -- para fora do painel, e não o nome do arquivo.
      local repo = fixture.repo()
      repo:commit_file("um/caminho/bem/comprido/para/o/painel.txt", THREE_LINES)
      repo:write("um/caminho/bem/comprido/para/o/painel.txt", "um\n")

      open_in(repo.root)

      assert.same({ "M  um/caminho/bem/comprido/para/o/painel.txt" }, panel.section "Unstaged")
      assert.equals("+0 −2", panel.numbers "painel%.txt")
    end)

    it("continua na linha do arquivo já visto, esmaecido junto com ela", function()
      -- Quão grande é uma mudança não deixa de ser verdade depois de lida; o
      -- que muda é a cor, que segue o esmaecido do resto da linha.
      fixture.data_dir()
      review.setup { seen_display = "dimmed" }
      local repo = fixture.repo()
      repo:commit_file("a.txt", THREE_LINES)
      repo:write("a.txt", "um\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "v"

      assert.same({ "M  a.txt" }, panel.dimmed())
      assert.equals("+0 −2", panel.numbers "a%.txt")
    end)

    it("deixa untracked e conflito sem números, de propósito", function()
      -- Contar as linhas de um untracked custaria um processo por arquivo, e um
      -- conflito não tem duas vias para comparar. Ausência é honesta; número
      -- inventado não.
      local repo = fixture.repo()
      repo:conflict "conflito.txt"
      repo:write("nao-rastreado.txt", THREE_LINES)

      open_in(repo.root)

      assert.is_nil(panel.numbers "conflito%.txt")
      assert.is_nil(panel.numbers "nao%-rastreado%.txt")
    end)

    it("deixa o arquivo binário sem números, que é o que o numstat diz dele", function()
      local repo = fixture.repo()
      repo:commit_file("bin.dat", "\0\1\2\n")
      repo:write("bin.dat", "\0\1\2\3\n")

      open_in(repo.root)

      assert.same({ "M  bin.dat" }, panel.section "Unstaged")
      assert.is_nil(panel.numbers "bin%.dat")
    end)

    it("não se perde com a renomeação, que o numstat -z escreve em três campos", function()
      -- `add\tdel\t\0antigo\0novo\0`: os dois caminhos vêm em campos próprios e
      -- precisam ser consumidos como parte do registro. Lidos como registros
      -- soltos, corrompem tudo o que vier depois.
      local repo = fixture.repo()
      repo:commit_file("antigo.txt", THREE_LINES)
      repo:commit_file("depois.txt", THREE_LINES)
      repo:git { "mv", "antigo.txt", "novo.txt" }
      repo:write("novo.txt", THREE_LINES .. "quatro\n")
      repo:add "novo.txt"
      repo:write("depois.txt", "um\n")
      repo:add "depois.txt"

      open_in(repo.root)

      assert.same({ "M  depois.txt", "R  novo.txt" }, panel.section "Staged")
      assert.equals("+1 −0", panel.numbers "novo%.txt")
      assert.equals("+0 −2", panel.numbers "depois%.txt")
    end)
  end)

  describe("o +N −M nos outros modos", function()
    before_each(function() fixture.data_dir() end)

    ---Uma história em linha, para haver commit e intervalo para revisar.
    ---@return FixtureRepo
    local function repo_with_a_series()
      local repo = fixture.repo()
      repo:commit_file("a.txt", THREE_LINES, "primeiro")
      repo:write("a.txt", "um\ndois\ntrês\nquatro\n")
      repo:add "a.txt"
      repo:commit "segundo"
      repo:write("a.txt", "um\ndois\ntrês\nquatro\ncinco\n")
      repo:write("b.txt", "b\n")
      repo:add("a.txt", "b.txt")
      repo:commit "terceiro"
      return repo
    end

    it("traz os números do commit em revisão", function()
      local repo = repo_with_a_series()

      open_in(repo.root)
      panel.feed "c"
      graph.choose "terceiro"

      assert.equals("+1 −0", panel.numbers "a%.txt")
      assert.equals("+1 −0", panel.numbers "b%.txt")
    end)

    it("traz os números do intervalo inteiro, e não os do último commit", function()
      local repo = repo_with_a_series()

      open_in(repo.root)
      panel.feed "c"
      graph.choose_range("terceiro", "segundo")

      assert.equals("+2 −0", panel.numbers "a%.txt")
    end)
  end)
end)
