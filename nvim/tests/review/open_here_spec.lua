local diff = require "tests.helpers.diff"
local fixture = require "tests.helpers.fixture"
local notify = require "tests.helpers.notify"
local panel = require "tests.helpers.panel"
local review = require "review"

local config_root = vim.fn.getcwd()

---@param dir string
local function open_in(dir)
  vim.cmd "tabnew"
  vim.cmd.tcd(vim.fn.fnameescape(dir))
  review.open()
end

---O arquivo que está na janela ao lado do painel, e onde o cursor está nele.
---@return string name
---@return integer lnum
---@return string line
local function reading_file()
  local win = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(win)
  local lnum = vim.api.nvim_win_get_cursor(win)[1]
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t"),
    lnum,
    vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
end

describe("o arquivo no ponto que está sendo lido", function()
  before_each(function()
    review.setup {}
    fixture.data_dir()
    notify.install()
  end)

  after_each(function()
    notify.restore()
    review.close()
    vim.cmd "tabfirst"
    vim.cmd "tabonly!"
    vim.cmd.cd(vim.fn.fnameescape(config_root))
    fixture.cleanup()
  end)

  it("abre o arquivo do disco na linha que está sendo lida, e não no topo", function()
    local repo = fixture.repo()
    repo:commit_file("a.txt", "um\ndois\ntrês\nquatro\ncinco\n")
    repo:write("a.txt", "um\ndois\ntrês MUDOU\nquatro\ncinco\n")

    open_in(repo.root)
    panel.focus("Unstaged", "a%.txt")
    panel.feed "<CR>"
    -- o revisor lê até a linha da mudança
    diff.feed "3G"

    diff.feed "go"

    local name, lnum, line = reading_file()
    assert.equals("a.txt", name)
    assert.equals(3, lnum)
    assert.equals("três MUDOU", line)
    -- o diff sai: o revisor pediu o arquivo, não meia comparação ao lado
    assert.same({}, diff.windows())
  end)

  it("acha a linha pelo texto quando o número não bate mais", function()
    -- O lado esquerdo é o índice; o arquivo no disco tem duas linhas a mais
    -- acima, então a linha 2 de lá é a 4 daqui.
    local repo = fixture.repo()
    repo:commit_file("a.txt", "alvo desta busca\nfim\n")
    repo:write("a.txt", "nova um\nnova dois\nalvo desta busca\nfim\n")

    open_in(repo.root)
    panel.focus("Unstaged", "a%.txt")
    panel.feed "<CR>"
    -- na janela da esquerda, que é a versão do índice
    vim.api.nvim_set_current_win(diff.windows()[1])
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("go", true, false, true), "x", false)

    local name, lnum, line = reading_file()
    assert.equals("a.txt", name)
    assert.equals(3, lnum)
    assert.equals("alvo desta busca", line)
  end)

  it("no modo commit abre o arquivo de hoje, ancorado pelo texto do commit", function()
    local repo = fixture.repo()
    repo:commit_file("a.txt", "linha um\nlinha dois\n")
    repo:commit_file("a.txt", "linha um\nlinha dois\nlinha três do commit\n", "o commit revisado")
    repo:write("a.txt", "cabeçalho novo\nlinha um\nlinha dois\nlinha três do commit\n")

    open_in(repo.root)
    panel.feed "c"
    require("tests.helpers.graph").choose "o commit revisado"
    panel.focus("Mudanças", "a%.txt")
    panel.feed "<CR>"
    diff.feed "3G"

    diff.feed "go"

    local name, lnum, line = reading_file()
    assert.equals("a.txt", name)
    assert.equals("linha três do commit", line)
    assert.equals(4, lnum)
  end)

  it("sem a linha no arquivo, cai no número e diz que caiu", function()
    local repo = fixture.repo()
    repo:commit_file("a.txt", "primeira\nsegunda apagada\nterceira\n")
    repo:write("a.txt", "primeira\nterceira\n")

    open_in(repo.root)
    panel.focus("Unstaged", "a%.txt")
    panel.feed "<CR>"
    vim.api.nvim_set_current_win(diff.windows()[1])
    vim.api.nvim_win_set_cursor(0, { 2, 0 })
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("go", true, false, true), "x", false)

    local name, lnum = reading_file()
    assert.equals("a.txt", name)
    assert.equals(2, lnum)
    assert.matches("não está no arquivo", notify.last())
  end)

  it("o <C-o> traz o diff de volta, na linha em que ele ficou", function()
    local repo = fixture.repo()
    repo:commit_file("a.txt", "um\ndois\ntrês\nquatro\ncinco\n")
    repo:write("a.txt", "um\ndois\ntrês MUDOU\nquatro\ncinco\n")

    open_in(repo.root)
    panel.focus("Unstaged", "a%.txt")
    panel.feed "<CR>"
    diff.feed "3G"
    diff.feed "go"
    assert.same({}, diff.windows())

    -- O revisor andou para outro arquivo, como faria indo a uma definição, e
    -- volta pelo caminho que veio.
    vim.cmd "edit outro.txt"
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-o>", true, false, true), "x", false)
    assert.equals("a.txt", reading_file())

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-o>", true, false, true), "x", false)

    assert.equals(2, #diff.windows())
    assert.equals("a.txt", diff.reading())
    assert.equals(3, diff.cursor())
  end)

  it("dentro do arquivo o <C-o> continua sendo o do editor", function()
    local repo = fixture.repo()
    repo:commit_file("a.txt", "um\ndois\ntrês\nquatro\ncinco\nseis\nsete\noito\n")
    repo:write("a.txt", "um\ndois\ntrês MUDOU\nquatro\ncinco\nseis\nsete\noito\n")

    open_in(repo.root)
    panel.focus("Unstaged", "a%.txt")
    panel.feed "<CR>"
    diff.feed "3G"
    diff.feed "go"
    -- um pulo dentro do próprio arquivo, que é o que o <C-o> desfaz
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("8G", true, false, true), "x", false)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("1G", true, false, true), "x", false)

    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-o>", true, false, true), "x", false)

    assert.same({}, diff.windows())
    local _, lnum = reading_file()
    assert.equals(8, lnum)
  end)

  it("abrir outro diff tira a volta do arquivo do revisor", function()
    -- A tecla é escrita no arquivo do revisor: o que o diff põe nela tem que
    -- sair quando ele deixa de ser o diff para onde se volta.
    local repo = fixture.repo()
    repo:commit_file("a.txt", "um\ndois\n")
    repo:commit_file("b.txt", "um\ndois\n")
    repo:write("a.txt", "um MUDOU\ndois\n")
    repo:write("b.txt", "um MUDOU\ndois\n")

    open_in(repo.root)
    panel.focus("Unstaged", "a%.txt")
    panel.feed "<CR>"
    diff.feed "go"
    local bufnr = vim.api.nvim_get_current_buf()

    panel.focus("Unstaged", "b%.txt")
    panel.feed "<CR>"

    local ours = vim.tbl_filter(function(map) return map.lhs == "<C-O>" end, vim.api.nvim_buf_get_keymap(bufnr, "n"))
    assert.same({}, ours)
  end)

  it("a ajuda do diff lista a tecla com o que ela faz", function()
    local repo = fixture.repo()
    repo:commit_file("a.txt", "um\n")
    repo:write("a.txt", "dois\n")

    open_in(repo.root)
    panel.focus("Unstaged", "a%.txt")
    panel.feed "<CR>"
    diff.feed "g?"

    assert.equals("Abrir o arquivo no disco no ponto que está sendo lido", require("tests.helpers.help").keys()["go"])
  end)
end)
