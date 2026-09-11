local diff = require "tests.helpers.diff"
local fixture = require "tests.helpers.fixture"
local menu = require "tests.helpers.menu"
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

---A repository with one changed file, which is enough for every line the mouse
---is pointed at here.
---@return table repo
local function repo_with_one_change()
  local repo = fixture.repo()
  repo:commit_file("a.txt", "v1\n")
  repo:write("a.txt", "v2\n")
  return repo
end

describe("mouse e descoberta das ações", function()
  before_each(function()
    review.setup {}
    fixture.data_dir()
  end)

  after_each(function()
    review.close()
    vim.cmd "tabfirst"
    vim.cmd "tabonly!"
    vim.cmd.cd(vim.fn.fnameescape(config_root))
    fixture.cleanup()
  end)

  describe("clique esquerdo", function()
    it("abre o diff do arquivo da linha clicada", function()
      local repo = repo_with_one_change()

      open_in(repo.root)
      panel.click("Unstaged", "a%.txt")

      assert.same({ { "v1" }, { "v2" } }, diff.sides())
    end)

    it("no cabeçalho da seção Vistos, mostra e esconde os arquivos dela", function()
      local repo = repo_with_one_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "v"

      panel.click_section "Vistos"
      assert.same({ "M  a.txt" }, panel.section "Vistos")

      panel.click_section "Vistos"
      assert.same({}, panel.section "Vistos")
    end)

    it("numa linha que não é arquivo não faz nada", function()
      local repo = repo_with_one_change()

      open_in(repo.root)
      panel.focus_header()

      assert.has_no.errors(function() panel.click_here() end)
      assert.same({}, diff.sides())
    end)
  end)

  describe("menu de contexto", function()
    it("mostra cada ação do painel junto do atalho dela", function()
      local repo = repo_with_one_change()

      open_in(repo.root)

      assert.same({
        ["<CR>"] = "Abrir o diff",
        ["d"] = "Abrir o diff alternativo",
        ["D"] = "Abrir as três versões do conflito",
        ["p"] = "Ligar ou desligar o preview",
        ["o"] = "Abrir o arquivo",
        ["O"] = "Abrir o arquivo num split",
        ["e"] = "Ver o arquivo em outro rev",
        ["E"] = "Comparar o arquivo com outro rev",
        ["v"] = "Marcar ou desmarcar como visto",
        ["<Space>"] = "Marcar como visto e ir à próxima",
        ["a"] = "Anotar o arquivo",
        ["A"] = "Anotar o arquivo em várias linhas",
        ["s"] = "Mover para staged",
        ["u"] = "Tirar de staged",
        ["X"] = "Descartar as mudanças",
        ["y"] = "Copiar o caminho relativo",
        ["Y"] = "Copiar o caminho absoluto",
        ["R"] = "Gerar o relatório em XML",
        ["M"] = "Gerar o relatório em markdown",
        ["U"] = "Reabrir a última entrega",
        ["c"] = "Abrir o grafo de commits",
        ["C"] = "Abrir o grafo alternativo",
        ["w"] = "Voltar ao working tree",
        ["g?"] = "Ver todas as teclas",
        ["r"] = "Atualizar",
        ["q"] = "Fechar o painel",
      }, menu.actions())
    end)

    it("mostra o atalho que o revisor configurou, e não o de fábrica", function()
      local repo = repo_with_one_change()
      review.setup { mappings = { toggle_seen = "<C-d>" } }

      open_in(repo.root)

      assert.is_truthy(menu.entry_matching "^Marcar ou desmarcar como visto%s+<C%-d>$")
    end)

    it("com o painel já aberto, o atalho que muda muda nos dois lugares", function()
      -- O menu existe para mostrar as teclas: uma entrada anunciando uma tecla
      -- que o painel não tem mais é pior do que menu nenhum.
      local repo = repo_with_one_change()
      open_in(repo.root)

      review.setup { mappings = { toggle_seen = "V" } }
      panel.focus("Unstaged", "a%.txt")
      panel.feed "o"
      local win = assert(panel.win(), "o painel não está aberto")
      vim.api.nvim_set_current_win(win)

      assert.is_truthy(menu.entry_matching "^Marcar ou desmarcar como visto%s+V$")
      panel.focus("Unstaged", "a%.txt")
      panel.feed "V"
      assert.equals(1, panel.section_count "Vistos")
    end)

    it("uma entrada do menu faz o que a tecla dela faz", function()
      local repo = repo_with_one_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      menu.choose "^Marcar ou desmarcar como visto"

      assert.same({}, panel.section "Unstaged")
      assert.equals(1, panel.section_count "Vistos")
    end)

    it("some ao sair do painel, e não polui o menu de outro buffer", function()
      local repo = repo_with_one_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "o"

      assert.same({}, menu.actions())
    end)

    it("volta ao entrar de novo no painel", function()
      local repo = repo_with_one_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "o"
      local win = assert(panel.win(), "o painel não está aberto")
      vim.api.nvim_set_current_win(win)

      assert.is_truthy(menu.entry_matching "^Abrir o diff%s+<CR>$")
    end)

    it("some quando o painel fecha", function()
      local repo = repo_with_one_change()

      open_in(repo.root)
      panel.feed "q"

      assert.same({}, menu.actions())
    end)
  end)

  describe("descoberta pelo teclado", function()
    it("toda tecla do painel tem descrição, que é o que o which-key mostra", function()
      local repo = repo_with_one_change()

      open_in(repo.root)
      local win = assert(panel.win(), "o painel não está aberto")
      local bufnr = vim.api.nvim_win_get_buf(win)

      local mappings = vim.api.nvim_buf_get_keymap(bufnr, "n")
      local undescribed = {}
      for _, mapping in ipairs(mappings) do
        if not mapping.desc or mapping.desc == "" then undescribed[#undescribed + 1] = mapping.lhs end
      end

      assert.is_true(#mappings > 0)
      assert.same({}, undescribed)
    end)
  end)
end)
