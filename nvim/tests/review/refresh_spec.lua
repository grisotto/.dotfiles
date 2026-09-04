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

describe("o painel se atualiza sozinho", function()
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

  it("quando um arquivo é salvo no editor", function()
    local repo = fixture.repo()
    repo:commit_file("a.txt", "a v1\n")

    open_in(repo.root)
    assert.is_not_nil(panel.line_matching "Nenhuma mudança")

    -- O revisor abre o arquivo ao lado do painel, mexe nele e salva. Nenhuma
    -- tecla do painel é pressionada depois disso.
    vim.cmd("botright vsplit " .. vim.fn.fnameescape(repo.root .. "/a.txt"))
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a v2" })
    vim.cmd.write()

    assert.same({ "M  a.txt" }, panel.section "Unstaged")
  end)

  it("mas não quando o arquivo salvo é de fora do repositório", function()
    -- Ler um repositório são cinco processos do git, e um arquivo que não é
    -- dele não muda uma linha da lista.
    local repo = fixture.repo()
    repo:commit_file("a.txt", "a v1\n")
    local outside = fixture.plain_dir()

    open_in(repo.root)
    local calls = fixture.trace_git()

    vim.cmd("botright vsplit " .. vim.fn.fnameescape(outside .. "/rascunho.txt"))
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "nada a ver" })
    vim.cmd.write()

    assert.same({}, calls())
  end)

  it("quando o editor volta ao foco", function()
    local repo = fixture.repo()
    repo:commit_file("a.txt", "a v1\n")

    open_in(repo.root)
    assert.is_not_nil(panel.line_matching "Nenhuma mudança")

    -- Mexido fora do editor, que é o caso em que a lista envelhece sem o
    -- editor ficar sabendo.
    repo:write("a.txt", "a v2\n")
    vim.api.nvim_exec_autocmds("FocusGained", {})

    assert.same({ "M  a.txt" }, panel.section "Unstaged")
  end)

  it("e não estoura ao salvar um arquivo com o painel fechado", function()
    local repo = fixture.repo()
    repo:commit_file("a.txt", "a v1\n")

    open_in(repo.root)
    review.close()

    assert.has_no.errors(function()
      vim.cmd("botright vsplit " .. vim.fn.fnameescape(repo.root .. "/a.txt"))
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { "a v2" })
      vim.cmd.write()
    end)
  end)
end)
