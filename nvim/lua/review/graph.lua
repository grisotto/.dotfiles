---The graph of commits, which is where the commit under review is chosen.
---
---Two presentations at once, on two keys, the way the diff has two and a
---conflict three (ADR-0006): the graph built here, beside the panel and
---without leaving the tabpage, and the gitgraph's, which draws the same
---history its own way. Both end in the same place — the sha goes to the panel,
---which switches mode — so what is being compared is the drawing and the
---gesture, not two different reviews.
---
---The one built here is a list, like the panel is: `git log --graph` already
---draws the lines and corners, and what this adds is the sha behind each line
---and a key that opens it. The lines git draws between two commits carry no
---commit, and pressing the key on one of them does nothing rather than opening
---a neighbour.
---
---Selecting more than one line and pressing the same key reviews the range they
---cover, which is how a finished feature is read at once. And a key filters the
---history by a branch chosen in a search: the filter is this graph reopened
---restricted to it, because that is a `git log` argument, not something the
---drawing has to know about.
local config = require "review.config"
local diff = require "review.diff"
local git = require "review.git"
local window = require "review.window"

local M = {}

local FILETYPE = "review-graph"

---What the search offers to take the filter off again, and what the header
---says while there is none.
local EVERY_BRANCH = "todas as branches"

---How far back the graph reads. It is read into a buffer in one go, and a
---repository with a hundred thousand commits would freeze the editor for as
---long as git takes to walk it. What the bound cuts off is the oldest end,
---which is not where a reviewer looking for what changed recently is reading.
local LIMIT = 1000

local MESSAGES = {
  not_a_repo = "review: fora de um repositório git.",
  git_failed = "review: não foi possível ler o histórico do git.",
  no_gitgraph = "review: o gitgraph não está disponível.",
  no_branches = "review: este repositório não tem branches.",
  no_commits = "Repositório sem commits.",
}

---@class ReviewGraphDrawing what one graph puts on screen
---@field lines string[]
---@field sha_by_line table<integer, string> 1-indexed, only the lines with a commit
---@field first integer|nil the first line with a commit on it

---@class ReviewGraphChoice what the graph hands the panel back
---@field commit fun(rev: string) the commit on the line that was opened
---@field range fun(oldest: string, newest: string) the ends of the range the
---selected lines cover, both included

---Everything the graph does, in one list, because the line under its header is
---there to show these keys: two lists would drift, and a hint naming a key the
---graph does not have is worse than no hint at all. It is the same reason the
---panel builds its keys and its context menu from one list.
---
---`name` is what a gesture is joined to what it runs by, so the hint and the
---mapping of one gesture can never come from different lines of this list.
---@return { name: string, mode: string, key: string, prefix: string|nil, hint: string, desc: string }[]
local function gestures()
  local mappings = config.options.mappings
  return {
    {
      name = "commit",
      mode = "n",
      key = mappings.diff,
      hint = "revisar",
      desc = "Revisar o commit desta linha",
    },
    {
      name = "range",
      mode = "x",
      key = mappings.diff,
      -- The key is the same one; what makes it a range is the selection it is
      -- pressed over, and that is what the hint has to show.
      prefix = "V",
      hint = "revisar o intervalo",
      desc = "Revisar o intervalo de commits selecionado",
    },
    {
      name = "branch",
      mode = "n",
      key = mappings.branch,
      hint = "filtrar por branch",
      desc = "Reabrir o grafo restrito a uma branch escolhida numa busca",
    },
    {
      name = "close",
      mode = "n",
      key = mappings.close,
      hint = "fechar",
      desc = "Fechar o grafo",
    },
  }
end

---The line the gestures are read from, under the header: the graph has keys
---nobody would guess — a selection reviews a range, a key filters by branch —
---and the list is where the reviewer is looking when they would need them.
---@return string
local function hints()
  local shown = {}
  for _, gesture in ipairs(gestures()) do
    shown[#shown + 1] = ("%s%s %s"):format(gesture.prefix or "", gesture.key, gesture.hint)
  end
  return table.concat(shown, " · ")
end

---@return integer bufnr
local function create_buf()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].filetype = FILETYPE
  return bufnr
end

---What one commit reads as on its line: the drawing git made, then the short
---name, the date, where the branches point, and what the commit says it did.
---The subject goes last because it is the one field with no length to it —
---anything after it would be pushed off the window by a wordy commit.
---@param entry ReviewLogEntry
---@return string
local function commit_line(entry)
  return ("%s%s %s%s %s"):format(entry.graph, entry.short, entry.date, entry.refs, entry.subject)
end

---@param entries ReviewLogEntry[]
---@param showing string what the history on screen is restricted to
---@return ReviewGraphDrawing
local function build_lines(entries, showing)
  local drawing = { lines = { "Commits · " .. showing, hints(), "" }, sha_by_line = {} }
  local lines = drawing.lines
  for _, entry in ipairs(entries) do
    lines[#lines + 1] = entry.sha and commit_line(entry) or entry.graph
    if entry.sha then
      drawing.sha_by_line[#lines] = entry.sha
      drawing.first = drawing.first or #lines
    end
  end
  if not drawing.first then lines[#lines + 1] = MESSAGES.no_commits end
  return drawing
end

---What each gesture of the graph runs, on the history that is on screen.
---@param drawing ReviewGraphDrawing
---@param root string absolute path of the repository root
---@param panel integer winid of the panel the graph was opened from
---@param review ReviewGraphChoice
---@return table<string, fun()> by the name of the gesture
local function runs_of(drawing, root, panel, review)
  local function open_line()
    local sha = drawing.sha_by_line[vim.api.nvim_win_get_cursor(0)[1]]
    if sha then review.commit(sha) end
  end

  ---The commits the selection covers, which are the ones on the lines it holds:
  ---the graph is drawn newest first, so the first of them is the newest end.
  local function open_selection()
    local first, last = vim.fn.line "v", vim.fn.line "."
    -- Out of the selection before acting: what is about to happen replaces this
    -- very buffer, and a visual mode left running over lines that are no longer
    -- there is not something to hand the reviewer back. The "x" is what makes
    -- the editor act on the key now instead of after this returns.
    vim.api.nvim_feedkeys(vim.keycode "<Esc>", "nx", false)

    if first > last then
      first, last = last, first
    end
    local newest, oldest = nil, nil
    for lnum = first, last do
      local sha = drawing.sha_by_line[lnum]
      if sha then
        newest = newest or sha
        oldest = sha
      end
    end
    -- A selection of the lines git drew between two commits has no commit in it
    -- to review, and does nothing rather than reviewing a neighbour.
    if newest and oldest then review.range(oldest, newest) end
  end

  ---Restrict the history to one branch, chosen in the editor's own selection
  ---UI — which is a search wherever the reviewer has a picker in front of it.
  ---The filter is this graph reopened with the branch as the argument of the
  ---`git log` behind it: there is nothing in the drawing to filter.
  local function filter_by_branch()
    local branches = git.branches(root)
    if not branches or #branches == 0 then
      vim.notify(MESSAGES.no_branches, vim.log.levels.WARN)
      return
    end

    -- The way back is offered with them: a filter that can only be taken off by
    -- closing the graph and opening it again is a filter nobody puts on twice.
    local choices = vim.list_extend({ EVERY_BRANCH }, branches)
    vim.ui.select(choices, { prompt = "Filtrar o grafo por branch" }, function(choice)
      if not choice then return end
      M.open(root, panel, review, choice ~= EVERY_BRANCH and choice or nil)
    end)
  end

  return {
    commit = open_line,
    range = open_selection,
    branch = filter_by_branch,
    close = function()
      -- Closing the last window of a tabpage closes the tabpage with it, and the
      -- graph can go without taking the reviewer's tab — and the panel's `:tcd` —
      -- along.
      if #vim.api.nvim_tabpage_list_wins(0) > 1 then pcall(vim.api.nvim_win_close, 0, true) end
    end,
  }
end

---The keys of the graph: the same gesture as in the panel — the key that opens
---a line opens what is on it — and the same key to close.
---
---The keys are the buffer's, so they read the window the reviewer is in and
---not the one the graph was drawn in: the two are the same until the buffer is
---moved somewhere else, and a key that acted on the old window would then be
---reading a line nobody is looking at.
---@param bufnr integer the graph's buffer
---@param runs table<string, fun()> what each gesture runs
local function apply_mappings(bufnr, runs)
  for _, gesture in ipairs(gestures()) do
    vim.keymap.set(gesture.mode, gesture.key, runs[gesture.name], {
      buffer = bufnr,
      nowait = true,
      desc = gesture.desc,
    })
  end

  -- The left button does what the key that opens a line does, for the same
  -- reason it does in the panel: choosing a commit with the mouse is asking to
  -- read it. It repeats a key instead of adding a gesture, which is why it is
  -- not in the list the hints come from. And it carries the same guard, because
  -- this is the same kind of list: a release over the empty rows below the
  -- oldest commit is not a click on it.
  vim.keymap.set("n", "<LeftRelease>", function()
    if window.is_click_on_a_line(vim.api.nvim_get_current_win()) then runs.commit() end
  end, {
    buffer = bufnr,
    nowait = true,
    desc = "Revisar o commit da linha clicada",
  })
end

---Open the graph beside the panel, in the window the panel opens into: the
---list stays visible while the commit is chosen, and choosing one puts its
---files in that same list.
---
---Reopening it is also how the branch filter is applied and taken off, which is
---why the branch is an argument here and not a state of the drawing: what
---changes is which commits git was asked for.
---@param root string|nil absolute path of the repository root
---@param panel integer|nil winid of the panel the key was pressed in
---@param review ReviewGraphChoice what to do with what was chosen
---@param branch string|nil the branch to restrict the history to; every branch
---when there is none
function M.open(root, panel, review, branch)
  if not root or not panel then
    vim.notify(MESSAGES.not_a_repo, vim.log.levels.WARN)
    return
  end

  local entries = git.log(root, { branch = branch, limit = LIMIT })
  if not entries then
    vim.notify(MESSAGES.git_failed, vim.log.levels.WARN)
    return
  end

  -- The diff that was beside the panel goes first: the graph takes the window
  -- one of its sides was in, and a side left behind alone stays in diff mode —
  -- with nothing to compare against, every line of the reviewer's file reads as
  -- unchanged and folds away.
  diff.close()

  local bufnr = create_buf()
  local drawing = build_lines(entries, branch or EVERY_BRANCH)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, drawing.lines)
  vim.bo[bufnr].modifiable = false

  local win = window.content(panel, bufnr)
  vim.api.nvim_win_set_buf(win, bufnr)
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true

  apply_mappings(bufnr, runs_of(drawing, root, panel, review))
  -- The cursor lands on the newest commit, which is the first line with one on
  -- it: it is what the reviewer came to read, and it saves them the trip down
  -- from the header.
  if drawing.first then vim.api.nvim_win_set_cursor(win, { drawing.first, 0 }) end
  vim.api.nvim_set_current_win(win)
end

---Open the same history in the gitgraph's own drawing, which is the other
---presentation being compared (ADR-0006). Which commit it hands back is the
---plugin's to say: the hook it calls is wired where the plugin is configured.
---@param root string|nil absolute path of the repository root
---@param panel integer|nil winid of the panel the key was pressed in
function M.open_alternate(root, panel)
  if not root or not panel then
    vim.notify(MESSAGES.not_a_repo, vim.log.levels.WARN)
    return
  end

  local ok, gitgraph = pcall(require, "gitgraph")
  if not ok then
    vim.notify(MESSAGES.no_gitgraph, vim.log.levels.WARN)
    return
  end

  diff.close()

  -- Drawn from the window beside the panel, because that is the window it
  -- takes: called with the panel focused, the gitgraph would put its own
  -- buffer where the list is and leave the reviewer without one.
  --
  -- The placeholder is only there because a window has to be opened showing
  -- something, and it is shown only when that window had to be created at all.
  -- It goes either way: wiped when the gitgraph's own buffer replaces it, and
  -- deleted here when it was never on screen for anything to replace.
  local placeholder = vim.api.nvim_create_buf(false, true)
  vim.bo[placeholder].bufhidden = "wipe"
  local win = window.content(panel, placeholder)
  vim.api.nvim_set_current_win(win)
  if vim.api.nvim_win_get_buf(win) ~= placeholder then vim.api.nvim_buf_delete(placeholder, { force = true }) end

  gitgraph.draw({}, { all = true, max_count = LIMIT })
end

return M
