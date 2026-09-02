---The two-way diff the panel builds in its own tabpage.
---
---What is compared comes from the section of the line: on a staged line, the
---HEAD against the index; on an unstaged or untracked line, the index against
---the working tree; on a line of a commit, that commit against its first
---parent. The working tree side is the file itself, not a copy of it, so the
---reviewer can fix what they are reading right there — a commit has no such
---side, because both of its versions are history.
---
---A conflicted file has no content at stage zero of the index, so no two-way
---diff of it means anything. What it has is the three sides git is holding in
---the other stages, and those go side by side here, in the third of the
---presentations a conflict has (ADR-0006). Picking a side and walking from one
---conflict to the next are still the diffview's (ADR-0005): what is built here
---only shows the three versions.
---
---The file read in a rev the reviewer chose is built here too, on the same
---buffers and in the same window: one side alone, which is a consultation and
---not a comparison, and comparing it with the file on disk, which is two sides
---like any other diff. It is the one place where what goes beside the panel is
---not the change on the line — and the reason both live here is that they take
---the same space, so leaving one has to take the other down.
local config = require "review.config"
local git = require "review.git"
local window = require "review.window"

local M = {}

---@class ReviewDiffSide
---@field label string what the side is called in the buffer name
---@field rev string|nil rev to read the content from; nil is the file on disk
---@field path string path relative to the repository root
---@field lines string[]|nil the content, when it was already read

---The windows this module opened in each tabpage, so opening another diff
---there can take them down. Per tabpage, like the panel: the diff of one
---tabpage is not the diff the reviewer is reading in another.
---@type table<integer, integer[]>
local wins_by_tab = {}

---What the read-only view of each tabpage gives back when it is left: the file
---the reviewer had beside the panel when the consultation started.
---
---Kept here rather than in the closure of one view because a consultation is
---often more than one: the second rev opens over the first, and by then the
---file is not on screen for the window to be asked about it. It goes when
---anything else takes that space, which is what `M.close` is.
---@type table<integer, integer>
local back_to_by_tab = {}

---How a rev is written on the side it is showing: short enough to leave room
---for the path beside it, which is the other half of the name.
---@param rev string
---@return string
local function short(rev)
  -- Only a whole object name is abbreviated, and how long that is depends on
  -- the repository's hash: forty on SHA-1, sixty-four on SHA-256. A rev the
  -- reviewer would recognise — a branch, something already short — is left as
  -- it is.
  return (rev:gsub("^(%x+)", function(sha) return #sha >= 40 and sha:sub(1, 7) or sha end))
end

---@param entry ReviewEntry
---@return ReviewDiffSide left
---@return ReviewDiffSide right
local function two_way_sides(entry)
  -- A commit is read against what it changed, which is the pair of revs the
  -- entry came with. Neither side is the file on disk: the working tree has
  -- moved on since, and what is being reviewed is the commit.
  if entry.rev then
    return { label = short(entry.base), rev = entry.base, path = entry.orig_path or entry.path }, {
      label = short(entry.rev),
      rev = entry.rev,
      path = entry.path,
    }
  end

  local index = { label = "índice", rev = ":0", path = entry.path }
  if entry.section == "staged" then
    -- A renamed file has its old content under the old path in HEAD.
    return { label = "HEAD", rev = "HEAD", path = entry.orig_path or entry.path }, index
  end
  -- Unstaged and untracked read the same way: what the index has of the file —
  -- nothing at all, for an untracked one — against what is on disk.
  return index, { label = "working tree", rev = nil, path = entry.path }
end

---A read-only buffer with the content of one side. Wiped with the window that
---shows it: these buffers are the diff, and they have no life after it.
---@param root string
---@param side ReviewDiffSide
---@return integer bufnr
local function rev_buf(root, side)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, side.lines or git.show(root, side.rev, side.path) or { "" })
  vim.bo[bufnr].modifiable = false

  -- The name is what the reviewer reads to tell the sides apart, and it is
  -- also all the syntax highlighting has to go on.
  pcall(vim.api.nvim_buf_set_name, bufnr, ("review://%s/%s"):format(side.label, side.path))
  vim.bo[bufnr].filetype = vim.filetype.match { filename = side.path } or ""

  return bufnr
end

---@param root string
---@param path string
---@return integer bufnr the buffer of the file itself
local function file_buf(root, path)
  local bufnr = vim.fn.bufadd(root .. "/" .. path)
  vim.fn.bufload(bufnr)
  return bufnr
end

---Take down the diff of this tabpage. The rev buffers go with their windows;
---the working tree side is the reviewer's own file buffer and stays, unsaved
---edits included.
function M.close()
  local tab = vim.api.nvim_get_current_tabpage()
  local open = wins_by_tab[tab] or {}
  wins_by_tab[tab] = nil
  -- What a view of this tabpage was going to give back goes with it: whatever
  -- takes this space now is what a later consultation has to come back to.
  back_to_by_tab[tab] = nil
  for _, win in ipairs(open) do
    if vim.api.nvim_win_is_valid(win) then
      -- Closing the last window of a tabpage closes the tabpage with it. The
      -- diff can go without taking the reviewer's tab along.
      if #vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(win)) > 1 then
        pcall(vim.api.nvim_win_close, win, true)
      else
        vim.api.nvim_win_call(win, function() vim.cmd "diffoff" end)
      end
    end
  end
end

---Put these sides side by side beside the panel, replacing whatever diff was
---there.
---@param target ReviewTarget
---@param sides ReviewDiffSide[] left to right
---@param focused_side integer index into `sides` of the one the reviewer is left in
---@return integer[] opened winids, left to right
local function build(target, sides, focused_side)
  -- The diff that was there goes first, and only then are the new sides built:
  -- a side is told from the others by the name of its buffer, a name is unique
  -- in the editor, and the side of the previous diff still holding it would
  -- leave this one unnamed — silently, since naming a buffer is allowed to
  -- fail. Opening the same conflict twice is exactly that case.
  M.close()

  local bufs = {}
  for index, side in ipairs(sides) do
    bufs[index] = side.rev and rev_buf(target.root, side) or file_buf(target.root, side.path)
  end

  local opened = { window.content(target.panel, bufs[1]) }
  vim.api.nvim_win_set_buf(opened[1], bufs[1])
  for index = 2, #bufs do
    opened[index] = window.beside(opened[index - 1], bufs[index])
  end

  -- A tabpage that is gone took its diff with it; what is left here is only
  -- the winids of tabpages still on screen.
  for tab in pairs(wins_by_tab) do
    if not vim.api.nvim_tabpage_is_valid(tab) then wins_by_tab[tab] = nil end
  end
  wins_by_tab[vim.api.nvim_get_current_tabpage()] = opened

  -- One side alone is not a comparison, and putting it in diff mode would fold
  -- the whole file away: nothing differs from nothing.
  if #opened > 1 then
    for _, win in ipairs(opened) do
      vim.api.nvim_win_call(win, function() vim.cmd "diffthis" end)
    end
  end
  vim.api.nvim_set_current_win(opened[focused_side])

  return opened
end

---Build the diff of `target` beside its panel, replacing whatever diff was
---there. Focus goes to the right side: it is the one to edit in the working
---tree, and the version being reviewed in a commit.
---@param target ReviewTarget
function M.open(target)
  local left, right = two_way_sides(target.entry)
  build(target, { left, right }, 2)
end

---The three versions git is holding for a conflicted path: a side each, short
---of the path, which is the file the reviewer asked about.
---
---Ours on the left and theirs on the right, which is where both of the
---diffview's merge layouts put them — the three presentations are there to be
---compared (ADR-0006), and they can only be compared if the reviewer has to
---re-learn which side is which on the way. The base goes in the middle, where
---the merge tool shows the merge: it is the one version neither side wrote,
---and what both of them changed away from.
local STAGES = {
  { label = "atual", rev = ":2" },
  { label = "base", rev = ":1" },
  { label = "entrando", rev = ":3" },
}

---Build the three versions of the conflict on `target` beside its panel,
---replacing whatever diff was there. The panel stays where it is: this is the
---presentation of a conflict that does not take the reviewer to another
---tabpage, so the list is still on the side while the three are read.
---
---A stage the index does not have — a file the two sides each added has no
---base — comes up as an empty side, which is what it is.
---@param target ReviewTarget
function M.open_conflict(target)
  local sides = {}
  for index, stage in ipairs(STAGES) do
    sides[index] = vim.tbl_extend("error", stage, { path = target.entry.path })
  end
  -- Left in our own version: it is the side the reviewer knows, and the one
  -- the incoming change is being judged against.
  build(target, sides, 1)
end

---The name this file goes by in `rev`, and what is under it there.
---
---A renamed file is under its old name in a rev from before the rename and
---under the new one after it, and which of the two a rev the reviewer picked
---falls on is not something to guess: the name that answers is the one that is
---there. The old name is only tried when there is one, so nothing else pays
---for a second call to git.
---@param root string
---@param entry ReviewEntry
---@param rev string
---@return string|nil path nil when that rev has the file under neither name
---@return string[]|nil lines
local function in_rev(root, entry, rev)
  local lines = git.show(root, rev, entry.path)
  if lines then return entry.path, lines end
  if not entry.orig_path then return nil end
  lines = git.show(root, rev, entry.orig_path)
  if lines then return entry.orig_path, lines end
end

---Compare the file on the line with the version of it in `rev`: that version on
---the left, what the panel is reviewing on the right. The rev chosen is on the
---left because it is the past being read against the present, which is the
---direction of every other diff the panel builds.
---@param target ReviewTarget
---@param rev string anything git resolves
function M.open_against(target, rev)
  local entry = target.entry
  local path, lines = in_rev(target.root, entry, rev)

  -- What the rev is compared against is what the panel is listing: the file on
  -- disk in the working tree, and the commit's own version in commit mode. A
  -- commit has no working tree side for the same reason its own diff has none —
  -- both of its versions are history, and what is on disk today is not what the
  -- line is showing. It is also a file that may not be there at all any more.
  local current = entry.rev and { label = short(entry.rev), rev = entry.rev, path = entry.path }
    or { label = "working tree", rev = nil, path = entry.path }

  build(target, {
    -- A rev that has the file under neither name is an empty side, which is
    -- what it is: the file was not there yet, or was already gone.
    { label = short(rev), rev = rev, path = path or entry.path, lines = lines or { "" } },
    current,
  }, 2)
end

---Take the read-only view of a rev off the screen: the window goes back to the
---file that was beside the panel before it, or goes away when there was none,
---and the reviewer is left in the list they pressed the key in.
---
---This is the whole of "the consultation costs nothing": what was being read
---comes back with one key. A diff that was on screen does not come back — its
---sides went when the view took their place — but the file of it does, which is
---the side the reviewer was reading and the one their edits are in.
---@param win integer winid the view is in
---@param panel integer winid of the panel it was opened from
---@param previous integer|nil bufnr to put back
local function leave(win, panel, previous)
  if vim.api.nvim_win_is_valid(win) then
    local tab = vim.api.nvim_win_get_tabpage(win)
    -- What is about to be in this window is the reviewer's, not for us to take
    -- down later. Only when the view is all that is tracked there: a window
    -- carried to another tabpage (`<C-w>T`) lands among that tabpage's own
    -- windows, and forgetting those would leave them behind on the next diff.
    local tracked = wins_by_tab[tab]
    if tracked and #tracked == 1 and tracked[1] == win then
      wins_by_tab[tab] = nil
      back_to_by_tab[tab] = nil
    end

    if previous and vim.api.nvim_buf_is_valid(previous) then
      vim.api.nvim_win_set_buf(win, previous)
    elseif #vim.api.nvim_tabpage_list_wins(tab) > 1 then
      pcall(vim.api.nvim_win_close, win, true)
    else
      vim.api.nvim_win_call(win, function() vim.cmd "enew" end)
    end
  end
  if vim.api.nvim_win_is_valid(panel) then vim.api.nvim_set_current_win(panel) end
end

---Show the file on the line as it is in `rev`, read only, in the window beside
---the panel, with the way back on the key that closes the panel and the graph.
---
---Read only because it is a consultation: what is in a rev is history, and an
---edit made here would have nowhere to be saved. The buffer is named after the
---rev, which is how the reviewer knows which version they are reading — the
---file itself is a key away, and the two look alike otherwise.
---@param target ReviewTarget
---@param rev string anything git resolves
---@return boolean opened false when that rev has no such path, which is nothing
---to show — unlike a diff, where it is an empty side
function M.open_rev(target, rev)
  local path, lines = in_rev(target.root, target.entry, rev)
  if not path then return false end

  -- Read before anything moves: the diff about to be replaced holds the file
  -- the reviewer was reading, and once its windows are gone there is no telling
  -- what was in them. A view already on screen has nothing to be asked — it is
  -- a buffer of ours — so what it was going to give back is carried forward.
  local tab = vim.api.nvim_get_current_tabpage()
  local previous = window.file_beside(target.panel) or back_to_by_tab[tab]

  local win = build(target, { { label = short(rev), rev = rev, path = path, lines = lines } }, 1)[1]
  back_to_by_tab[tab] = previous

  vim.keymap.set("n", config.options.mappings.close, function() leave(win, target.panel, previous) end, {
    buffer = vim.api.nvim_win_get_buf(win),
    nowait = true,
    desc = "Voltar ao que estava ao lado do painel",
  })

  return true
end

return M
