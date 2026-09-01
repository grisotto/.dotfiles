local clipboard = require "tests.helpers.clipboard"
local fixture = require "tests.helpers.fixture"
local lsp = require "tests.helpers.lsp"
local panel = require "tests.helpers.panel"
local rooter = require "tests.helpers.rooter"
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

describe("copiar caminhos", function()
  before_each(function()
    review.setup {}
    rooter.install()
    clipboard.clear()
  end)

  after_each(function()
    review.close()
    lsp.cleanup()
    vim.cmd "tabfirst"
    vim.cmd "tabonly!"
    vim.cmd.cd(vim.fn.fnameescape(config_root))
    fixture.cleanup()
  end)

  it("copia o caminho absoluto do arquivo da linha", function()
    local repo = fixture.repo()
    repo:commit_file("src/a.txt", "a v1\n")
    repo:write("src/a.txt", "a v2\n")

    open_in(repo.root)
    panel.focus("Unstaged", "src/a%.txt")
    panel.feed "Y"

    assert.equals(repo.root .. "/src/a.txt", clipboard.content())
    -- Também no registrador sem nome, para o caminho estar à mão de um `p`
    -- dentro do editor.
    assert.equals(repo.root .. "/src/a.txt", vim.fn.getreg '"')
  end)

  it("copia o caminho relativo à raiz do projeto", function()
    local repo = fixture.repo()
    repo:commit_file("src/a.txt", "a v1\n")
    repo:write("src/a.txt", "a v2\n")

    open_in(repo.root)
    panel.focus("Unstaged", "src/a%.txt")
    panel.feed "y"

    assert.equals("src/a.txt", clipboard.content())
  end)

  it("num repositório com mais de um módulo, sai relativo ao módulo do arquivo", function()
    local repo = fixture.repo()
    repo:commit_file("apps/web/src/a.js", "a v1\n")
    repo:commit_file("apps/api/src/b.py", "b v1\n")
    repo:write("apps/web/src/a.js", "a v2\n")
    repo:write("apps/api/src/b.py", "b v2\n")

    -- Cada módulo tem o servidor de linguagem dele, que é quem sabe onde o
    -- módulo começa: é mais estreito que a raiz do repositório, e diferente
    -- entre os dois arquivos.
    lsp.attach(repo.root .. "/apps/web/src/a.js", repo.root .. "/apps/web")
    lsp.attach(repo.root .. "/apps/api/src/b.py", repo.root .. "/apps/api")

    open_in(repo.root)

    panel.focus("Unstaged", "apps/web/src/a%.js")
    panel.feed "y"
    assert.equals("src/a.js", clipboard.content())

    panel.focus("Unstaged", "apps/api/src/b%.py")
    panel.feed "y"
    assert.equals("src/b.py", clipboard.content())
  end)

  it("num módulo que o editor não abriu, cai na raiz do repositório", function()
    local repo = fixture.repo()
    repo:commit_file("apps/web/package.json", "{}\n")
    repo:commit_file("apps/web/src/a.js", "a v1\n")
    repo:write("apps/web/src/a.js", "a v2\n")

    open_in(repo.root)
    panel.focus("Unstaged", "apps/web/src/a%.js")
    panel.feed "y"

    -- Sem o arquivo aberto não há servidor de linguagem nele, e o detector
    -- responde o que os detectores seguintes acham: a raiz do repositório. O
    -- módulo de um arquivo que ninguém abriu não é sabido por ninguém no
    -- editor, e inventá-lo aqui seria detecção nossa.
    assert.equals("apps/web/src/a.js", clipboard.content())
  end)

  it("num repositório com mais de um módulo, o caminho absoluto continua inteiro", function()
    local repo = fixture.repo()
    repo:commit_file("apps/web/src/a.js", "a v1\n")
    repo:write("apps/web/src/a.js", "a v2\n")
    lsp.attach(repo.root .. "/apps/web/src/a.js", repo.root .. "/apps/web")

    open_in(repo.root)
    panel.focus("Unstaged", "apps/web/src/a%.js")
    panel.feed "Y"

    assert.equals(repo.root .. "/apps/web/src/a.js", clipboard.content())
  end)

  it("não copia nada de uma linha que não é arquivo", function()
    local repo = fixture.repo()
    repo:commit_file("a.txt", "a v1\n")
    repo:write("a.txt", "a v2\n")

    open_in(repo.root)
    panel.focus_header()
    panel.feed "y"
    panel.feed "Y"

    assert.equals("", clipboard.content())
  end)
end)
