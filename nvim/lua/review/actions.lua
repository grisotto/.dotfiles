---What a key on a line of the panel does.
---
---Opening the line has two keys on purpose (ADR-0006): one for the way it
---opens by default, another for the alternative presentation of the same
---thing. On a changed file that is our two-way diff and the diffview's tab; on
---a conflict it is the three-way merge tool and the layout that also shows the
---base version — both the diffview's, because navigating conflicts and picking
---a side are already solved there (ADR-0005).
local config = require "review.config"
local diff = require "review.diff"
local git = require "review.git"
local root = require "review.root"
local state = require "review.state"
local window = require "review.window"

local M = {}

---@param target ReviewTarget
---@return string absolute path of the file on the line
local function absolute(target) return target.root .. "/" .. target.entry.path end

---The autocommand waiting to put the diffview's merge tool layout back, while
---one of ours is in its place. There is at most one: a second swap before the
---first view closes must not capture the layout already swapped in, or the
---reviewer's own layout would be lost for the rest of the session.
---@type integer|nil
local pending_restore = nil

---Put a layout in the diffview's configuration for as long as the view it is
---opening lives. The diffview reads the merge tool layout from there, and
---re-reads it on every refresh, so a layout of ours cannot be handed over per
---call: it has to sit in the configuration and come back out.
---@param layout string
local function use_merge_layout(layout)
  local view = require("diffview.config").get_config().view

  if not pending_restore then
    local configured = view.merge_tool.layout
    pending_restore = vim.api.nvim_create_autocmd("User", {
      pattern = "DiffviewViewClosed",
      once = true,
      callback = function()
        view.merge_tool.layout = configured
        pending_restore = nil
      end,
    })
  end

  view.merge_tool.layout = layout
end

---Ask the diffview for a view of one file.
---@param target ReviewTarget
---@param merge_layout string|nil layout to open a conflict in
local function diffview(target, merge_layout)
  local ok, diffview_module = pcall(require, "diffview")
  if not ok then
    vim.notify("review: o diffview não está disponível.", vim.log.levels.WARN)
    return
  end

  if merge_layout then use_merge_layout(merge_layout) end

  local args = { "--", absolute(target) }
  -- Staged compares the HEAD with the index; everything else the index with
  -- the working tree, which is what the diffview does without a rev.
  if target.entry.section == "staged" then table.insert(args, 1, "--cached") end
  diffview_module.open(args)
end

---Open what the line represents, the default way: the two-way diff beside the
---panel, or the merge tool when the file is conflicted.
---@param target ReviewTarget
function M.open(target)
  if target.entry.section == "conflicts" then return diffview(target, config.options.merge_layouts.conflict) end
  diff.open(target)
end

---Open the same thing in its alternative presentation: the diffview's own tab,
---or, for a conflict, the layout that includes the base version.
---@param target ReviewTarget
function M.open_alternate(target)
  if target.entry.section == "conflicts" then
    return diffview(target, config.options.merge_layouts.conflict_with_base)
  end
  diffview(target, nil)
end

---Mark what the line puts under review as seen, or unmark it when it already
---is. The mark is on the content, not on the file (ADR-0002), so the same file
---listed as two changes is two different marks.
---@param target ReviewTarget
function M.toggle_seen(target)
  local content = target.entry.content
  if not content then
    vim.notify("review: não foi possível identificar o conteúdo deste arquivo.", vim.log.levels.WARN)
    return
  end
  state.toggle(target.root, content, target.entry.path)
end

---Say it when git refused. Everything here changes the repository, and a
---command that did nothing has to be visible: the panel redraws either way,
---and a list that came back unchanged looks exactly like a key that was never
---pressed.
---@param ok boolean
---@param detail string|nil git's own error message
local function report(ok, detail)
  if ok then return end
  vim.notify("review: " .. (detail and detail ~= "" and detail or "o git recusou a operação."), vim.log.levels.WARN)
end

---Move the change on the line into the index. On an untracked file that is the
---file itself; on a deleted one, its deletion; on a conflicted one, the
---resolution the reviewer left on disk — which is the one thing the panel
---knows how to do with a conflict (ADR-0007).
---@param target ReviewTarget
function M.stage(target) report(git.stage(target.root, target.entry)) end

---Take the change on the line out of the index.
---@param target ReviewTarget
function M.unstage(target)
  -- Resetting a conflicted path would drop the sides git is holding in the
  -- index and leave the file looking merged, with the markers still in it.
  -- Undoing a merge is the merge tool's, not a key of the list (ADR-0007).
  if target.entry.section == "conflicts" then
    vim.notify("review: um conflito não sai do índice daqui; resolva-o no merge tool.", vim.log.levels.WARN)
    return
  end
  report(git.unstage(target.root, target.entry))
end

---What the panel asks before throwing a change away. Each section gets its own
---question, naming the file and saying exactly what goes: this is the one key
---that loses work, and the answer is given once.
---@param entry ReviewEntry
---@return string|nil nil when the line is not something to discard
local function question(entry)
  if entry.section == "untracked" then
    return ("Apagar %s? O arquivo não está no git, não dá para recuperar."):format(entry.path)
  elseif entry.section == "unstaged" then
    return ("Descartar as mudanças não staged de %s?"):format(entry.path)
  elseif entry.section == "staged" then
    return ("Descartar as mudanças de %s, staged e no disco?"):format(entry.path)
  end
end

---Throw the change on the line away, after asking. The question goes through
---the editor's own selection UI, so it is asked wherever the reviewer already
---reads questions, and so that it can be answered without the editor sitting
---blocked on it.
---@param target ReviewTarget
---@param done fun() redraws the panel; called after the answer, which with a
---picker in front of `vim.ui.select` arrives long after this function returns
function M.discard(target, done)
  -- The only line without a question is a conflict: discarding one would be
  -- picking a side without saying which (ADR-0007).
  local asking = question(target.entry)
  if not asking then
    vim.notify("review: um conflito não se descarta daqui; resolva-o no merge tool.", vim.log.levels.WARN)
    return
  end

  vim.ui.select({ "Sim", "Não" }, { prompt = asking }, function(choice)
    if choice ~= "Sim" then return end
    report(git.discard(target.root, target.entry))
    done()
  end)
end

---@param win integer winid to open the file in
---@param path string
local function edit(win, path)
  vim.api.nvim_set_current_win(win)
  -- The window may be coming back from a diff of another file.
  vim.cmd "diffoff"
  vim.cmd.edit(vim.fn.fnameescape(path))
end

---Open the file itself, in the window beside the panel. The diff goes: the
---reviewer asked for the file, not for half of a comparison next to it.
---@param target ReviewTarget
function M.open_file(target)
  diff.close()
  local path = absolute(target)
  edit(window.content(target.panel, vim.fn.bufadd(path)), path)
end

---Put a path where the reviewer can paste it: in the system clipboard, which
---is where copying points — a PR, a ticket, a message — and in the unnamed
---register, so it is also there for a `p` in the editor, clipboard provider or
---not. The notification shows what went into them: the two keys differ only in
---the path they copy, and reading it back is the only way to tell the key that
---was pressed from the one that was meant.
---@param path string
local function copy(path)
  vim.fn.setreg("+", path)
  vim.fn.setreg('"', path)
  vim.notify("review: copiado " .. path)
end

---A path under `directory`, written from it. Tried again through symlinks
---before giving up: the two come from different places — git's own answer and
---the root detector's, which resolves what it answers — and one symlink on the
---way to the repository is enough for the same directory to arrive here
---written two ways.
---@param directory string absolute path
---@param path string absolute path
---@return string relative or `path` itself, when it is not under `directory`
local function relative_to(directory, path)
  return vim.fs.relpath(directory, path)
    or vim.fs.relpath(vim.uv.fs_realpath(directory) or directory, vim.uv.fs_realpath(path) or path)
    or path
end

---Copy the absolute path of the file on the line.
---@param target ReviewTarget
function M.copy_absolute_path(target) copy(absolute(target)) end

---Copy the path of the file on the line written from the root of its project —
---the root of the module it belongs to, which in a monorepo is not the root of
---the repository. The repository root is what is left when there is no
---detector to ask at all, which is also the right answer wherever the
---repository holds a single module.
---@param target ReviewTarget
function M.copy_relative_path(target)
  local path = absolute(target)
  copy(relative_to(root.project(path) or target.root, path))
end

---Open the file itself in a split, keeping what was already in the window
---beside the panel.
---@param target ReviewTarget
function M.open_file_in_split(target)
  diff.close()
  local path = absolute(target)
  local bufnr = vim.fn.bufadd(path)
  edit(window.below(window.content(target.panel, bufnr), bufnr), path)
end

return M
