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

---Paths compare only after resolving: the fixture lives under a temporary
---directory, which is a symlink on some machines.
---@param path string
---@return string
local function resolved(path) return vim.fn.resolve(path) end

---Open the panel on `dir` in a tabpage of its own, the way a reviewer with one
---repository per tab does it: a new tabpage with its own `:tcd`.
---@param dir string
local function open_in_new_tab(dir)
  vim.cmd "tabnew"
  vim.cmd.tcd(vim.fn.fnameescape(dir))
  review.open()
end

---Close every window of the tabpage but the panel, leaving it as the only
---window on screen.
local function leave_the_panel_alone()
  local win = assert(panel.win(), "the review panel is not open")
  for _, other in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if other ~= win then pcall(vim.api.nvim_win_close, other, true) end
  end
end

---Leave the editor with a single tabpage, back on the configuration's own
---directory: a tabpage local directory outlives the test that set it.
local function reset_tabs()
  vim.cmd "tabonly!"
  vim.cmd.cd(vim.fn.fnameescape(config_root))
end

describe("painel de revisão", function()
  before_each(function() review.setup {} end)

  after_each(function()
    review.close()
    reset_tabs()
    fixture.cleanup()
  end)

  describe("abrir e fechar", function()
    it("abre o painel e fecha com a tecla do painel", function()
      local repo = fixture.repo()

      open_in(repo.root)
      assert.is_true(panel.is_open())

      panel.feed "q"
      assert.is_false(panel.is_open())
    end)

    it("abrir duas vezes não empilha painéis", function()
      local repo = fixture.repo()

      open_in(repo.root)
      review.open()

      local panels = vim.tbl_filter(
        function(win) return vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "review" end,
        vim.api.nvim_tabpage_list_wins(0)
      )
      assert.equals(1, #panels)
    end)

    it("fecha com a tecla do painel mesmo sendo a única janela", function()
      local repo = fixture.repo()

      open_in(repo.root)
      leave_the_panel_alone()

      panel.feed "q"

      assert.is_false(panel.is_open())
    end)

    it("fecha sendo a única janela sem levar a aba junto", function()
      -- Fechar a última janela de uma aba fecha a aba com ela — e leva o `:tcd`
      -- do repositório junto. O revisor pediu para o painel sair, não a aba.
      local repo = fixture.repo()

      open_in_new_tab(repo.root)
      leave_the_panel_alone()
      local tabs = #vim.api.nvim_list_tabpages()

      panel.feed "q"

      assert.is_false(panel.is_open())
      assert.equals(tabs, #vim.api.nvim_list_tabpages())
      assert.equals(resolved(repo.root), resolved(vim.fn.getcwd()))
    end)

    it("devolve uma janela comum ao fechar sendo a única janela", function()
      -- Sozinho na aba o painel solta a janela em vez de fechá-la, e é nela que
      -- o revisor vai abrir os arquivos depois: ela não pode ficar com a
      -- aparência do painel — sem número de linha, de largura travada.
      local repo = fixture.repo()
      vim.wo[vim.api.nvim_get_current_win()].number = true

      open_in(repo.root)
      local win = assert(panel.win(), "o painel não abriu")
      leave_the_panel_alone()

      panel.feed "q"

      assert.is_true(vim.api.nvim_win_is_valid(win))
      assert.is_true(vim.wo[win].number)
      assert.is_false(vim.wo[win].winfixwidth)
      vim.wo[win].number = false
    end)

    it("torna a abrir com o toggle depois de fechar sendo a única janela", function()
      -- Um fechamento que falha em silêncio deixa o toggle preso no ramo de
      -- fechar: o painel continua na tela e a tecla vira um no-op.
      local repo = fixture.repo()

      open_in(repo.root)
      leave_the_panel_alone()

      review.toggle()
      assert.is_false(panel.is_open())

      review.toggle()
      assert.is_true(panel.is_open())
    end)
  end)

  describe("uma aba por repositório", function()
    it("mantém em cada aba o painel do repositório daquela aba", function()
      local a = fixture.repo()
      a:write("de-a.txt", "novo\n")
      local b = fixture.repo()
      b:write("de-b.txt", "novo\n")

      open_in_new_tab(a.root)
      assert.same({ "?  de-a.txt" }, panel.section "Untracked")

      open_in_new_tab(b.root)
      assert.same({ "?  de-b.txt" }, panel.section "Untracked")

      vim.cmd "tabprevious"
      assert.same({ "?  de-a.txt" }, panel.section "Untracked")
    end)

    it("abre o arquivo da entrada no repositório da própria aba", function()
      -- O mapa de linha para entrada acompanha o painel: numa aba que compartilha
      -- o mapa com outra, a tecla abre o arquivo do repositório errado.
      local a = fixture.repo()
      a:write("de-a.txt", "novo\n")
      local b = fixture.repo()
      b:write("de-b.txt", "novo\n")

      open_in_new_tab(a.root)
      open_in_new_tab(b.root)

      vim.cmd "tabprevious"
      panel.focus("Untracked", "de%-a")
      panel.feed "o"

      assert.equals(resolved(a.root .. "/de-a.txt"), resolved(vim.api.nvim_buf_get_name(0)))
    end)
  end)

  describe("seções do working tree", function()
    it("separa staged, unstaged e untracked pelo estado real do repositório", function()
      local repo = fixture.repo()
      repo:commit_file("so-staged.txt", "v1\n")
      repo:commit_file("so-unstaged.txt", "v1\n")
      repo:write("so-staged.txt", "v2\n")
      repo:add "so-staged.txt"
      repo:write("so-unstaged.txt", "v2\n")
      repo:write("nao-rastreado.txt", "novo\n")

      open_in(repo.root)

      assert.same({ "M  so-staged.txt" }, panel.section "Staged")
      assert.same({ "M  so-unstaged.txt" }, panel.section "Unstaged")
      assert.same({ "?  nao-rastreado.txt" }, panel.section "Untracked")
      assert.is_nil(panel.section_count "Conflitos")
    end)

    it("mostra nas duas seções o arquivo com mudança staged e unstaged", function()
      local repo = fixture.repo()
      repo:commit_file("dois.txt", "v1\n")
      repo:write("dois.txt", "v2\n")
      repo:add "dois.txt"
      repo:write("dois.txt", "v3\n")

      open_in(repo.root)

      assert.same({ "M  dois.txt" }, panel.section "Staged")
      assert.same({ "M  dois.txt" }, panel.section "Unstaged")
    end)

    it("mostra o arquivo renomeado com o caminho novo, numa linha só", function()
      local repo = fixture.repo()
      repo:commit_file("antigo.txt", "uma linha longa o bastante para o git enxergar a renomeação\n")
      repo:git { "mv", "antigo.txt", "novo.txt" }

      open_in(repo.root)

      assert.same({ "R  novo.txt" }, panel.section "Staged")
      assert.is_nil(panel.line_matching "antigo")
    end)

    it("não lê o caminho antigo de uma renomeação como se fosse outro arquivo", function()
      -- O caminho antigo vem num campo separado do registro de renomeação. Um
      -- parser que não o consome como tal o lê como o próximo registro — e um
      -- caminho antigo que começa como um registro de verdade vira, aí, um
      -- arquivo fantasma na lista.
      local repo = fixture.repo()
      repo:commit_file("? antigo.txt", "uma linha longa o bastante para o git enxergar a renomeação\n")
      repo:git { "mv", "? antigo.txt", "novo.txt" }
      repo:write("novo.txt", "uma linha longa o bastante para o git enxergar a renomeação\nmais uma\n")

      open_in(repo.root)

      assert.same({ "R  novo.txt" }, panel.section "Staged")
      assert.same({ "M  novo.txt" }, panel.section "Unstaged")
      assert.is_nil(panel.section_count "Untracked")
      assert.is_nil(panel.line_matching "antigo")
    end)

    it("lista os arquivos de um diretório novo, e não o diretório", function()
      -- O padrão do git colapsa um diretório inteiro numa linha `src/`. Numa
      -- lista de revisão isso mente na contagem e dá uma linha que não é um
      -- arquivo para abrir.
      local repo = fixture.repo()
      repo:write("src/um.txt", "novo\n")
      repo:write("src/dois.txt", "novo\n")

      open_in(repo.root)

      assert.same({ "?  src/dois.txt", "?  src/um.txt" }, panel.section "Untracked")
      assert.equals(2, panel.section_count "Untracked")
    end)

    it("não estoura com um caminho que tem quebra de linha", function()
      -- `-z` entrega os caminhos crus, e um caminho com \n quebraria a
      -- renderização em duas linhas — ou, pior, o próprio open().
      local repo = fixture.repo()
      repo:write("a\nb.txt", "novo\n")

      assert.has_no.errors(function() open_in(repo.root) end)

      assert.same({ "?  a\\nb.txt" }, panel.section "Untracked")
    end)

    it("mostra o arquivo deletado, no lado em que ele foi deletado", function()
      local repo = fixture.repo()
      repo:commit_file("apagado.txt", "x\n")
      repo:commit_file("removido.txt", "x\n")
      repo:delete "apagado.txt"
      repo:git { "rm", "removido.txt" }

      open_in(repo.root)

      assert.same({ "D  apagado.txt" }, panel.section "Unstaged")
      assert.same({ "D  removido.txt" }, panel.section "Staged")
    end)

    it("mostra o arquivo conflitado numa seção própria, antes das outras", function()
      local repo = fixture.repo()
      repo:conflict "conflito.txt"

      open_in(repo.root)

      assert.same({ "UU conflito.txt" }, panel.section "Conflitos")

      local lines = panel.lines()
      local conflitos, staged
      for index, line in ipairs(lines) do
        if line:match "^Conflitos" then conflitos = index end
        if line:match "^Unstaged" or line:match "^Staged" then staged = staged or index end
      end
      assert.is_not_nil(conflitos)
      if staged then assert.is_true(conflitos < staged) end
    end)
  end)

  describe("cabeçalho e contagens", function()
    it("mostra a branch atual no cabeçalho", function()
      local repo = fixture.repo()

      open_in(repo.root)

      assert.equals("Revisão · main", panel.lines()[1])
    end)

    it("traz na segunda linha os totais de linhas do working tree, esmaecidos", function()
      -- Revisar o próprio working tree e revisar o commit de outra pessoa são
      -- dois trabalhos com fins diferentes: as teclas continuam as mesmas
      -- (ADR-0001), e o que muda é o que o painel informa.
      local repo = fixture.repo()
      repo:commit_file("a.txt", "um\ndois\ntrês\n")
      repo:write("a.txt", "um\ndois\ntrês\nquatro\n")
      repo:write("b.txt", "novo\n")
      repo:add "b.txt"

      open_in(repo.root)

      assert.equals("+2 −0", panel.lines()[2])
      assert.is_true(panel.is_dimmed "^%+2 −0$")
    end)

    it("conta as duas mudanças do arquivo que está staged e unstaged", function()
      -- Os totais contam mudanças, e não arquivos, como as seções e o
      -- `N/M vistos` contam: uma mudança staged e uma unstaged no mesmo arquivo
      -- são dois diffs para ler, e o cabeçalho diz o tamanho dos dois.
      local repo = fixture.repo()
      repo:commit_file("a.txt", "um\n")
      repo:write("a.txt", "um\ndois\n")
      repo:add "a.txt"
      repo:write("a.txt", "um\ndois\ntrês\n")

      open_in(repo.root)

      assert.equals("Revisão · main · 0/2 vistos", panel.lines()[1])
      assert.equals("+2 −0", panel.lines()[2])
    end)

    it("traz a linha de informação mesmo sem nenhuma mudança", function()
      local repo = fixture.repo()

      open_in(repo.root)

      assert.equals("+0 −0", panel.lines()[2])
    end)

    it("conta os arquivos de cada seção", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "v1\n")
      repo:commit_file("b.txt", "v1\n")
      repo:write("a.txt", "v2\n")
      repo:add "a.txt"
      repo:write("b.txt", "v2\n")
      repo:write("c.txt", "novo\n")
      repo:write("d.txt", "novo\n")

      open_in(repo.root)

      assert.equals(1, panel.section_count "Staged")
      assert.equals(1, panel.section_count "Unstaged")
      assert.equals(2, panel.section_count "Untracked")
    end)
  end)

  describe("mensagens em vez de erro", function()
    it("abre com mensagem fora de um repositório", function()
      local dir = fixture.plain_dir()

      assert.has_no.errors(function() open_in(dir) end)

      assert.is_true(panel.is_open())
      assert.is_not_nil(panel.line_matching "Fora de um repositório git")
    end)

    it("abre com mensagem num repositório sem commits, ainda listando o que há", function()
      local repo = fixture.repo_without_commits()
      repo:write("nao-rastreado.txt", "novo\n")

      assert.has_no.errors(function() open_in(repo.root) end)

      assert.is_not_nil(panel.line_matching "Repositório sem commits")
      assert.same({ "?  nao-rastreado.txt" }, panel.section "Untracked")
    end)

    it("abre com mensagem quando não há nenhuma mudança", function()
      local repo = fixture.repo()

      open_in(repo.root)

      assert.is_not_nil(panel.line_matching "Nenhuma mudança")
    end)
  end)

  describe("atualizar", function()
    it("relê o estado do git com a tecla de atualizar", function()
      local repo = fixture.repo()

      open_in(repo.root)
      assert.is_nil(panel.section_count "Untracked")

      repo:write("apareceu.txt", "novo\n")
      panel.feed "r"

      assert.same({ "?  apareceu.txt" }, panel.section "Untracked")
    end)
  end)

  describe("posição e largura", function()
    it("respeita a largura configurada", function()
      local repo = fixture.repo()
      review.setup { width = 55 }

      open_in(repo.root)

      assert.equals(55, panel.width())
    end)

    it("abre à esquerda por padrão e à direita quando configurado", function()
      local repo = fixture.repo()

      open_in(repo.root)
      assert.equals(0, vim.api.nvim_win_get_position(panel.win())[2])
      review.close()

      review.setup { position = "right" }
      review.open()
      assert.is_true(vim.api.nvim_win_get_position(panel.win())[2] > 0)
    end)
  end)

  describe("a janela do painel", function()
    ---Abre o painel e o arquivo mudado ao lado dele: a lista de um lado, o que
    ---o revisor está lendo do outro, que é o arranjo em que a revisão acontece.
    ---@param repo table o repositório do fixture
    ---@return integer winid da janela de conteúdo
    local function open_beside_a_file(repo)
      repo:commit_file("a.txt", "v1\n")
      repo:write("a.txt", "v2\n")
      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "o"
      return vim.api.nvim_get_current_win()
    end

    ---Mais uma janela do lado do painel, para haver o que fechar: é o fechar
    ---de uma janela que faz o painel conferir a largura dele.
    ---@param win integer winid da janela a dividir
    ---@return integer winid da janela nova
    local function split_below(win)
      return vim.api.nvim_open_win(vim.api.nvim_win_get_buf(win), false, { split = "below", win = win })
    end

    ---@return integer bufnr do painel aberto
    local function panel_buf()
      local win = assert(panel.win(), "o painel não abriu")
      return vim.api.nvim_win_get_buf(win)
    end

    after_each(editor.reset)

    it("devolve a janela de conteúdo ao arquivo quando o buffer do painel aparece nela", function()
      -- É o que o `<C-^>`, um seletor de arquivos ou qualquer plugin que
      -- escolha "a última janela usada" faz: põe o buffer do painel na janela
      -- grande, e o revisor fica com a lista tomando a tela.
      local repo = fixture.repo()
      local content = open_beside_a_file(repo)
      local file = vim.api.nvim_win_get_buf(content)
      local win = assert(panel.win(), "o painel não abriu")

      vim.api.nvim_win_set_buf(content, panel_buf())

      assert.equals(file, vim.api.nvim_win_get_buf(content))
      assert.equals(win, panel.win())
    end)

    it("não fecha a janela de conteúdo com a tecla que fecha o painel", function()
      -- Com o buffer do painel na janela grande, era ela que as ações do painel
      -- elegiam como painel — o `q` fechava a janela de trabalho do revisor.
      local repo = fixture.repo()
      local content = open_beside_a_file(repo)

      vim.api.nvim_win_set_buf(content, panel_buf())
      panel.feed "q"

      assert.is_false(panel.is_open())
      assert.is_true(vim.api.nvim_win_is_valid(content))
    end)

    it("não deixa uma divisão da janela do painel virar um segundo painel", function()
      -- Dividir uma janela mostra o mesmo buffer na nova sem nunca exibi-lo, e
      -- a lista aparecia nas duas: `win_of` só responde uma, e o `q` fechava
      -- essa, deixando a outra na tela.
      local repo = fixture.repo()
      open_beside_a_file(repo)
      local win = assert(panel.win(), "o painel não abriu")
      local bufnr = panel_buf()

      panel.feed "<C-w>s"

      local showing = vim.tbl_filter(
        function(other) return vim.api.nvim_win_get_buf(other) == bufnr end,
        vim.api.nvim_tabpage_list_wins(0)
      )
      assert.same({ win }, showing)
    end)

    it("não deixa outro buffer tomar a janela do painel", function()
      local repo = fixture.repo()
      open_in(repo.root)
      local win = assert(panel.win(), "o painel não abriu")
      local bufnr = vim.api.nvim_win_get_buf(win)
      local other = vim.api.nvim_create_buf(true, false)

      local shown = pcall(vim.api.nvim_win_set_buf, win, other)
      local emptied = pcall(vim.api.nvim_win_call, win, function() vim.cmd "enew" end)

      assert.is_false(shown)
      assert.is_false(emptied)

      assert.equals(bufnr, vim.api.nvim_win_get_buf(win))
      vim.api.nvim_buf_delete(other, { force = true })
    end)

    it("volta à largura dele quando o layout a muda sem o revisor pedir", function()
      -- Alargar a janela ao lado espreme o painel: o `winfixwidth` segura a
      -- largura quando uma janela abre ou fecha, e não quando outra é
      -- redimensionada por cima dele.
      local repo = fixture.repo()
      local content = open_beside_a_file(repo)
      local split = split_below(content)

      vim.api.nvim_win_set_width(content, vim.o.columns - 10)
      vim.api.nvim_win_close(split, true)

      vim.wait(200, function() return panel.width() == 40 end)
      assert.equals(40, panel.width())
    end)

    it("mantém a largura que o revisor deu ao painel", function()
      -- Alargar o painel com ele focado é gesto do revisor: é essa largura que
      -- volta depois de um acidente de layout, e não a configurada.
      --
      -- O `WinResized` é disparado à mão: o editor só o dispara no laço
      -- principal, esperando uma tecla, e um editor headless nunca chega lá —
      -- nem redimensionando por API, nem pelas teclas de redimensionar. O gesto
      -- é o do revisor; o que se afirma é a largura que fica na tela depois.
      local repo = fixture.repo()
      local content = open_beside_a_file(repo)

      panel.feed "<C-w>15<"
      vim.cmd "doautocmd WinResized"
      assert.equals(25, panel.width())

      vim.api.nvim_set_current_win(content)
      local split = split_below(content)
      vim.api.nvim_win_set_width(content, vim.o.columns - 10)
      vim.api.nvim_win_close(split, true)

      vim.wait(200, function() return panel.width() == 25 end)
      assert.equals(25, panel.width())
    end)
  end)

  describe("convivência com o neo-tree", function()
    ---A janela lateral que o neo-tree ocuparia. Ganha um buffer próprio: um
    ---`vsplit` puro herdaria o buffer atual, e marcá-lo como "neo-tree"
    ---deixaria a marca colada nele para todos os testes seguintes.
    ---@return integer winid
    local function fake_neo_tree()
      vim.cmd "topleft vnew"
      local win = vim.api.nvim_get_current_win()
      vim.bo[vim.api.nvim_win_get_buf(win)].filetype = "neo-tree"
      return win
    end

    it("fecha a janela do neo-tree ao abrir, para não disputar o espaço", function()
      local repo = fixture.repo()
      local neotree_win = fake_neo_tree()

      open_in(repo.root)

      assert.is_false(vim.api.nvim_win_is_valid(neotree_win))
      assert.is_true(panel.is_open())
    end)

    it("deixa o neo-tree em paz quando configurado para ignorá-lo", function()
      local repo = fixture.repo()
      review.setup { neo_tree = "ignore" }
      local neotree_win = fake_neo_tree()

      open_in(repo.root)

      assert.is_true(vim.api.nvim_win_is_valid(neotree_win))
      vim.api.nvim_win_close(neotree_win, true)
    end)
  end)
end)
