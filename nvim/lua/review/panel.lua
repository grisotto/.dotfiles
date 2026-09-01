---The review panel itself: the window, the rendered sections and the map from
---a rendered line back to the entry on it.
local actions = require "review.actions"
local config = require "review.config"
local git = require "review.git"
local state = require "review.state"

local M = {}

local FILETYPE = "review"

---Where the dimming of a seen file is drawn, when the vistos are configured to
---stay in place.
local NAMESPACE = vim.api.nvim_create_namespace(FILETYPE)

---Sections in the order the reviewer reads them: conflicts first, because
---they are what has to be dealt with before anything else.
local SECTIONS = {
  { key = "conflicts", label = "Conflitos" },
  { key = "staged", label = "Staged" },
  { key = "unstaged", label = "Unstaged" },
  { key = "untracked", label = "Untracked" },
}

---The section seen files go to: last, because it is what the reviewer is done
---with, and collapsed, because the list is there to show what is left.
local SEEN = {
  label = "Vistos",
  collapsed = "▸",
  expanded = "▾",
}

local MESSAGES = {
  not_a_repo = "Fora de um repositório git.",
  git_failed = "Não foi possível ler o estado do git.",
  no_commits = "Repositório sem commits.",
  no_changes = "Nenhuma mudança.",
}

---@class ReviewPanelState the panel of one tabpage
---@field bufnr integer the panel buffer, reused across open and close
---@field cwd string|nil the directory the panel is reviewing
---@field root string|nil the repository root of what is listed
---@field entry_by_line table<integer, ReviewEntry> 1-indexed, only entry lines
---@field seen_collapsed boolean whether the Vistos section is showing its files
---@field seen_header integer|nil line the Vistos header is on, when it is rendered
---@field mapped string[] keys currently mapped in the panel buffer
---@field window_options table<string, any>|nil what the panel's window looked like before it took it

---The panel is single (ADR-0001), but single *per tabpage*: a reviewer keeps
---one repository per tabpage (`:tcd`), and a panel sharing its buffer across
---tabpages would show one tabpage's repository — and its lines — inside the
---other's.
---@type table<integer, ReviewPanelState>
local panels = {}

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
---@param tab integer tabpage handle
---@param panel ReviewPanelState
---@return integer|nil winid nil when that panel is closed
local function win_of(tab, panel)
  if not vim.api.nvim_tabpage_is_valid(tab) then return nil end
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
---@return table<ReviewSection, ReviewEntry[]>
local function group(entries)
  local grouped = {}
  for _, section in ipairs(SECTIONS) do
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

---Split the entries into the ones still to review and the ones already seen.
---An entry whose content git could not identify is never seen: there is no key
---it could have been marked under.
---@param entries ReviewEntry[]
---@param seen table<string, true> contents marked as seen
---@return ReviewEntry[] unseen
---@return ReviewEntry[] already_seen
local function split_seen(entries, seen)
  local unseen, already_seen = {}, {}
  for _, entry in ipairs(entries) do
    table.insert(entry.content and seen[entry.content] and already_seen or unseen, entry)
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

---The line an entry is rendered on. A conflict carries a two-letter code,
---everything else one letter; padding keeps the paths in one column either way.
---@param entry ReviewEntry
---@return string
local function entry_line(entry) return ("  %-2s %s"):format(entry.status, displayable(entry.path)) end

---@class ReviewRendered what one draw puts on screen
---@field lines string[]
---@field entry_by_line table<integer, ReviewEntry> 1-indexed, only entry lines
---@field dimmed integer[] lines drawn as already seen, where they stand
---@field seen_header integer|nil line the Vistos header is on, when rendered

---@param status ReviewStatus|nil nil when the repository could not be read
---@param failure ReviewGitFailure|nil
---@param seen table<string, true> contents marked as seen
---@param collapsed boolean whether the Vistos section hides its files
---@return ReviewRendered
local function build_lines(status, failure, seen, collapsed)
  local lines, entry_by_line, dimmed, seen_header = {}, {}, {}, nil

  if not status then
    return {
      lines = { "Revisão", "", MESSAGES[failure] or MESSAGES.git_failed },
      entry_by_line = entry_by_line,
      dimmed = dimmed,
    }
  end

  local unseen, already_seen = split_seen(status.entries, seen)
  -- Dimmed in place: nothing leaves its section, and what is seen is drawn as
  -- read instead of moved.
  local in_place = config.options.seen_display == "dimmed"
  if in_place then unseen = status.entries end

  lines[#lines + 1] = "Revisão · " .. status.branch
  -- The progress is what is left to read, so it only means something while
  -- there is something to read. It counts changes and not files, the same way
  -- the sections do: a file with a staged and an unstaged change is two diffs
  -- to read, and a header counting it once would say the review was over with
  -- one of them still on the list.
  if #status.entries > 0 then
    lines[#lines] = ("%s · %d/%d vistos"):format(lines[#lines], #already_seen, #status.entries)
  end
  if not status.has_commits then
    lines[#lines + 1] = ""
    lines[#lines + 1] = MESSAGES.no_commits
  end

  local grouped = group(unseen)
  for _, section in ipairs(SECTIONS) do
    local entries = grouped[section.key]
    if #entries > 0 then
      lines[#lines + 1] = ""
      lines[#lines + 1] = ("%s (%d)"):format(section.label, #entries)
      for _, entry in ipairs(entries) do
        lines[#lines + 1] = entry_line(entry)
        entry_by_line[#lines] = entry
        if in_place and entry.content and seen[entry.content] then dimmed[#dimmed + 1] = #lines end
      end
    end
  end

  if not in_place and #already_seen > 0 then
    table.sort(already_seen, by_path)
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("%s %s (%d)"):format(collapsed and SEEN.collapsed or SEEN.expanded, SEEN.label, #already_seen)
    seen_header = #lines
    if not collapsed then
      for _, entry in ipairs(already_seen) do
        lines[#lines + 1] = entry_line(entry)
        entry_by_line[#lines] = entry
      end
    end
  end

  if #status.entries == 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = MESSAGES.no_changes
  end

  return { lines = lines, entry_by_line = entry_by_line, dimmed = dimmed, seen_header = seen_header }
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

  panel = { bufnr = create_buf(), entry_by_line = {}, seen_collapsed = true, mapped = {} }
  panels[vim.api.nvim_get_current_tabpage()] = panel
  return panel
end

---What the line under the cursor points at, and where it was read from.
---@return ReviewTarget|nil nil on a line that is not a file
local function target_under_cursor()
  local panel = current()
  local win = M.win()
  if not win or not panel or not panel.root then return nil end
  local entry = panel.entry_by_line[vim.api.nvim_win_get_cursor(win)[1]]
  if not entry then return nil end
  return { entry = entry, root = panel.root, panel = win }
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

---The panel's keys are short, local to its buffer, and their descriptions are
---what which-key shows.
---@param panel ReviewPanelState
local function apply_mappings(panel)
  local bufnr = panel.bufnr
  for _, key in ipairs(panel.mapped) do
    pcall(vim.keymap.del, "n", key, { buffer = bufnr })
  end
  panel.mapped = {}

  local mappings = config.options.mappings
  local keys = {
    { key = mappings.close, desc = "Fechar o painel de revisão", run = M.close },
    { key = mappings.refresh, desc = "Atualizar o painel de revisão", run = M.refresh },
    {
      key = mappings.diff,
      desc = "Abrir o diff da linha (merge tool, num conflito); expandir a seção Vistos",
      run = function()
        if not toggle_seen_section() then on_entry(actions.open)() end
      end,
    },
    {
      key = mappings.diff_alternate,
      desc = "Abrir na apresentação alternativa (diffview; com a versão base, num conflito)",
      run = on_entry(actions.open_alternate),
    },
    {
      key = mappings.toggle_seen,
      desc = "Marcar ou desmarcar o arquivo como visto",
      -- The list is what tells the reviewer the mark took: it has to be
      -- redrawn, and only the panel knows how to redraw itself.
      run = on_entry(function(target)
        actions.toggle_seen(target)
        M.refresh()
      end),
    },
    {
      key = mappings.stage,
      desc = "Mover o arquivo para staged",
      -- Same as the mark above: what tells the reviewer the file moved is the
      -- list, and only the panel knows how to redraw itself.
      run = on_entry(function(target)
        actions.stage(target)
        M.refresh()
      end),
    },
    {
      key = mappings.unstage,
      desc = "Tirar o arquivo de staged",
      run = on_entry(function(target)
        actions.unstage(target)
        M.refresh()
      end),
    },
    {
      key = mappings.discard,
      desc = "Descartar as mudanças do arquivo, com confirmação",
      -- The redraw goes along instead of following the call: the answer to the
      -- question arrives after this returns.
      run = on_entry(function(target) actions.discard(target, M.refresh) end),
    },
    {
      key = mappings.copy_relative_path,
      desc = "Copiar o caminho a partir da raiz do projeto do arquivo",
      run = on_entry(actions.copy_relative_path),
    },
    {
      key = mappings.copy_absolute_path,
      desc = "Copiar o caminho absoluto do arquivo",
      run = on_entry(actions.copy_absolute_path),
    },
    { key = mappings.open, desc = "Abrir o arquivo na janela principal", run = on_entry(actions.open_file) },
    { key = mappings.open_split, desc = "Abrir o arquivo num split", run = on_entry(actions.open_file_in_split) },
  }
  for _, action in ipairs(keys) do
    vim.keymap.set("n", action.key, function() action.run() end, {
      buffer = bufnr,
      nowait = true,
      desc = action.desc,
    })
    panel.mapped[#panel.mapped + 1] = action.key
  end
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

  panel.entry_by_line = rendered.entry_by_line
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

  local win = vim.api.nvim_open_win(panel.bufnr, true, {
    split = options.position,
    win = -1, -- split against the whole tabpage, so the panel spans its height
    width = options.width,
  })
  for name, value in pairs(WINDOW_OPTIONS) do
    vim.wo[win][name] = value
  end

  return win
end

---Leave the window on screen without the panel in it: an empty buffer, and the
---look the window had before the panel took it.
---@param panel ReviewPanelState
---@param win integer winid
local function give_up_win(panel, win)
  vim.api.nvim_win_call(win, function() vim.cmd "enew" end)
  for name, value in pairs(panel.window_options or {}) do
    vim.wo[win][name] = value
  end
end

---Read git and put the result on screen.
---@param panel ReviewPanelState
local function draw(panel)
  local status, failure = git.status(panel.cwd)
  panel.root = status and status.root or nil
  local seen = panel.root and state.seen(panel.root) or {}
  render(panel, build_lines(status, failure, seen, panel.seen_collapsed))
end

---Open the panel of this tabpage, on the repository containing the current
---directory. Opening an already open panel focuses it and re-reads git.
function M.open()
  local panel = ensure_panel()
  panel.cwd = vim.fn.getcwd()
  apply_mappings(panel)

  local win = M.win()
  if win then
    vim.api.nvim_set_current_win(win)
  else
    clear_the_way()
    open_win(panel)
  end

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

local GROUP = vim.api.nvim_create_augroup("review-panel", { clear = true })

---The panel follows the repository without being asked: what the editor itself
---changed on disk is listed without the reviewer having to ask for it. Only the
---panels listing the file that was saved — reading a repository is three git
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

---Coming back to the editor is the other moment the list would be old, and
---there is no telling what happened outside it: every panel is re-read.
vim.api.nvim_create_autocmd("FocusGained", {
  group = GROUP,
  desc = "Atualizar o painel de revisão",
  callback = function() M.refresh() end,
})

return M
