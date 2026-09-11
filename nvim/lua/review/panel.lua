---The review panel itself: the window, the rendered sections and the map from
---a rendered line back to the entry on it.
local actions = require "review.actions"
local annotation = require "review.annotation"
local config = require "review.config"
-- The panel is built on top of the diff (ADR-0009), which is why it can ask it
-- what is beside the list; the diff only ever reaches back the other way from
-- inside a key, and lazily.
local diff = require "review.diff"
local git = require "review.git"
local graph = require "review.graph"
local menu = require "review.menu"
local mode = require "review.mode"
local state = require "review.state"
local window = require "review.window"

local M = {}

local FILETYPE = "review"

---Where the dimming of a seen file is drawn, when the vistos are configured to
---stay in place.
local NAMESPACE = vim.api.nvim_create_namespace(FILETYPE)

---Everything the panel listens to. Up here because one of them is written on
---the panel's own buffer as it is created, and the rest at the bottom of this
---file, where the editor-wide ones are gathered.
local GROUP = vim.api.nvim_create_augroup("review-panel", { clear = true })

---Sections in the order the reviewer reads them: conflicts first, because
---they are what has to be dealt with before anything else.
local SECTIONS = {
  { key = "conflicts", label = "Conflitos" },
  { key = "staged", label = "Staged" },
  { key = "unstaged", label = "Unstaged" },
  { key = "untracked", label = "Untracked" },
}

---What a commit is listed under. One section, because a commit has one kind of
---file in it: the sections of the working tree are the states a change can be
---in on its way to a commit, and a change that is already in one is past all
---of them. The panel keeps its shape either way — a header with a count, the
---files under it, and the Vistos section at the end (ADR-0001).
local COMMIT_SECTIONS = { { key = "commit", label = "Mudanças" } }

---The sections a reading of the repository is rendered in.
---@param status ReviewStatus
---@return { key: ReviewSection, label: string }[]
local function sections_of(status) return status.rev and COMMIT_SECTIONS or SECTIONS end

---The section seen files go to: last, because it is what the reviewer is done
---with, and collapsed, because the list is there to show what is left.
local SEEN = {
  label = "Vistos",
  collapsed = "▸",
  expanded = "▾",
}

---What the key says when the two commits selected in the graph are not the
---ends of a range. Not one of the MESSAGES below: those are lines the panel
---renders, and this is said to a reviewer whose list did not change.
local NOT_A_RANGE = "review: os dois commits não estão na mesma linha da história; não há intervalo entre eles."

local MESSAGES = {
  not_a_repo = "Fora de um repositório git.",
  git_failed = "Não foi possível ler o estado do git.",
  no_such_rev = "Commit não encontrado.",
  no_commits = "Repositório sem commits.",
  no_changes = "Nenhuma mudança.",
}

---@class ReviewPanelState the panel of one tabpage
---@field bufnr integer the panel buffer, reused across open and close
---@field cwd string|nil the directory the panel is reviewing
---@field root string|nil the repository root of what is listed
---@field rev string|nil the commit being listed; nil in the working tree
---@field oldest string|nil the other end when what is listed is a range of
---commits: the oldest of it, with `rev` the newest
---@field mode ReviewMode the review the annotations and the report are of
---@field hidden_for_diff boolean|nil whether `close_on_diff` took the list off
---the screen, which is the list the key that closes the diff brings back
---@field entry_by_line table<integer, ReviewEntry> 1-indexed, only entry lines
---@field order ReviewEntry[] every entry listed, in the order the review goes in
---@field seen_collapsed boolean whether the Vistos section is showing its files
---@field preview boolean whether the diff is following the cursor of the list
---@field pending_preview integer|nil how many moves of the cursor have asked for
---a preview, so that only the last of a burst draws one
---@field seen_header integer|nil line the Vistos header is on, when it is rendered
---@field mapped string[] keys currently mapped in the panel buffer
---@field window_options table<string, any>|nil what the panel's window looked like before it took it
---@field winid integer|nil the window the panel is in, while it is on screen
---@field at ReviewEntry|nil where the review went while the list was off
---screen, for the cursor to catch up with when it comes back
---@field width integer|nil the width the panel keeps, in columns

---The panel is single (ADR-0001), but single *per tabpage*: a reviewer keeps
---one repository per tabpage (`:tcd`), and a panel sharing its buffer across
---tabpages would show one tabpage's repository — and its lines — inside the
---other's.
---@type table<integer, ReviewPanelState>
local panels = {}

---The panel buffer being put on screen by the panel itself, while that is
---happening. The eviction at the bottom of this file has to leave alone the one
---window that is allowed to show a panel: the window the panel is opening,
---which has no winid to be recognised by yet.
---@type integer|nil
local opening = nil

---Drop the panels of tabpages that no longer exist, with their buffers: with
---the tabpage gone nothing can reach them again.
local function forget_closed_tabs()
  for tab, panel in pairs(panels) do
    if not vim.api.nvim_tabpage_is_valid(tab) then
      panels[tab] = nil
      if vim.api.nvim_buf_is_valid(panel.bufnr) then pcall(vim.api.nvim_buf_delete, panel.bufnr, { force = true }) end
    end
  end
end

---The panel of the current tabpage, if it already has one.
---@return ReviewPanelState|nil
local function current()
  forget_closed_tabs()
  local panel = panels[vim.api.nvim_get_current_tabpage()]
  if panel and vim.api.nvim_buf_is_valid(panel.bufnr) then return panel end
end

---The window a panel is showing in, in the tabpage it belongs to.
---
---The window the panel opened, first: it is the one the panel lives in, and
---every action reads this to know where the list is. Sweeping the tabpage for
---the panel's buffer answers *a* window showing it, which is a different
---question — the buffer displayed in the reviewer's content window would make
---that window the panel for every action, `close` included. The sweep is left
---as the fallback for the winid that no longer holds, and what keeps the
---buffer from being shown outside its window is the eviction below.
---@param tab integer tabpage handle
---@param panel ReviewPanelState
---@return integer|nil winid nil when that panel is closed
local function win_of(tab, panel)
  if not vim.api.nvim_tabpage_is_valid(tab) then return nil end

  local own = panel.winid
  if
    own
    and vim.api.nvim_win_is_valid(own)
    and vim.api.nvim_win_get_tabpage(own) == tab
    and vim.api.nvim_win_get_buf(own) == panel.bufnr
  then
    return own
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    if vim.api.nvim_win_get_buf(win) == panel.bufnr then return win end
  end
end

---@return integer|nil winid the panel window in the current tabpage
function M.win()
  local panel = current()
  if not panel then return nil end
  return win_of(vim.api.nvim_get_current_tabpage(), panel)
end

---@return boolean
function M.is_open() return M.win() ~= nil end

---The repository the panel of this tabpage is listing, for the actions that
---are about the review as a whole and not about a line of the list.
---
---Only while it is on screen: a panel that was closed keeps the root it read,
---and answering with it would put a reviewer who has since moved to another
---repository — the panel closed, `:tcd` elsewhere — in front of a report of
---the one they left.
---@return string|nil root nil when no panel is showing in this tabpage
function M.repository()
  local panel = M.win() and current()
  return panel and panel.root or nil
end

---The entry rendered on a line of the panel of the current tabpage, if that
---line has one.
---@param lnum integer 1-indexed
---@return ReviewEntry|nil
function M.entry_at(lnum)
  local panel = current()
  if not panel then return nil end
  return panel.entry_by_line[lnum]
end

---@param a ReviewEntry
---@param b ReviewEntry
---@return boolean
local function by_path(a, b) return a.path < b.path end

---@param entries ReviewEntry[]
---@param sections { key: ReviewSection, label: string }[]
---@return table<ReviewSection, ReviewEntry[]>
local function group(entries, sections)
  local grouped = {}
  for _, section in ipairs(sections) do
    grouped[section.key] = {}
  end
  for _, entry in ipairs(entries) do
    table.insert(grouped[entry.section], entry)
  end
  for _, section in pairs(grouped) do
    table.sort(section, by_path)
  end
  return grouped
end

---Whether an entry is one the reviewer has already read. An entry whose content
---git could not identify never is: there is no key it could have been marked
---under.
---@param entry ReviewEntry
---@param seen table<string, true> contents marked as seen
---@return boolean
local function is_seen(entry, seen) return entry.content ~= nil and seen[entry.content] == true end

---Whether two entries are the same file under review. Section and path
---together: the same file can be listed in two sections — changed in the index
---and changed again on disk — and those are two changes to read, not one.
---@param one ReviewEntry
---@param other ReviewEntry
---@return boolean
local function same_entry(one, other) return one.section == other.section and one.path == other.path end

---Split the entries into the ones still to review and the ones already seen.
---@param entries ReviewEntry[]
---@param seen table<string, true> contents marked as seen
---@return ReviewEntry[] unseen
---@return ReviewEntry[] already_seen
local function split_seen(entries, seen)
  local unseen, already_seen = {}, {}
  for _, entry in ipairs(entries) do
    table.insert(is_seen(entry, seen) and already_seen or unseen, entry)
  end
  return unseen, already_seen
end

---A path fit to put on one line of the panel. `-z` hands us paths exactly as
---they are on disk, and a newline in one would split the entry across two
---lines — or make rendering fail outright. The entry keeps the real path; only
---what is shown is escaped.
---@param path string
---@return string
local function displayable(path) return (path:gsub("[\r\n]", { ["\n"] = "\\n", ["\r"] = "\\r" })) end

---What a file with annotations carries after its path, so the reviewer sees
---from the list where they left remarks.
local ANNOTATED = "✎"

---What each status code is drawn in: the colours the editor already has for the
---three kinds of change, so the column is read without being learned. A
---conflict is not one of the three — it is what has to be dealt with before the
---review goes anywhere — and it is drawn as the error it is.
---
---By the first letter, which is what the panel puts on the line: the score of a
---rename is already off it, and a conflict is answered before this is read.
local STATUS_HIGHLIGHT = {
  A = "Added",
  ["?"] = "Added",
  C = "Added",
  M = "Changed",
  R = "Changed",
  T = "Changed",
  D = "Removed",
}

---@param entry ReviewEntry
---@return string|nil group nil for a status nothing here names
local function status_highlight(entry)
  if entry.section == "conflicts" then return "ErrorMsg" end
  return STATUS_HIGHLIGHT[entry.status:sub(1, 1)]
end

---Whether the module has been asked for already. The `require` below is there
---to make a lazily loaded mini.icons load, which happens once; without the
---guard, a configuration without mini.icons at all would pay a search of the
---runtimepath on every line of every draw.
local asked_for_icons = false

---What answers for icons, or nil where there are none.
---
---mini.icons, which is what is installed here, read from the global it
---publishes and not from what `require` hands back: the module only answers
---once it has been set up — the cache the icons come out of is built there —
---so the global is what says there are icons to ask for. The `require` is still
---made, because under a plugin manager it is what loads the plugin in the first
---place.
---@return table|nil
local function icons_provider()
  if not _G.MiniIcons and not asked_for_icons then
    asked_for_icons = true
    pcall(require, "mini.icons")
  end
  return _G.MiniIcons
end

---The icon of a file, which is what makes the panel be read by the same eyes
---that read the file tree beside it. Absent, the line goes back to being what
---it was: a glyph is not a dependency to take on.
---@param path string
---@return string|nil icon
---@return string|nil hl the highlight the icon is drawn in
local function icon_of(path)
  local icons = icons_provider()
  if not icons then return nil end
  local ok, icon, hl = pcall(icons.get, "file", path)
  if not ok then return nil end
  return icon, hl
end

---@class ReviewMark what the panel draws over a stretch of one line
---@field lnum integer 1-indexed, filled in when the line is put on the list
---@field col integer 0-indexed byte the stretch starts at
---@field end_col integer 0-indexed byte it ends at
---@field group string highlight group

---@class ReviewNumberMark the `+N −M` of a line, drawn beside it
---@field lnum integer 1-indexed, filled in when the line is put on the list
---@field chunks { [1]: string, [2]: string }[] text and highlight, as the
---editor takes virtual text

---How much a change adds and takes out, which is what decides in what order to
---review. Drawn as virtual text against the right edge of the panel, so a long
---path pushes the numbers off the list instead of pushing the name of the file
---off it.
---
---Nothing at all where there is nothing to count: an untracked file, a
---conflict, a binary file. Absence is honest; an invented number is not.
---
---A line drawn as already read keeps its numbers — how big a change is does not
---stop being true once it has been read — but keeps them faded with the rest of
---it: in the colours of what they add and take out they would be the one bright
---thing on a line that is done.
---@param entry ReviewEntry
---@param dim boolean whether the line is drawn as already read
---@return { [1]: string, [2]: string }[]|nil chunks
local function number_chunks(entry, dim)
  if not entry.added or not entry.removed then return nil end
  local puts, takes = dim and "Comment" or "Added", dim and "Comment" or "Removed"
  return { { ("+%d"):format(entry.added), puts }, { " " }, { ("−%d"):format(entry.removed), takes } }
end

---The line an entry is rendered on: the icon of the file, the status code, the
---path, and the annotations. A conflict carries a two-letter code, everything
---else one letter; padding keeps the paths in one column either way. The count
---of annotations comes after the path, where a long path pushes it off the
---panel rather than pushing the name of the file off it.
---
---The count is the file's, so a file listed in two sections — a staged change
---and an unstaged one — shows it on both lines. That is what it is: an
---annotation is written about a file and a line, never about the section the
---reviewer happened to be reading when they wrote it.
---@param entry ReviewEntry
---@param counts table<string, integer> annotations by path
---@return string line
---@return ReviewMark[] marks what is drawn over it, without their line yet
local function entry_line(entry, counts)
  local marks = {}
  local line = "  "

  local icon, icon_hl = icon_of(entry.path)
  if icon then
    if icon_hl then marks[#marks + 1] = { col = #line, end_col = #line + #icon, group = icon_hl } end
    line = line .. icon .. " "
  end

  local status_hl = status_highlight(entry)
  if status_hl then marks[#marks + 1] = { col = #line, end_col = #line + #entry.status, group = status_hl } end
  line = ("%s%-2s %s"):format(line, entry.status, displayable(entry.path))

  local count = counts[entry.path]
  if count then line = ("%s  %s %d"):format(line, ANNOTATED, count) end
  return line, marks
end

---@class ReviewRendered what one draw puts on screen
---@field lines string[]
---@field entry_by_line table<integer, ReviewEntry> 1-indexed, only entry lines
---@field order ReviewEntry[] every entry listed, in the order the review goes in
---@field dimmed integer[] lines drawn faded: a file already read where it
---stands, and the line of information under the header
---@field highlights ReviewMark[] what is drawn over the lines
---@field numbers ReviewNumberMark[] the `+N −M` drawn beside the lines
---@field seen_header integer|nil line the Vistos header is on, when rendered

---Where the reviewer goes after the working tree has been read through: the
---commit page of neogit, which is what this configuration puts on that key. It
---is not a mapping of ours and is not configurable here — it is neogit's, and
---naming it is the whole of what the line does (ADR-0005).
local NEOGIT_COMMIT = "<Leader>gnc"

---What the panel says once there is nothing left to read.
---
---It is the end of the review without a state being invented for it: nothing is
---started, nothing is finished, nothing is archived. The mark is of the content
---and goes on crossing the modes (ADR-0002); what the end adds is a line saying
---what to do now, which is not the same thing in every mode.
---@param status ReviewStatus
---@return string
local function next_step(status)
  if status.rev then return ("Tudo visto. Gerar o relatório: %s"):format(config.options.mappings.report) end
  return "Tudo visto. Commitar no neogit: " .. NEOGIT_COMMIT
end

---How many commits a range holds, written the way it is read.
---@param commits integer
---@return string
local function counted_commits(commits) return ("%d %s"):format(commits, commits == 1 and "commit" or "commits") end

---The line of information under the header, which is where the panel says what
---is different about the review the reviewer is in.
---
---Reviewing one's own working tree and reviewing somebody else's commit are two
---jobs with different ends. The keys stay the same whichever it is (ADR-0001);
---what changes is what the panel *informs* — and the totals are the one thing
---every mode has, because every mode is a diff of some size.
---@param status ReviewStatus
---@return string
local function information(status)
  local parts = {}
  if status.range and status.commits then
    parts[#parts + 1] = counted_commits(status.commits)
  elseif status.rev then
    -- Whose commit it is and from when, which is what a reviewer opening
    -- somebody else's work wants to know before reading a line of it.
    if status.author and status.author ~= "" then parts[#parts + 1] = status.author end
    if status.date and status.date ~= "" then parts[#parts + 1] = status.date end
  end
  parts[#parts + 1] = ("+%d −%d"):format(status.added, status.removed)
  return table.concat(parts, " · ")
end

---@class ReviewDrawing what one draw reads, the other half of `ReviewRendered`
---@field status ReviewStatus|nil nil when the repository could not be read
---@field failure ReviewGitFailure|nil
---@field seen table<string, true> contents marked as seen
---@field counts table<string, integer> annotations by path
---@field collapsed boolean whether the Vistos section hides its files

---@param drawing ReviewDrawing
---@return ReviewRendered
local function build_lines(drawing)
  local status, seen, counts = drawing.status, drawing.seen, drawing.counts
  local lines, entry_by_line, dimmed, highlights, numbers, seen_header = {}, {}, {}, {}, {}, nil

  ---Put an entry on the next line of the list, with what the panel draws over
  ---it and beside it. A line drawn as already read keeps its numbers and loses
  ---its colours: the dimming is what says it is done, and a status still in the
  ---colour of its change would leave the line read half one way and half the
  ---other.
  ---@param entry ReviewEntry
  ---@param dim boolean
  local function put(entry, dim)
    local line, marks = entry_line(entry, counts)
    lines[#lines + 1] = line
    entry_by_line[#lines] = entry
    if dim then
      dimmed[#dimmed + 1] = #lines
    else
      for _, mark in ipairs(marks) do
        mark.lnum = #lines
        highlights[#highlights + 1] = mark
      end
    end
    local chunks = number_chunks(entry, dim)
    if chunks then numbers[#numbers + 1] = { lnum = #lines, chunks = chunks } end
  end

  if not status then
    return {
      lines = { "Revisão", "", MESSAGES[drawing.failure] or MESSAGES.git_failed },
      entry_by_line = entry_by_line,
      order = {},
      dimmed = dimmed,
      highlights = highlights,
      numbers = numbers,
    }
  end

  local unseen, already_seen = split_seen(status.entries, seen)
  -- Dimmed in place: nothing leaves its section, and what is seen is drawn as
  -- read instead of moved.
  local in_place = config.options.seen_display == "dimmed"
  if in_place then unseen = status.entries end

  -- What is being reviewed, which in the working tree is the branch and in a
  -- commit is the commit itself: the reviewer has to be able to tell one mode
  -- from the other without counting the sections.
  lines[#lines + 1] = "Revisão · " .. status.title
  -- The progress is what is left to read, so it only means something while
  -- there is something to read. It counts changes and not files, the same way
  -- the sections do: a file with a staged and an unstaged change is two diffs
  -- to read, and a header counting it once would say the review was over with
  -- one of them still on the list.
  if #status.entries > 0 then
    lines[#lines] = ("%s · %d/%d vistos"):format(lines[#lines], #already_seen, #status.entries)
  end
  -- Dimmed, so the header stays one line to be read and this one is there to be
  -- glanced at.
  lines[#lines + 1] = information(status)
  dimmed[#dimmed + 1] = #lines
  if not status.has_commits then
    lines[#lines + 1] = ""
    lines[#lines + 1] = MESSAGES.no_commits
  end

  local sections = sections_of(status)
  -- The order the review goes in: the sections in the order the reviewer reads
  -- them, paths ascending inside each. Every entry is in it, seen or not — the
  -- Vistos section gathers what is done, and gathering it is a presentation of
  -- the list, not a change to where a file stands in the review (ADR-0009).
  local all = group(status.entries, sections)
  local order = {}
  for _, section in ipairs(sections) do
    vim.list_extend(order, all[section.key])
  end

  local grouped = in_place and all or group(unseen, sections)
  for _, section in ipairs(sections) do
    local entries = grouped[section.key]
    if #entries > 0 then
      lines[#lines + 1] = ""
      lines[#lines + 1] = ("%s (%d)"):format(section.label, #entries)
      for _, entry in ipairs(entries) do
        put(entry, in_place and is_seen(entry, seen))
      end
    end
  end

  if not in_place and #already_seen > 0 then
    table.sort(already_seen, by_path)
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("%s %s (%d)"):format(
      drawing.collapsed and SEEN.collapsed or SEEN.expanded,
      SEEN.label,
      #already_seen
    )
    seen_header = #lines
    if not drawing.collapsed then
      for _, entry in ipairs(already_seen) do
        put(entry, false)
      end
    end
  end

  if #status.entries == 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = MESSAGES.no_changes
  elseif #already_seen == #status.entries then
    -- In the same place the message goes, because it is the same place: the
    -- bottom of the list is where the panel says what there is to say when
    -- there is nothing left on it.
    lines[#lines + 1] = ""
    lines[#lines + 1] = next_step(status)
  end

  return {
    lines = lines,
    entry_by_line = entry_by_line,
    order = order,
    dimmed = dimmed,
    highlights = highlights,
    numbers = numbers,
    seen_header = seen_header,
  }
end

---How long the panel waits, in milliseconds, before the preview draws what the
---cursor arrived on. A `j` held down a list of a hundred files goes past every
---one of them, and each one drawn costs a `git show` per side read out of the
---repository — two of them on a staged line and on a commit — plus a redrawn
---screen: what the reviewer means by that gesture is the file they stop on, and
---this is the pause that tells stopping from passing through.
local PREVIEW_DELAY = 80

---Draw beside the panel the diff of the entry the cursor is on, without taking
---the cursor out of the list.
---
---On a header or a blank line nothing is drawn and what is beside the list
---stays: passing over one on the way down the list is not asking for the diff
---to go.
---
---Nor is the entry whose diff is already beside the list redrawn. It is what
---keeps a cursor moving inside one line — and a list redrawn under a cursor
---that did not move — from asking git for the same versions again, and the
---screen from flickering while nothing changed.
---
---What is beside the list is asked of the diff, and not remembered here: the
---`<CR>` of the list, the keys that walk the review from inside the diff and the
---key that closes it all put something else in that space, and a memory of ours
---would go on saying a file was on the screen after it had gone — leaving the
---preview refusing to draw the one file the reviewer came back to.
---@param panel ReviewPanelState
---@param win integer winid of the panel
local function preview_entry(panel, win)
  if not panel.root then return end

  local entry = panel.entry_by_line[vim.api.nvim_win_get_cursor(win)[1]]
  if not entry then return end
  local showing = diff.showing()
  if showing and same_entry(showing, entry) then return end

  actions.preview { entry = entry, root = panel.root, panel = win, mode = panel.mode }
end

---Draw the preview once the cursor has stopped moving, and only for the last
---move of the burst: the reviewer on their way down the list passes over files
---they are not asking to read.
---@param panel ReviewPanelState
local function schedule_preview(panel)
  local pending = (panel.pending_preview or 0) + 1
  panel.pending_preview = pending

  vim.defer_fn(function()
    if panel.pending_preview ~= pending or not panel.preview then return end
    -- Everything is asked again now, and not when the move happened: the list
    -- may have been redrawn in between, and what the preview is about is the
    -- line the cursor is on when it stops.
    --
    -- The reviewer being in the list is asked again for a stronger reason. A key
    -- pressed inside this pause — the `<CR>` of the list, the key that opens the
    -- file, the one that marks and advances — takes them out of the panel and
    -- into what it opened, and a preview built on top of that would close the
    -- windows they are sitting in and hand them back to the list they had just
    -- left.
    local win = win_of(vim.api.nvim_get_current_tabpage(), panel)
    if win and win == vim.api.nvim_get_current_win() then preview_entry(panel, win) end
  end, PREVIEW_DELAY)
end

---While the preview is on, moving in the list is what asks for the diff: the
---reviewer sweeps with the cursor and reads what is beside it, which is the
---whole of the gesture (`nvi-01m1kh83jb71`).
---
---Only while the panel is the window the reviewer is in. Its buffer can be on
---screen in a window that is not the panel's — that is what the eviction at the
---bottom of this file is for — and a cursor moving there is not the review
---moving. The cursor of the panel is also moved from outside it: the keys of
---the diff walk the review (ADR-0009) and `<Space>` takes it to the next file,
---and both already open what they moved to, so a preview drawn from there would
---be a second diff built on top of the one the key just opened.
---@param panel ReviewPanelState
local function follow_cursor(panel)
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = GROUP,
    buffer = panel.bufnr,
    desc = "Desenhar o preview da entrada sob o cursor do painel de revisão",
    callback = function()
      if not panel.preview then return end
      local win = win_of(vim.api.nvim_get_current_tabpage(), panel)
      if win and win == vim.api.nvim_get_current_win() then schedule_preview(panel) end
    end,
  })
end

---@return integer bufnr
local function create_buf()
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "hide"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].filetype = FILETYPE
  vim.bo[bufnr].modifiable = false
  return bufnr
end

---The panel of the current tabpage, created if this is its first open.
---@return ReviewPanelState
local function ensure_panel()
  local panel = current()
  if panel then return panel end

  panel = {
    bufnr = create_buf(),
    entry_by_line = {},
    order = {},
    seen_collapsed = true,
    mapped = {},
    mode = mode.WORKTREE,
    -- Where the option is read: it is the state the panel opens in, and from
    -- there the key is what says whether the diff is following the cursor.
    preview = config.options.preview,
  }
  panels[vim.api.nvim_get_current_tabpage()] = panel
  follow_cursor(panel)
  return panel
end

---The review the panel of this tabpage is making: the working tree, or the
---commit it was switched to.
---
---Only while it is on screen, for the same reason `repository` answers only
---then, and so that the two always answer about the same review: with the
---panel closed the repository falls back to the current directory, and a mode
---that went on naming a commit would file a remark about that repository under
---the review of another one.
---@return ReviewMode
function M.mode()
  local panel = M.win() and current()
  return panel and panel.mode or mode.WORKTREE
end

---What the line under the cursor points at, and where it was read from.
---@return ReviewTarget|nil nil on a line that is not a file
local function target_under_cursor()
  local panel = current()
  local win = M.win()
  if not win or not panel or not panel.root then return nil end
  local entry = panel.entry_by_line[vim.api.nvim_win_get_cursor(win)[1]]
  if not entry then return nil end
  return { entry = entry, root = panel.root, panel = win, mode = panel.mode }
end

---Only run on a line that has a file on it: on a header or a blank line the
---key does nothing, rather than acting on a neighbouring file.
---@param run fun(target: ReviewTarget)
---@return fun()
local function on_entry(run)
  return function()
    local target = target_under_cursor()
    if target then run(target) end
  end
end

---Show the files of the Vistos section, or hide them again. On the header of
---that section the key that opens a file has nothing to open, and expanding is
---what the reviewer means there.
---@return boolean handled false when the cursor is not on that header
local function toggle_seen_section()
  local panel, win = current(), M.win()
  if not panel or not win or not panel.seen_header then return false end
  if vim.api.nvim_win_get_cursor(win)[1] ~= panel.seen_header then return false end

  panel.seen_collapsed = not panel.seen_collapsed
  M.refresh()
  return true
end

---What the key that opens a line does: on the header of the Vistos section
---there is nothing to open, and expanding it is what the reviewer means there.
local function open_line()
  if not toggle_seen_section() then on_entry(actions.open)() end
end

---Turn the preview on, or off again: sweeping the list and reading a file are
---two moments of the same review, and going from one to the other is a gesture
---and not a setting to go and change (ADR-0006).
---
---Turning it on draws what the cursor is already on, because that is the answer
---to the key: the reviewer asked to see what they are standing on, not to see
---the next file they move to. Turning it off leaves the screen as it is —
---whoever turns it off has found the file they were sweeping for, and taking
---the diff down would take away what they just found. It is said out loud for
---the same reason: with the diff still there, nothing else on the screen tells
---the reviewer the key took.
local function toggle_preview()
  local panel, win = current(), M.win()
  if not panel or not win then return end

  panel.preview = not panel.preview
  if panel.preview then
    vim.notify "review: preview ligado — o diff segue o cursor da lista."
    preview_entry(panel, win)
  else
    vim.notify "review: preview desligado — o diff fica onde está."
  end
end

---Where an entry stands in the review, which is its place in the order the
---panel lists.
---@param panel ReviewPanelState
---@param entry ReviewEntry
---@return integer|nil index nil when it is no longer listed
local function place_of(panel, entry)
  for index, listed in ipairs(panel.order) do
    if same_entry(listed, entry) then return index end
  end
end

---Where the review is, read from the cursor of the panel: the place of the
---entry it is on, or of the last one listed above it when the cursor is on a
---line that is not a file.
---
---Above every entry there is no place at all, and that is not the same as being
---before the first: the end of the review parks the cursor on the header, where
---`N/N vistos` is written, and a walk that started counting from there would
---answer the top of the list — which is the lap the review does not do.
---@param panel ReviewPanelState
---@param lnum integer the line the cursor is on
---@return integer|nil place nil when the cursor is above the whole list
local function place_under_cursor(panel, lnum)
  for line = lnum, 1, -1 do
    local entry = panel.entry_by_line[line]
    if entry then return place_of(panel, entry) end
  end
end

---Where the review is when there is no list on screen to read it from: the line
---the diff beside it was built from.
---
---It is the one thing the reviewer can see then, and it is unambiguous — the
---diff was built from an entry, so the file listed as two changes is not two
---answers here. A consultation of a rev is no entry of the list and answers
---nothing, which is the same as being nowhere in the review.
---@param panel ReviewPanelState
---@return integer|nil place
local function place_of_the_diff(panel)
  local entry = require("review.diff").showing()
  return entry and place_of(panel, entry) or nil
end

---The entry one step away in the order the panel lists, and never wrapping
---around: the ends of the list are the ends of the review, not a lap of it.
---
---The order is the list's own — the sections as the reviewer reads them, paths
---ascending — and not the order of the lines on the screen: a file already seen
---is gathered into the Vistos section at the end, and being done with a file
---does not move it in the review (ADR-0009). With `seen` given it is skipped
---altogether, which is the walk through what is left to read.
---@param panel ReviewPanelState
---@param from integer the place to walk away from
---@param direction integer 1 down the list, -1 up it
---@param seen table<string, true>|nil contents to walk past, when what is being
---looked for is a file still to read
---@return ReviewEntry|nil
local function neighbour(panel, from, direction, seen)
  for place = from + direction, direction > 0 and #panel.order or 1, direction do
    local entry = panel.order[place]
    if entry and not (seen and is_seen(entry, seen)) then return entry end
  end
end

---The line an entry is drawn on now, which is where it went when the list was
---redrawn under it.
---@param panel ReviewPanelState
---@param entry ReviewEntry
---@return integer|nil lnum nil when it is not drawn: it left the list, or it is
---inside the Vistos section while that section is collapsed
local function line_of(panel, entry)
  for lnum, drawn in pairs(panel.entry_by_line) do
    if same_entry(drawn, entry) then return lnum end
  end
end

---Where the cursor goes when there is no next file to read: the header, which is
---where the panel writes how the review stands.
local HEADER = 1

---What the panel opens for the entry the review has moved to, in the tabpage
---the list is in.
---@param panel ReviewPanelState
---@param win integer winid of the panel
---@param entry ReviewEntry
local function open_entry(panel, win, entry)
  if not panel.root then return end
  actions.open { entry = entry, root = panel.root, panel = win, mode = panel.mode }
end

---Put the cursor of the panel on an entry, which is the review moving to it.
---
---A file already read is inside the Vistos section, and that section opens to
---receive the cursor when it is closed: the position of the review is a line of
---the list (ADR-0009), so it has to have one to sit on — and a reviewer going
---back to a file they had finished with is the one gesture that section is
---there for.
---With the list off screen the review moves all the same, and what it moved to
---is written down for the cursor to catch up with when the panel comes back:
---the position of the review is a line of the list, and it has to be that line
---again the moment there is a list to look at.
---@param panel ReviewPanelState
---@param win integer|nil winid of the panel; nil while it is not on screen
---@param entry ReviewEntry
---@return boolean moved false when the entry is not on the list at all
local function go_to(panel, win, entry)
  if not win then
    panel.at = entry
    return true
  end

  local lnum = line_of(panel, entry)
  if not lnum and panel.seen_collapsed then
    panel.seen_collapsed = false
    M.refresh()
    lnum = line_of(panel, entry)
  end
  if not lnum then return false end

  vim.api.nvim_win_set_cursor(win, { lnum, 0 })
  panel.at = nil
  return true
end

---Mark the file on the line as seen and go to the next one still to read: one
---key for what otherwise costs three — the focus back on the list, the cursor
---down, and the diff open again.
---
---Only marking advances. Unmarking is done looking at the file, and a key that
---left it would undo the mark and take away what it undid.
---
---With nothing left below, the cursor goes to the header, where the panel
---already writes how the review stands — `12/12 vistos`. That is the whole of
---the ending: the review has no lifecycle to finish, and the end of it is a
---line.
---@param target ReviewTarget
---@param opts { open: boolean } whether the next file is opened as well, which
---is what the key means when it is pressed away from the list: there the cursor
---moving is not something the reviewer is looking at
local function seen_and_next(target, opts)
  local panel, win = current(), target.panel
  if not panel then return end

  local seen = state.seen(target.root)
  local marking = not is_seen(target.entry, seen) and target.entry.content ~= nil
  -- The next one is read from the list before the mark, because the mark is what
  -- moves the lines around — and read as the mark leaves it: a mark is of the
  -- content and not of the path (ADR-0002), so it makes every entry of that
  -- content seen at once, and none of them is a file left to read.
  if marking then seen[target.entry.content] = true end
  local from = place_under_cursor(panel, vim.api.nvim_win_get_cursor(win)[1])
  local next_entry = marking and from and neighbour(panel, from, 1, seen) or nil

  actions.toggle_seen(target)
  M.refresh()
  if not marking then return end

  if next_entry and go_to(panel, win, next_entry) then
    if opts.open then open_entry(panel, win, next_entry) end
  else
    vim.api.nvim_win_set_cursor(win, { HEADER, 0 })
  end
end

---Mark what the review is on as seen and open the next file still to read: the
---loop of the list, on a key that works from inside the file being read.
---
---What it marks is the entry under the panel's cursor, which is the position of
---the review (ADR-0009). The file on the screen would not answer it: the same
---file changed in the index and on disk is two entries of the list, two diffs
---to read and two marks, and only the cursor says which of them is being read.
---
---It opens the next one, where the key of the list only points at it: the
---reviewer pressing this is not looking at the list, and a cursor moving out of
---sight is not an answer. With nothing left to read there is nothing to open,
---and what says so is the list beside them — the count in the header, where the
---cursor goes.
function M.seen_and_next()
  local target = target_under_cursor()
  -- Said out loud, unlike the same key inside the list: there the reviewer is
  -- looking at the line the key did nothing on, and here they are not looking
  -- at the list at all.
  if not target then
    vim.notify(
      "review: a revisão não está em nenhuma linha do painel; escolha uma para marcar.",
      vim.log.levels.WARN
    )
    return
  end
  seen_and_next(target, { open = true })
end

---Move the review to the file one step away in the list and open it, without
---going through the list: the panel's cursor is the position of the review
---(ADR-0009), and this is the diff moving it.
---
---The list does not have to be on screen for it to walk: reading a file takes
---the whole screen, and closing the list is what the reviewer does to get it —
---the review goes on being the same review, with the same order and the same
---place in it. What is on screen then is the diff, and the entry it was built
---from is where the review is; the panel's cursor catches up when it comes back
---(`go_to`).
---
---With the list on screen it is the cursor that answers, and nothing else
---(ADR-0009): a reviewer who moved it to another line and pressed this key is
---asking to walk from there, and the file on the screen would not know that.
---
---Nothing happens at the ends of the list, and nothing is said either: the key
---does not wrap around, for the same reason the key of the list does not. What
---says the review did not move is the panel — its cursorline, when it is there,
---and the diff staying where it is when it is not.
---
---Everything that is not the end of the list is said out loud: a review that
---cannot be walked at all is not a review the reviewer can see standing still,
---and the key would look like a key that stopped working.
---@param opts { direction: integer, unseen: boolean } `direction` is 1 down the
---list and -1 up it; `unseen` walks past what is already marked, which is the
---pair of keys that goes through what is left to read
---@return boolean moved false at the ends of the list, where the review stays
---where it is — which is what the key that walks the changes of a file reads to
---know there was no file to go on into
---@return boolean spoke whether it said why it did not move, so the key that
---called it does not say something else on top
function M.step(opts)
  local panel = current()
  if not panel then
    vim.notify("review: não há revisão nesta aba; abra o painel para começar uma.", vim.log.levels.WARN)
    return false, true
  end
  if not panel.root then
    vim.notify("review: fora de um repositório git.", vim.log.levels.WARN)
    return false, true
  end

  local win = M.win()
  local from = win and place_under_cursor(panel, vim.api.nvim_win_get_cursor(win)[1]) or place_of_the_diff(panel)
  if not from then
    vim.notify(
      "review: a revisão não está em nenhuma linha da lista; abra o painel para escolher uma.",
      vim.log.levels.WARN
    )
    return false, true
  end

  local entry = neighbour(panel, from, opts.direction, opts.unseen and state.seen(panel.root) or nil)
  if not entry or not go_to(panel, win, entry) then return false, false end

  open_entry(panel, win, entry)
  return true, false
end

---Everything the panel does, in the order the context menu lists it: what the
---reviewer came to do first, the file itself next, then what changes the
---repository, and the panel's own keys last.
---
---One list for the keys and for the menu, because the menu exists to show the
---keys: two lists would drift, and the entry showing the wrong key is worse
---than no menu at all. `label` is the menu's short wording and `desc` the long
---one which-key shows, where there is room to say what the key does in a
---conflict too. `worktree_only` is what a commit has nothing to do with: those
---entries keep their key and lose their wording (see `offered_in`).
---@return { key: string, label: string, desc: string, worktree_only: boolean|nil, run: fun() }[]
local function panel_actions()
  local mappings = config.options.mappings
  return {
    {
      key = mappings.diff,
      label = "Abrir o diff",
      desc = "Abrir o diff da linha (merge tool, num conflito); expandir a seção Vistos",
      run = open_line,
    },
    {
      key = mappings.diff_alternate,
      label = "Abrir o diff alternativo",
      desc = "Abrir na apresentação alternativa (diffview; com a versão base, num conflito)",
      run = on_entry(actions.open_alternate),
    },
    {
      key = mappings.diff_conflict,
      label = "Abrir as três versões do conflito",
      desc = "Abrir as três versões de um conflito ao lado do painel, sem trocar de aba",
      run = on_entry(actions.open_conflict),
    },
    -- Beside the keys that open a line, because what it opens is the same diff:
    -- the difference is that this one keeps opening it, on whatever line the
    -- cursor arrives at, without the reviewer leaving the list.
    {
      key = mappings.preview,
      label = "Ligar ou desligar o preview",
      desc = "Ligar ou desligar o preview: o diff da linha desenhado ao lado enquanto o cursor anda pela lista",
      run = toggle_preview,
    },
    {
      key = mappings.open,
      label = "Abrir o arquivo",
      desc = "Abrir o arquivo na janela principal",
      run = on_entry(actions.open_file),
    },
    {
      key = mappings.open_split,
      label = "Abrir o arquivo num split",
      desc = "Abrir o arquivo num split",
      run = on_entry(actions.open_file_in_split),
    },
    -- O par do arquivo em outro rev, logo depois das teclas que abrem o arquivo
    -- daqui: é o mesmo arquivo, em outra versão.
    {
      key = mappings.open_rev,
      label = "Ver o arquivo em outro rev",
      desc = "Ver o arquivo como ele está em outro commit ou branch, escolhido numa busca",
      run = on_entry(actions.open_rev),
    },
    {
      key = mappings.diff_rev,
      label = "Comparar o arquivo com outro rev",
      desc = "Comparar o arquivo atual com a versão dele em outro commit ou branch",
      run = on_entry(actions.diff_rev),
    },
    {
      key = mappings.toggle_seen,
      label = "Marcar ou desmarcar como visto",
      desc = "Marcar ou desmarcar o arquivo como visto",
      -- The list is what tells the reviewer the mark took: it has to be
      -- redrawn, and only the panel knows how to redraw itself.
      run = on_entry(function(target)
        actions.toggle_seen(target)
        M.refresh()
      end),
    },
    {
      key = mappings.seen_and_next,
      label = "Marcar como visto e ir à próxima",
      desc = "Marcar o arquivo como visto e levar o cursor à próxima não vista, sem dar a volta",
      -- From the list the cursor moving is the answer: the reviewer is looking
      -- at it. Only pressed from away from the list does the key open what it
      -- moved to (`M.seen_and_next`).
      run = on_entry(function(target) seen_and_next(target, { open = false }) end),
    },
    {
      key = mappings.annotate,
      label = "Anotar o arquivo",
      desc = "Escrever a anotação do arquivo, sem linha; editar a que já houver",
      -- The count on the line is what tells the reviewer the annotation took,
      -- and the redraw goes along instead of following the call: the text
      -- arrives after this returns.
      run = on_entry(function(target) actions.annotate_file(target, nil, M.refresh) end),
    },
    {
      key = mappings.annotate_long,
      label = "Anotar o arquivo em várias linhas",
      desc = "Escrever a anotação do arquivo na entrada de várias linhas",
      run = on_entry(function(target) actions.annotate_file(target, { long = true }, M.refresh) end),
    },
    -- The three that a commit has nothing to do with: what is committed is
    -- history, and staging it, taking it out of the index or throwing it away
    -- are all about the working tree.
    {
      key = mappings.stage,
      label = "Mover para staged",
      desc = "Mover o arquivo para staged",
      worktree_only = true,
      -- Same as the mark above: what tells the reviewer the file moved is the
      -- list, and only the panel knows how to redraw itself.
      run = on_entry(function(target)
        actions.stage(target)
        M.refresh()
      end),
    },
    {
      key = mappings.unstage,
      label = "Tirar de staged",
      desc = "Tirar o arquivo de staged",
      worktree_only = true,
      run = on_entry(function(target)
        actions.unstage(target)
        M.refresh()
      end),
    },
    {
      key = mappings.discard,
      label = "Descartar as mudanças",
      desc = "Descartar as mudanças do arquivo, com confirmação",
      worktree_only = true,
      -- The redraw goes along instead of following the call: the answer to the
      -- question arrives after this returns.
      run = on_entry(function(target) actions.discard(target, M.refresh) end),
    },
    {
      key = mappings.copy_relative_path,
      label = "Copiar o caminho relativo",
      desc = "Copiar o caminho a partir da raiz do projeto do arquivo",
      run = on_entry(actions.copy_relative_path),
    },
    {
      key = mappings.copy_absolute_path,
      label = "Copiar o caminho absoluto",
      desc = "Copiar o caminho absoluto do arquivo",
      run = on_entry(actions.copy_absolute_path),
    },
    {
      key = mappings.report,
      label = "Gerar o relatório",
      desc = "Gerar o relatório da revisão, copiá-lo para a área de transferência e pôr os pontos na quickfix",
      -- Not `on_entry`: the report is about the review, not about the line the
      -- cursor happens to be on, and it is generated from the header of the
      -- panel as much as from a file in it.
      run = function() actions.report(M.repository(), M.mode()) end,
    },
    -- The three keys of the mode, together and after the ones about a line:
    -- they are the panel's own, like refreshing and closing are, and what they
    -- change is what the whole list is showing.
    {
      key = mappings.graph,
      label = "Abrir o grafo de commits",
      desc = "Abrir o grafo com os commits de todas as branches, para revisar um deles ou um intervalo",
      run = function() graph.open(M.repository(), M.win(), { commit = M.commit, range = M.range }) end,
    },
    {
      key = mappings.graph_alternate,
      label = "Abrir o grafo alternativo",
      desc = "Abrir o grafo na apresentação alternativa (gitgraph)",
      run = function() graph.open_alternate(M.repository(), M.win()) end,
    },
    {
      key = mappings.worktree,
      label = "Voltar ao working tree",
      desc = "Sair do modo commit e voltar a listar o working tree",
      run = M.worktree,
    },
    -- With the panel's own keys, because it is about the panel and not about a
    -- line of it: every key above, with what it does, one key away.
    {
      key = mappings.help,
      label = "Ver todas as teclas",
      desc = "Ver todas as teclas do painel, com o que cada uma faz",
      run = function() M.help() end,
    },
    { key = mappings.refresh, label = "Atualizar", desc = "Atualizar o painel de revisão", run = M.refresh },
    { key = mappings.close, label = "Fechar o painel", desc = "Fechar o painel de revisão", run = M.close },
  }
end

---The left button on a line does what the key that opens it does: the reviewer
---clicking a file is asking to read it.
---
---The release, and not the press: the press is what moves the cursor to the
---line that was clicked, and the action reads the line the cursor is on.
local MOUSE = "<LeftRelease>"

local function on_click()
  local win = M.win()
  if win and window.is_click_on_a_line(win) then open_line() end
end

---Whether a key of the panel can act the moment it is typed, instead of waiting
---to see whether a longer mapping was being typed.
---
---Every one of them can, except the reviewer's own leader. A key of the panel is
---local to its buffer and the `<Leader>` commands are global, so a leader that
---acted at once would take every one of those commands away from the reviewer
---while the cursor is in the list — and the list is where they sit longest.
---Waiting is the whole cost of keeping them, and it is paid by one key.
---@param key string as it is written in the mappings
---@return boolean
local function acts_at_once(key)
  local leader = vim.g.mapleader
  if type(leader) ~= "string" then return true end
  return vim.api.nvim_replace_termcodes(key, true, true, true) ~= leader
end

---The panel's keys are short, local to its buffer, and their descriptions are
---what which-key shows. The mouse is mapped along with them, and only here: it
---repeats a key instead of adding an action, so it has nothing to say in a menu
---that exists to show the keys.
---@param panel ReviewPanelState
---@param keys { key: string, desc: string, run: fun() }[]
local function apply_mappings(panel, keys)
  local bufnr = panel.bufnr
  for _, key in ipairs(panel.mapped) do
    pcall(vim.keymap.del, "n", key, { buffer = bufnr })
  end
  panel.mapped = {}

  local mapped = vim.list_extend({ { key = MOUSE, desc = "Abrir o diff da linha clicada", run = on_click } }, keys)
  for _, action in ipairs(mapped) do
    vim.keymap.set("n", action.key, function() action.run() end, {
      buffer = bufnr,
      nowait = acts_at_once(action.key),
      desc = action.desc,
    })
    panel.mapped[#panel.mapped + 1] = action.key
  end
end

---The panel's actions as the mode it is in offers them.
---
---A commit has nothing to do with staging, unstaging or discarding: what is
---committed is history, and the keys already say so, with a refusal that points
---at the key back to the working tree. What changes here is that they stop being
---*offered* — no wording in the menu, no description for which-key — because a
---menu offering what is going to be refused is worse than no menu at all.
---
---They stay mapped, so whoever presses one out of habit gets that refusal
---instead of silence. And the filter comes off the same single list the keys and
---the menu have always come off (ADR-0008): what the mode changes is which of
---its entries carry wording, not which list is read.
---@param panel ReviewPanelState
---@return { key: string, label: string|nil, desc: string|nil, run: fun() }[] keys
---@return ReviewMenuItem[] offered the ones the menu shows
local function offered_in(panel)
  local keys, offered = {}, {}
  for _, action in ipairs(panel_actions()) do
    local silent = action.worktree_only and panel.mode.rev ~= nil
    keys[#keys + 1] = { key = action.key, desc = not silent and action.desc or nil, run = action.run }
    if not silent then offered[#offered + 1] = { label = action.label, key = action.key, run = action.run } end
  end
  return keys, offered
end

---List every key of the panel in the help window: the ones the mode offers,
---with the words which-key shows for them, in the order the menu lists them.
---The same list the keys were mapped from (`offered_in`), read when the key is
---pressed, so the window cannot list a key the panel does not have.
function M.help()
  local panel = current()
  if not panel then return end

  local keys = {}
  for _, key in ipairs((offered_in(panel))) do
    if key.desc then keys[#keys + 1] = { key = key.key, desc = key.desc } end
  end
  require("review.help").open("Teclas do painel", keys, config.options.mappings.help)
end

---The winbar of the panel's window: the key that lists every key of the panel,
---with what it does, the way the winbar of the diff writes its keys. The keys of
---the panel are too many for a bar as wide as the list, and the one that lists
---them fits.
---@return string
local function help_bar()
  return window.bar("", { { label = "ver todas as teclas", key = config.options.mappings.help } })
end

---Put the panel's actions where the reviewer reaches them: the keys of its
---buffer and the entries of the context menu.
---
---From one list and at one moment, because the menu is there to show the keys.
---Sharing the list is not enough on its own: refreshed at different times, the
---menu would go on showing the key of a mapping that is no longer there.
---
---The menu of the editor is one and global (ADR-0008), so only the panel the
---reviewer is actually sitting in puts its entries there: a panel of another
---tabpage being redrawn is not the menu the right button has to show.
---@param panel ReviewPanelState
local function apply_actions(panel)
  local keys, offered = offered_in(panel)
  apply_mappings(panel, keys)
  -- With the keys and at the same moment, for the same reason as the menu: the
  -- key the bar names is the key that is mapped.
  if
    panel.winid
    and vim.api.nvim_win_is_valid(panel.winid)
    and vim.api.nvim_win_get_buf(panel.winid) == panel.bufnr
  then
    vim.wo[panel.winid].winbar = help_bar()
  end
  if vim.api.nvim_get_current_buf() == panel.bufnr then menu.install(offered) end
end

---@param panel ReviewPanelState
---@param rendered ReviewRendered
local function render(panel, rendered)
  vim.bo[panel.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(panel.bufnr, 0, -1, false, rendered.lines)
  vim.bo[panel.bufnr].modifiable = false

  vim.api.nvim_buf_clear_namespace(panel.bufnr, NAMESPACE, 0, -1)
  for _, lnum in ipairs(rendered.dimmed) do
    vim.api.nvim_buf_set_extmark(panel.bufnr, NAMESPACE, lnum - 1, 0, { line_hl_group = "Comment" })
  end
  for _, mark in ipairs(rendered.highlights) do
    vim.api.nvim_buf_set_extmark(
      panel.bufnr,
      NAMESPACE,
      mark.lnum - 1,
      mark.col,
      { end_col = mark.end_col, hl_group = mark.group }
    )
  end
  for _, mark in ipairs(rendered.numbers) do
    vim.api.nvim_buf_set_extmark(
      panel.bufnr,
      NAMESPACE,
      mark.lnum - 1,
      0,
      { virt_text = mark.chunks, virt_text_pos = "right_align" }
    )
  end

  panel.entry_by_line = rendered.entry_by_line
  panel.order = rendered.order
  panel.seen_header = rendered.seen_header
end

---Give the panel the side it was configured for, instead of splitting it with
---the file tree. Detected by filetype so nothing here depends on neo-tree
---being installed.
local function clear_the_way()
  if config.options.neo_tree ~= "close" then return end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree" then pcall(vim.api.nvim_win_close, win, false) end
  end
end

---How the panel's window looks: a list, not a file being edited.
local WINDOW_OPTIONS = {
  number = false,
  relativenumber = false,
  signcolumn = "no",
  foldcolumn = "0",
  wrap = false,
  spell = false,
  list = false,
  cursorline = true,
  winfixwidth = true,
  -- The panel's window shows the panel and nothing else: a buffer opened into
  -- it — by `<C-^>`, by a file picker, by any plugin that reuses "the last
  -- window used" — would leave the list with no window of its own and the
  -- reviewer reading a file in a strip forty columns wide.
  winfixbuf = true,
}

---@param panel ReviewPanelState
---@return integer winid
local function open_win(panel)
  local options = config.options

  -- How an ordinary window of this tabpage looks, read from the window the
  -- panel is about to split — the window it opens cannot be asked afterwards,
  -- because Neovim remembers these options per buffer and gives the panel its
  -- own look back every time its buffer is shown again. It is kept because the
  -- window can outlive the panel: alone in its tabpage the panel gives the
  -- window up instead of closing it, and what stays behind has to be an
  -- ordinary window again.
  local splitting = vim.api.nvim_get_current_win()
  panel.window_options = {}
  for name in pairs(WINDOW_OPTIONS) do
    panel.window_options[name] = vim.wo[splitting][name]
  end
  -- The winbar is the editor's, and not the window being split: that one can be
  -- a side of a diff, whose bar is the diff's and would come back over an empty
  -- window.
  panel.window_options.winbar = vim.go.winbar

  opening = panel.bufnr
  local ok, win = pcall(vim.api.nvim_open_win, panel.bufnr, true, {
    split = options.position,
    win = -1, -- split against the whole tabpage, so the panel spans its height
    width = options.width,
  })
  opening = nil
  if not ok then error(win, 0) end

  for name, value in pairs(WINDOW_OPTIONS) do
    vim.wo[win][name] = value
  end

  panel.winid = win
  -- What it got, and not what was asked for: a screen narrower than the
  -- configured width gives less, and that is the width to keep.
  panel.width = vim.api.nvim_win_get_width(win)

  return win
end

---Leave a window showing an empty buffer, which is what a window that stops
---showing the panel gets when there is nothing to go back to.
---@param win integer winid
local function empty(win)
  vim.api.nvim_win_call(win, function() vim.cmd "enew" end)
end

---Give a window the look of an ordinary window of this tabpage: what the panel
---read from the window it split, which is what a window that stops showing the
---panel — the one it gives up, or one it was cloned into — has to look like
---again.
---@param panel ReviewPanelState
---@param win integer winid
local function make_ordinary(panel, win)
  for name, value in pairs(panel.window_options or {}) do
    vim.wo[win][name] = value
  end
end

---Leave the window on screen without the panel in it: an empty buffer, and the
---look the window had before the panel took it.
---@param panel ReviewPanelState
---@param win integer winid
local function give_up_win(panel, win)
  -- The window only takes another buffer once it stops being the panel's: the
  -- `winfixbuf` that keeps everyone else out keeps this out too.
  vim.wo[win].winfixbuf = false
  empty(win)
  make_ordinary(panel, win)
  panel.winid = nil
end

---Read what the panel is listing: the working tree of its directory, or the
---commit — or range of commits — it was switched to, in the repository that
---directory is in.
---@param panel ReviewPanelState
---@return ReviewStatus|nil status
---@return ReviewGitFailure|nil failure
local function read(panel)
  if not panel.rev then return git.status(panel.cwd) end

  local root = git.root(panel.cwd)
  if not root then return nil, "not_a_repo" end
  if panel.oldest then return git.range_status(root, panel.oldest, panel.rev) end
  return git.commit_status(root, panel.rev)
end

---Read git and put the result on screen.
---@param panel ReviewPanelState
local function draw(panel)
  local status, failure = read(panel)
  panel.root = status and status.root or nil
  -- Read back from what git answered, and not from what was asked for: the
  -- mode is what the annotations written from here are filed under, and a
  -- commit that could not be read is no mode to file anything under.
  panel.mode = mode.of(status)
  render(
    panel,
    build_lines {
      status = status,
      failure = failure,
      seen = panel.root and state.seen(panel.root) or {},
      counts = panel.root and annotation.counts(panel.root, panel.mode) or {},
      collapsed = panel.seen_collapsed,
    }
  )
  -- What the mode offers is put back with every read, and not only when the
  -- panel is entered: the mode is only known once git has answered, and the
  -- key that switches to a commit reads it after the panel is already on
  -- screen.
  apply_actions(panel)
end

---Put the panel of this tabpage on screen and focused, with its actions in
---place, ready to be drawn.
---@return ReviewPanelState
local function surface()
  local panel = ensure_panel()

  local win = M.win()
  if win then
    vim.api.nvim_set_current_win(win)
  else
    clear_the_way()
    open_win(panel)
  end

  -- Entering the panel is what puts its actions in place, and opening it from
  -- inside it enters nothing.
  apply_actions(panel)

  return panel
end

---Open the panel of this tabpage, on the repository containing the current
---directory. Opening an already open panel focuses it and re-reads git.
function M.open()
  local panel = surface()
  -- On screen again, whoever brought it: from here on, a list that leaves is
  -- one somebody took away again.
  panel.hidden_for_diff = nil

  -- Reopening comes back to what was being reviewed, commit mode included: `q`
  -- to get the screen back and the key again to return is one gesture, not a
  -- reason to lose the commit. Unless the tabpage moved to another repository
  -- since — the commit was chosen in the one the panel was on, and a sha of
  -- somewhere else is nothing to go looking for here.
  local cwd = vim.fn.getcwd()
  if panel.rev and panel.root and git.root(cwd) ~= panel.root then
    panel.rev, panel.oldest = nil, nil
  end
  panel.cwd = cwd

  draw(panel)
  -- The review walked while the list was off screen, and the cursor is where it
  -- was left. It has to be where the review is, which is what the reviewer is
  -- coming back to look at.
  if panel.at then go_to(panel, M.win(), panel.at) end
end

---Review a commit: the panel of this tabpage stops listing the working tree
---and lists the files of that commit, in its own section and with exactly the
---keys it already had (ADR-0001). It opens if it was closed — choosing a
---commit is asking to review it, and the review happens in the list.
---@param rev string anything git resolves to a commit
function M.commit(rev)
  local panel = surface()
  -- The repository is the panel's, which is the one the commit was chosen in;
  -- the current directory only answers for a panel that was never opened.
  panel.cwd = panel.cwd or vim.fn.getcwd()
  panel.rev, panel.oldest = rev, nil
  draw(panel)
end

---Review a range of commits: the panel lists what changed across the whole of
---it, in the same section and with the same keys a single commit is reviewed
---with. It is the gesture of reading a finished feature at once, instead of
---one commit at a time.
---
---The range includes both ends: `oldest` is reviewed too, not just what came
---after it.
---@param oldest string the commit the range starts at
---@param newest string the commit it ends at
function M.range(oldest, newest)
  -- A range of one commit is that commit: nothing about the review of it is
  -- different, and a header naming it twice would say otherwise.
  if oldest == newest then return M.commit(newest) end

  -- Two commits that are not on the same line of history have no range between
  -- them, and the graph draws every branch: two lines one above the other on
  -- screen are not always one after the other in the repository. What a
  -- comparison of two divergent tips lists is everything that differs between
  -- the branches — a list far longer than what was selected, and not a range at
  -- all. Asked before anything moves, so the reviewer is left where they are,
  -- in the graph, able to select again.
  local existing = current()
  local root = git.root((existing and existing.cwd) or vim.fn.getcwd())
  if root and not git.is_ancestor(root, oldest, newest) then
    vim.notify(NOT_A_RANGE, vim.log.levels.WARN)
    return
  end

  local panel = surface()
  panel.cwd = panel.cwd or vim.fn.getcwd()
  panel.rev, panel.oldest = newest, oldest
  draw(panel)
end

---Go back to reviewing the working tree, which is where the reviewer left off.
---Like `commit`, it opens the panel if it was closed: asking for the working
---tree with nothing on screen is asking for the list.
function M.worktree()
  local showing = M.win() and current()
  if showing and not showing.rev then
    -- Silence would read as a key that did not work, and this is the key
    -- pressed by someone who lost track of which mode they are in.
    vim.notify "review: o painel já está no working tree."
    return
  end

  local panel = surface()
  panel.cwd = panel.cwd or vim.fn.getcwd()
  panel.rev, panel.oldest = nil, nil
  draw(panel)
end

---Close the panel. The buffer stays, so reopening is instant.
function M.close()
  local panel, win = current(), M.win()
  if not panel or not win then return end

  -- Alone in its tabpage the panel has no window to hand the space back to:
  -- closing it would take the tabpage — and the `:tcd` of the repository being
  -- reviewed — along with it, or fail outright in the last tabpage and leave
  -- the panel on screen with `toggle` stuck on closing it. It gives up the
  -- window instead.
  -- The winid the panel keeps is dropped by the `WinClosed` this fires, which
  -- is the one place a closed window is forgotten, whoever closed it.
  if #vim.api.nvim_tabpage_list_wins(0) > 1 and pcall(vim.api.nvim_win_close, win, false) then return end
  give_up_win(panel, win)
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

---The diff was closed from inside it: go back to the list.
---
---The list the diff took off the screen (`close_on_diff`) comes back, and only
---that one: a list the reviewer closed themselves was taken away to read with
---the width of the editor, and the diff closing is not them asking for it again.
---It comes back after the diff is gone and not before: the last window of the
---diff stays in the tabpage, and the list opens beside it with its own width.
---Opened first, the list was left alone when the diff closed its windows, and
---took the whole screen.
function M.back_from_diff()
  local panel = current()
  if not panel then return end

  if panel.hidden_for_diff and not M.win() then
    M.open()
    return
  end
  local win = M.win()
  if win then vim.api.nvim_set_current_win(win) end
end

---Re-read git and re-render the panels on screen that `wants` accepts.
---
---Panels, plural, and not only the one of the current tabpage: a panel is per
---tabpage but the repository is not, and an action here — or a file saved
---anywhere in the editor — changes the state of whatever other panel is
---listing the same repository.
---@param wants fun(panel: ReviewPanelState): boolean
local function redraw(wants)
  forget_closed_tabs()
  for tab, panel in pairs(panels) do
    if win_of(tab, panel) and wants(panel) then draw(panel) end
  end
end

---Re-read git and re-render every panel that is on screen. Does nothing when
---none is.
function M.refresh()
  redraw(function() return true end)
end

---Whether `path` is a file of the repository rooted at `root`. Tried again
---through symlinks before answering no: the two come from different places —
---git's own answer and the name the file was opened under — and one symlink on
---the way to the repository is enough for the same file to arrive written two
---ways.
---@param root string absolute path of the repository root
---@param path string absolute path
---@return boolean
local function is_inside(root, path)
  if vim.startswith(path, root .. "/") then return true end
  local real_root, real_path = vim.uv.fs_realpath(root), vim.uv.fs_realpath(path)
  return real_root ~= nil and real_path ~= nil and vim.startswith(real_path, real_root .. "/")
end

---The panel follows the repository without being asked: what the editor itself
---changed on disk is listed without the reviewer having to ask for it. Only the
---panels listing the file that was saved — reading a repository is five git
---processes, and every other panel's list is exactly as it was.
vim.api.nvim_create_autocmd("BufWritePost", {
  group = GROUP,
  desc = "Atualizar os painéis de revisão que listam o arquivo salvo",
  callback = function(event)
    local path = vim.api.nvim_buf_get_name(event.buf)
    if path == "" then return end
    redraw(function(panel) return panel.root ~= nil and is_inside(panel.root, path) end)
  end,
})

---The actions of the panel are in the context menu while the reviewer is in the
---panel, and nowhere else: the right button on a file of the repository opens
---the editor's own menu, with nothing of ours in it.
---
---The panel of this tabpage, and not any buffer of the panel's filetype: every
---action reads the panel of the tabpage it runs in, so its own buffer shown
---somewhere else is not a panel to act on.
vim.api.nvim_create_autocmd("BufEnter", {
  group = GROUP,
  desc = "Pôr as ações do painel de revisão no menu de contexto, e tirá-las fora dele",
  callback = function(event)
    -- Read straight from the panels of the tabpages, and not through `current`:
    -- this runs on every buffer the editor enters, and `current` sweeps the
    -- panels of closed tabpages, deleting buffers — which is not something to
    -- do underneath whatever else is walking the buffer list at that moment.
    local panel = panels[vim.api.nvim_get_current_tabpage()]
    if panel and panel.bufnr == event.buf then
      -- The keys are put back with the menu, and not only when the panel opens:
      -- the options can have been changed since, and the menu showing a key the
      -- panel no longer has is the one thing it must never do.
      apply_actions(panel)
    else
      menu.remove()
    end
  end,
})

---Coming back to the editor is the other moment the list would be old, and
---there is no telling what happened outside it: every panel is re-read.
vim.api.nvim_create_autocmd("FocusGained", {
  group = GROUP,
  desc = "Atualizar o painel de revisão",
  callback = function() M.refresh() end,
})

---The panel a buffer belongs to, of whatever tabpage: a panel buffer shown in
---another tabpage's window is as much out of place as one shown beside its own
---list.
---@param bufnr integer
---@return ReviewPanelState|nil
local function panel_of_buf(bufnr)
  for _, panel in pairs(panels) do
    if panel.bufnr == bufnr then return panel end
  end
end

---Put a window that ended up showing the panel back to what it was showing:
---the buffer it had before, or an empty one when there is none to come back to.
---@param panel ReviewPanelState
---@param win integer winid
local function evict(panel, win)
  local previous = vim.api.nvim_win_call(win, function() return vim.fn.bufnr "#" end)
  if previous > 0 and previous ~= panel.bufnr and vim.api.nvim_buf_is_valid(previous) then
    pcall(vim.api.nvim_win_set_buf, win, previous)
  end
  if vim.api.nvim_win_get_buf(win) == panel.bufnr then pcall(empty, win) end

  -- A window split off the panel's came with the panel's look: no line numbers,
  -- a fixed width. What is in it now is the reviewer's, and has to look like it.
  make_ordinary(panel, win)
end

---The list stays in the window it opened in. `winfixbuf` keeps other buffers out
---of the panel's window; this is the other direction — the panel's buffer shown
---in a window that is not its own, which is what `<C-^>`, a file picker or any
---plugin reusing "the last window used" does, and what leaves the reviewer with
---the list across the whole screen.
---
---`WinNew` as well as `BufWinEnter`: splitting a window shows the same buffer in
---the new one without ever displaying it — no `BufWinEnter` — and a split of the
---panel is two panels on screen, of which `win_of` can only answer one.
vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew" }, {
  group = GROUP,
  desc = "Tirar o buffer do painel de revisão de qualquer janela que não seja a dele",
  callback = function(event)
    if event.buf == opening then return end
    local panel = panel_of_buf(event.buf)
    if not panel then return end
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if win ~= panel.winid and vim.api.nvim_win_get_buf(win) == panel.bufnr then evict(panel, win) end
    end
  end,
})

---The panel window of a tabpage, when the width it has is its own to keep:
---alone in the tabpage it has the width of the screen, which is neither a
---choice to remember nor a width to restore. Floating windows do not count —
---one of them on top of the layout leaves the panel just as alone in it.
---@param panel ReviewPanelState
---@param tab integer tabpage handle
---@return integer|nil winid
local function win_with_its_own_width(panel, tab)
  local win = win_of(tab, panel)
  if not win or not panel.width then return nil end

  local sharing = vim.tbl_filter(
    function(other) return other ~= win and vim.api.nvim_win_get_config(other).relative == "" end,
    vim.api.nvim_tabpage_list_wins(tab)
  )
  if #sharing == 0 then return nil end
  return win
end

---Run `act` on every panel that is on screen with a width of its own.
---@param act fun(panel: ReviewPanelState, win: integer)
local function for_each_panel_window(act)
  for tab, panel in pairs(panels) do
    if vim.api.nvim_tabpage_is_valid(tab) then
      local win = win_with_its_own_width(panel, tab)
      if win then act(panel, win) end
    end
  end
end

---Give the panel back the width it keeps. `winfixwidth` holds that width while
---windows open and close, and lets go when a neighbour is resized over it: the
---columns come out of the panel, and the list stays narrow from there on.
---@param panel ReviewPanelState
---@param win integer winid
local function restore_width(panel, win)
  if vim.api.nvim_win_get_width(win) ~= panel.width then pcall(vim.api.nvim_win_set_width, win, panel.width) end
end

---Take the width the panel has now as the width it keeps.
---@param panel ReviewPanelState
---@param win integer winid
local function adopt_width(panel, win) panel.width = vim.api.nvim_win_get_width(win) end

---Whether the width every window has just been given came from the editor
---itself being resized. The terminal getting narrower takes columns from the
---panel like any other accident of layout, and it does it while the reviewer
---may well be sitting in the panel — which is otherwise how the panel tells the
---reviewer's own resizing apart. Read and cleared by the `WinResized` the
---resize goes on to fire.
local editor_resized = false

vim.api.nvim_create_autocmd("VimResized", {
  group = GROUP,
  desc = "Marcar que quem mudou as larguras foi o editor, e não o revisor",
  callback = function() editor_resized = true end,
})

vim.api.nvim_create_autocmd("WinResized", {
  group = GROUP,
  desc = "Devolver ao painel de revisão a largura dele, ou tomar como dele a que o revisor lhe deu",
  callback = function()
    local by_the_editor = editor_resized
    editor_resized = false

    for_each_panel_window(function(panel, win)
      -- Resizing the panel with it focused is the reviewer asking for a wider
      -- list, and that width becomes the panel's. A neighbour resized over it
      -- is an accident of layout, and the panel takes its width back.
      if not by_the_editor and win == vim.api.nvim_get_current_win() then
        adopt_width(panel, win)
      else
        restore_width(panel, win)
      end
    end)
  end,
})

---A window is still on screen while `WinClosed` runs, and the columns it frees
---are handed out after it: the width is put back once that is done. Never taken
---as the panel's own — a window closing is nobody asking for a wider list.
vim.api.nvim_create_autocmd("WinClosed", {
  group = GROUP,
  desc = "Devolver ao painel de revisão a largura dele depois de uma janela fechar",
  callback = function(event)
    -- The window the panel was in is gone with it, however it was closed: the
    -- winid is dropped here so nothing has to tell a stale one from a live one.
    local closed = tonumber(event.match)
    for _, panel in pairs(panels) do
      if panel.winid == closed then panel.winid = nil end
    end

    vim.schedule(function() for_each_panel_window(restore_width) end)
  end,
})

---With `close_on_diff`, going into the diff of a line takes the list off the
---screen: the reviewer came to read, and the diff gets the width of the editor.
---However they went in — the key that opens the line, a window command from a
---preview already drawn, a click — it is the focus arriving at a side that says
---so, and not the key. The panel asks the diff which diff that is: the panel is
---built on top of the diff, and that is the direction the two know each other
---in (ADR-0009).
---
---A preview draws its diff without entering it, so sweeping the list leaves it
---where it is. On the turn of the loop after, because a side is entered while
---the diff is still being built, before it is known to be the diff of a line.
vim.api.nvim_create_autocmd("WinEnter", {
  group = GROUP,
  desc = "Tirar o painel da tela quando o revisor entra no diff de uma linha",
  callback = function()
    if not config.options.close_on_diff then return end
    local win = vim.api.nvim_get_current_win()

    vim.schedule(function()
      if vim.api.nvim_get_current_win() ~= win or not diff.is_line_diff(win) then return end
      local panel = current()
      if not panel or not M.win() then return end

      panel.hidden_for_diff = true
      M.close()
    end)
  end,
})

return M
