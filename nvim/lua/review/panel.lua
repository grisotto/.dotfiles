---The review panel itself: the window, the rendered sections and the map from
---a rendered line back to the entry on it.
local actions = require "review.actions"
local annotation = require "review.annotation"
local config = require "review.config"
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

---What a file with annotations carries after its path, so the reviewer sees
---from the list where they left remarks.
local ANNOTATED = "✎"

---The line an entry is rendered on. A conflict carries a two-letter code,
---everything else one letter; padding keeps the paths in one column either way.
---The count of annotations comes after the path, where a long path pushes it
---off the panel rather than pushing the name of the file off it.
---
---The count is the file's, so a file listed in two sections — a staged change
---and an unstaged one — shows it on both lines. That is what it is: an
---annotation is written about a file and a line, never about the section the
---reviewer happened to be reading when they wrote it.
---@param entry ReviewEntry
---@param counts table<string, integer> annotations by path
---@return string
local function entry_line(entry, counts)
  local line = ("  %-2s %s"):format(entry.status, displayable(entry.path))
  local count = counts[entry.path]
  return count and ("%s  %s %d"):format(line, ANNOTATED, count) or line
end

---@class ReviewRendered what one draw puts on screen
---@field lines string[]
---@field entry_by_line table<integer, ReviewEntry> 1-indexed, only entry lines
---@field dimmed integer[] lines drawn as already seen, where they stand
---@field seen_header integer|nil line the Vistos header is on, when rendered

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
  local lines, entry_by_line, dimmed, seen_header = {}, {}, {}, nil

  if not status then
    return {
      lines = { "Revisão", "", MESSAGES[drawing.failure] or MESSAGES.git_failed },
      entry_by_line = entry_by_line,
      dimmed = dimmed,
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
  if not status.has_commits then
    lines[#lines + 1] = ""
    lines[#lines + 1] = MESSAGES.no_commits
  end

  local sections = sections_of(status)
  local grouped = group(unseen, sections)
  for _, section in ipairs(sections) do
    local entries = grouped[section.key]
    if #entries > 0 then
      lines[#lines + 1] = ""
      lines[#lines + 1] = ("%s (%d)"):format(section.label, #entries)
      for _, entry in ipairs(entries) do
        lines[#lines + 1] = entry_line(entry, counts)
        entry_by_line[#lines] = entry
        if in_place and entry.content and seen[entry.content] then dimmed[#dimmed + 1] = #lines end
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
        lines[#lines + 1] = entry_line(entry, counts)
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

  panel = { bufnr = create_buf(), entry_by_line = {}, seen_collapsed = true, mapped = {}, mode = mode.WORKTREE }
  panels[vim.api.nvim_get_current_tabpage()] = panel
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

---Everything the panel does, in the order the context menu lists it: what the
---reviewer came to do first, the file itself next, then what changes the
---repository, and the panel's own keys last.
---
---One list for the keys and for the menu, because the menu exists to show the
---keys: two lists would drift, and the entry showing the wrong key is worse
---than no menu at all. `label` is the menu's short wording and `desc` the long
---one which-key shows, where there is room to say what the key does in a
---conflict too.
---@return { key: string, label: string, desc: string, run: fun() }[]
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
    {
      key = mappings.stage,
      label = "Mover para staged",
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
      label = "Tirar de staged",
      desc = "Tirar o arquivo de staged",
      run = on_entry(function(target)
        actions.unstage(target)
        M.refresh()
      end),
    },
    {
      key = mappings.discard,
      label = "Descartar as mudanças",
      desc = "Descartar as mudanças do arquivo, com confirmação",
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
      desc = "Gerar o relatório da revisão e pôr os pontos anotados na quickfix",
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
      nowait = true,
      desc = action.desc,
    })
    panel.mapped[#panel.mapped + 1] = action.key
  end
end

---Put the panel's actions where the reviewer reaches them: the keys of its
---buffer and the entries of the context menu.
---
---From one list and at one moment, because the menu is there to show the keys.
---Sharing the list is not enough on its own: refreshed at different times, the
---menu would go on showing the key of a mapping that is no longer there.
---@param panel ReviewPanelState
local function apply_actions(panel)
  local keys = panel_actions()
  apply_mappings(panel, keys)
  menu.install(keys)
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

return M
