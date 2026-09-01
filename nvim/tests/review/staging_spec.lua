local confirm = require "tests.helpers.confirm"
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

---The repository's own account of what happened, which is what these actions
---have to be judged by.
---@param repo FixtureRepo
---@return string[] one line per changed path, as `git status --short` writes it
local function status(repo) return vim.split(repo:git { "status", "--short" }, "\n", { plain = true, trimempty = true }) end

describe("mover entre staged e unstaged, e descartar", function()
  before_each(function()
    review.setup {}
    fixture.data_dir()
    confirm.install()
  end)

  after_each(function()
    review.close()
    confirm.restore()
    vim.cmd "tabfirst"
    vim.cmd "tabonly!"
    vim.cmd.cd(vim.fn.fnameescape(config_root))
    fixture.cleanup()
  end)

  describe("para staged", function()
    it("move o arquivo modificado, e o painel passa a listá-lo em Staged", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:write("a.txt", "a v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "s"

      assert.same({ "M  a.txt" }, status(repo))
      assert.same({ "M  a.txt" }, panel.section "Staged")
      assert.is_nil(panel.section_count "Unstaged")
    end)

    it("move o arquivo untracked", function()
      local repo = fixture.repo()
      repo:write("novo.txt", "novo\n")

      open_in(repo.root)
      panel.focus("Untracked", "novo%.txt")
      panel.feed "s"

      assert.same({ "A  novo.txt" }, status(repo))
      assert.same({ "A  novo.txt" }, panel.section "Staged")
      assert.is_nil(panel.section_count "Untracked")
    end)

    it("move a exclusão de um arquivo apagado no disco", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:delete "a.txt"

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "s"

      assert.same({ "D  a.txt" }, status(repo))
      assert.same({ "D  a.txt" }, panel.section "Staged")
    end)

    it("marca o conflito como resolvido", function()
      -- É o `git add` de sempre: o revisor resolveu o conflito no merge tool e
      -- registra a resolução daqui.
      local repo = fixture.repo()
      repo:conflict "conflito.txt"
      repo:write("conflito.txt", "resolvido\n")

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "s"

      assert.same({ "M  conflito.txt" }, status(repo))
      assert.is_nil(panel.section_count "Conflitos")
      assert.same({ "M  conflito.txt" }, panel.section "Staged")
    end)

    it("do lado unstaged de um renomeado, move só o que falta", function()
      -- O caminho antigo já está apagado no índice pela renomeação; nomeá-lo
      -- de novo aqui faria o git recusar o pathspec e nada seria movido.
      local repo = fixture.repo()
      repo:commit_file("old.txt", "conteúdo\n")
      repo:git { "mv", "old.txt", "new.txt" }
      repo:write("new.txt", "conteúdo mudado\n")

      open_in(repo.root)
      panel.focus("Unstaged", "new%.txt")
      panel.feed "s"

      -- Tudo do arquivo está no índice: nenhuma das linhas tem mudança na
      -- segunda coluna, que é onde o git escreve o que ficou de fora dele.
      assert.same({ "A  new.txt", "D  old.txt" }, status(repo))
      assert.is_nil(panel.section_count "Unstaged")
    end)
  end)

  describe("para fora de staged", function()
    it("tira o arquivo, e o painel passa a listá-lo em Unstaged", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:write("a.txt", "a v2\n")
      repo:add "a.txt"

      open_in(repo.root)
      panel.focus("Staged", "a%.txt")
      panel.feed "u"

      assert.same({ " M a.txt" }, status(repo))
      assert.same({ "M  a.txt" }, panel.section "Unstaged")
      assert.is_nil(panel.section_count "Staged")
    end)

    it("devolve a untracked o arquivo que o índice tinha e o HEAD não", function()
      local repo = fixture.repo()
      repo:write("novo.txt", "novo\n")
      repo:add "novo.txt"

      open_in(repo.root)
      panel.focus("Staged", "novo%.txt")
      panel.feed "u"

      assert.same({ "?? novo.txt" }, status(repo))
      assert.same({ "?  novo.txt" }, panel.section "Untracked")
    end)

    it("desfaz as duas metades de um renomeado", function()
      -- Uma renomeação no índice é o caminho novo adicionado e o antigo
      -- apagado: tirar só o caminho novo deixaria a exclusão do antigo staged.
      local repo = fixture.repo()
      repo:commit_file("old.txt", "conteúdo\n")
      repo:git { "mv", "old.txt", "new.txt" }

      open_in(repo.root)
      assert.same({ "R  new.txt" }, panel.section "Staged")
      panel.focus("Staged", "new%.txt")
      panel.feed "u"

      assert.same({ " D old.txt", "?? new.txt" }, status(repo))
      assert.same({ "D  old.txt" }, panel.section "Unstaged")
      assert.same({ "?  new.txt" }, panel.section "Untracked")
    end)

    it("não tira um conflito do índice", function()
      -- Um `git reset` num caminho conflitado joga fora os lados que o git
      -- guarda no índice e deixa o arquivo parecendo mesclado, com os
      -- marcadores ainda dentro dele.
      local repo = fixture.repo()
      repo:conflict "conflito.txt"

      open_in(repo.root)
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "u"

      assert.same({ "UU conflito.txt" }, status(repo))
      assert.equals(1, panel.section_count "Conflitos")
    end)

    it("funciona num repositório sem commits", function()
      -- Sem HEAD não há de onde restaurar o índice, e o painel ainda assim tem
      -- que conseguir tirar o arquivo de staged.
      local repo = fixture.repo_without_commits()
      repo:write("novo.txt", "novo\n")
      repo:add "novo.txt"

      open_in(repo.root)
      panel.focus("Staged", "novo%.txt")
      panel.feed "u"

      assert.same({ "?? novo.txt" }, status(repo))
      assert.same({ "?  novo.txt" }, panel.section "Untracked")
    end)
  end)

  describe("descartar", function()
    it("pergunta antes e não mexe em nada enquanto não for respondido que sim", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:write("a.txt", "a v2\n")

      open_in(repo.root)
      panel.focus("Unstaged", "a%.txt")
      panel.feed "X"

      assert.equals(1, #confirm.prompts())
      assert.same({ " M a.txt" }, status(repo))
      assert.equals("a v2\n", repo:read "a.txt")
      assert.same({ "M  a.txt" }, panel.section "Unstaged")
    end)

    it("não mexe em nada quando a resposta é não", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:write("a.txt", "a v2\n")

      open_in(repo.root)
      confirm.answer "Não"
      panel.focus("Unstaged", "a%.txt")
      panel.feed "X"

      assert.same({ " M a.txt" }, status(repo))
      assert.equals("a v2\n", repo:read "a.txt")
    end)

    it("devolve o arquivo ao que está no índice, sem tocar no que está staged", function()
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:write("a.txt", "a v2\n")
      repo:add "a.txt"
      repo:write("a.txt", "a v3\n")

      open_in(repo.root)
      confirm.answer "Sim"
      panel.focus("Unstaged", "a%.txt")
      panel.feed "X"

      assert.same({ "M  a.txt" }, status(repo))
      assert.equals("a v2\n", repo:read "a.txt")
      assert.is_nil(panel.section_count "Unstaged")
      assert.same({ "M  a.txt" }, panel.section "Staged")
    end)

    it("devolve o arquivo ao que está no HEAD, índice e disco de uma vez", function()
      -- Da linha staged não há como descartar só o índice: pôr o índice de
      -- volta sem tocar no disco é o que a outra tecla já faz.
      local repo = fixture.repo()
      repo:commit_file("a.txt", "a v1\n")
      repo:write("a.txt", "a v2\n")
      repo:add "a.txt"
      repo:write("a.txt", "a v3\n")

      open_in(repo.root)
      confirm.answer "Sim"
      panel.focus("Staged", "a%.txt")
      panel.feed "X"

      assert.same({}, status(repo))
      assert.equals("a v1\n", repo:read "a.txt")
      assert.is_not_nil(panel.line_matching "Nenhuma mudança")
    end)

    it("apaga o arquivo untracked", function()
      local repo = fixture.repo()
      repo:write("novo.txt", "novo\n")

      open_in(repo.root)
      confirm.answer "Sim"
      panel.focus("Untracked", "novo%.txt")
      panel.feed "X"

      assert.same({}, status(repo))
      assert.is_false(repo:exists "novo.txt")
      assert.is_nil(panel.section_count "Untracked")
    end)

    it("apaga o arquivo staged de um repositório sem commits", function()
      -- Não há commit para restaurar: o que está staged é um arquivo que o
      -- repositório nunca teve, e descartar a mudança leva o arquivo junto.
      local repo = fixture.repo_without_commits()
      repo:write("novo.txt", "novo\n")
      repo:add "novo.txt"

      open_in(repo.root)
      confirm.answer "Sim"
      panel.focus("Staged", "novo%.txt")
      panel.feed "X"

      assert.same({}, status(repo))
      assert.is_false(repo:exists "novo.txt")
    end)

    it("desfaz um renomeado inteiro", function()
      local repo = fixture.repo()
      repo:commit_file("old.txt", "conteúdo\n")
      repo:git { "mv", "old.txt", "new.txt" }

      open_in(repo.root)
      confirm.answer "Sim"
      panel.focus("Staged", "new%.txt")
      panel.feed "X"

      assert.same({}, status(repo))
      assert.equals("conteúdo\n", repo:read "old.txt")
      assert.is_false(repo:exists "new.txt")
    end)

    it("não descarta um conflito, e nem pergunta", function()
      -- Escolher um lado é resolução de conflito, que é do merge tool
      -- (ADR-0005); descartar aqui apagaria um dos lados sem dizer qual.
      local repo = fixture.repo()
      repo:conflict "conflito.txt"

      open_in(repo.root)
      confirm.answer "Sim"
      panel.focus("Conflitos", "conflito%.txt")
      panel.feed "X"

      assert.same({}, confirm.prompts())
      assert.same({ "UU conflito.txt" }, status(repo))
      assert.equals(1, panel.section_count "Conflitos")
    end)

    describe("a pergunta", function()
      it("diz que o arquivo untracked some para sempre", function()
        local repo = fixture.repo()
        repo:write("novo.txt", "novo\n")

        open_in(repo.root)
        panel.focus("Untracked", "novo%.txt")
        panel.feed "X"

        assert.same({ "Apagar novo.txt? O arquivo não está no git, não dá para recuperar." }, confirm.prompts())
      end)

      it("diz que da linha unstaged só as mudanças não staged vão embora", function()
        local repo = fixture.repo()
        repo:commit_file("a.txt", "a v1\n")
        repo:write("a.txt", "a v2\n")

        open_in(repo.root)
        panel.focus("Unstaged", "a%.txt")
        panel.feed "X"

        assert.same({ "Descartar as mudanças não staged de a.txt?" }, confirm.prompts())
      end)

      it("diz que da linha staged vão embora o índice e o disco", function()
        local repo = fixture.repo()
        repo:commit_file("a.txt", "a v1\n")
        repo:write("a.txt", "a v2\n")
        repo:add "a.txt"

        open_in(repo.root)
        panel.focus("Staged", "a%.txt")
        panel.feed "X"

        assert.same({ "Descartar as mudanças de a.txt, staged e no disco?" }, confirm.prompts())
      end)
    end)
  end)

  it("não faz nada numa linha que não é arquivo", function()
    local repo = fixture.repo()
    repo:commit_file("a.txt", "a v1\n")
    repo:write("a.txt", "a v2\n")

    open_in(repo.root)
    confirm.answer "Sim"
    panel.focus_header()
    panel.feed "s"
    panel.feed "u"
    panel.feed "X"

    assert.same({}, confirm.prompts())
    assert.same({ " M a.txt" }, status(repo))
  end)
end)
