local diff = require "tests.helpers.diff"
local editor = require "tests.helpers.editor"
local fixture = require "tests.helpers.fixture"
local help = require "tests.helpers.help"
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

---A key as the editor writes it back, so the key the configuration spells and
---the key the mapping table lists compare equal.
---@param key string
---@return string
local function spelled(key) return vim.fn.keytrans(vim.keycode(key)) end

---@return integer bufnr the buffer of the panel of this tabpage
local function panel_buffer()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local bufnr = vim.api.nvim_win_get_buf(win)
    if vim.bo[bufnr].filetype == "review" then return bufnr end
  end
  error "o painel não está na tela"
end

describe("ajuda das teclas", function()
  before_each(function()
    review.setup {}
    fixture.data_dir()
  end)

  after_each(function()
    editor.reset()
    vim.cmd.cd(vim.fn.fnameescape(config_root))
    fixture.cleanup()
  end)

  describe("no painel", function()
    it("lista cada tecla do painel com a descrição que o which-key mostra", function()
      -- A lista sai da mesma de onde as teclas são mapeadas: o que se afirma é
      -- que as duas dizem a mesma coisa, tecla por tecla.
      local repo = repo_with_a_change()

      open_in(repo.root)
      local described = {}
      for _, map in ipairs(vim.api.nvim_buf_get_keymap(panel_buffer(), "n")) do
        -- O clique repete uma tecla em vez de somar uma ação, e não se aperta.
        if map.desc and spelled(map.lhs) ~= "<LeftRelease>" then described[spelled(map.lhs)] = map.desc end
      end
      panel.feed "g?"

      assert.equals("Teclas do painel", help.title())
      local listed = {}
      for key, desc in pairs(help.keys()) do
        listed[spelled(key)] = desc
      end
      assert.same(described, listed)
    end)

    it("fecha no q e devolve o cursor ao painel", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.feed "g?"
      help.feed "q"

      assert.is_false(help.is_open())
      assert.equals("review", vim.bo.filetype)
    end)

    it("fecha na mesma tecla que a abriu", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.feed "g?"
      help.feed "g?"

      assert.is_false(help.is_open())
    end)

    it("a winbar do painel escreve a tecla que mostra todas as outras, e segue a configurada", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      assert.matches("ver todas as teclas%s+g%?", vim.wo[panel.win()].winbar)

      review.setup { mappings = { help = "<F1>" } }
      review.refresh()

      assert.matches("ver todas as teclas%s+<F1>", vim.wo[panel.win()].winbar)
    end)
  end)

  describe("no diff", function()
    it("lista as teclas que a winbar não escreve, e as globais", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      diff.feed "g?"

      assert.equals("Teclas do diff", help.title())
      local keys = help.keys()
      for _, key in ipairs {
        "q",
        "g?",
        "go",
        "]c",
        "[c",
        "]f",
        "[f",
        "]F",
        "[F",
        "<Leader>ga",
        "<Leader>gA",
        "<Leader>gv",
      } do
        assert.is_not_nil(keys[key], ("a ajuda do diff não lista %s"):format(key))
      end
    end)

    it("fecha no q e devolve o cursor ao diff", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      diff.feed "g?"
      help.feed "q"

      assert.is_false(help.is_open())
      assert.is_true(diff.focused())
    end)

    it("lista a tecla de visto que está mapeada, também quando o revisor a troca", function()
      review.setup { mappings = { seen_and_open_next = "<Leader>m" } }
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"
      diff.feed "g?"

      local keys = help.keys()
      assert.is_not_nil(keys["<Leader>m"])
      assert.is_nil(keys["<Leader>gv"])
      assert.equals("", vim.fn.maparg("<Leader>gv", "n"))
      assert.is_not.equals("", vim.fn.maparg("<Leader>m", "n"))
    end)
  end)

  describe("a winbar do diff", function()
    it("escreve só a tecla que fecha e a que mostra as outras", function()
      local repo = repo_with_a_change()

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "<CR>"

      local bars = diff.winbars()
      assert.matches("fechar%s+q%s+ajuda%s+g%?", bars[#bars])
      -- O resto está na ajuda, a uma tecla: a barra que não cabe na janela
      -- perde as teclas, às vezes todas.
      for _, gone in ipairs { "o arquivo", "mudança", "não vista", "todas", "anotar" } do
        assert.is_not.matches(gone, bars[#bars])
      end
      assert.is_not.matches("ajuda", bars[1])
    end)
  end)
end)
