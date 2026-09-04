-- Reading the review panel the way the reviewer sees it: by looking at the
-- window that is on screen and the lines rendered in it.

local M = {}

local FILETYPE = "review"

---@return integer|nil winid
function M.win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == FILETYPE then return win end
  end
end

---@return boolean
function M.is_open() return M.win() ~= nil end

---Every line currently rendered in the panel.
---@return string[]
function M.lines()
  local win = M.win()
  assert(win, "the review panel is not open")
  return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
end

---@param pattern string a Lua pattern
---@return string|nil line
function M.line_matching(pattern)
  for _, line in ipairs(M.lines()) do
    if line:match(pattern) then return line end
  end
end

---@param pattern string a Lua pattern
---@return string[] lines
function M.lines_matching(pattern)
  return vim.tbl_filter(function(line) return line:match(pattern) ~= nil end, M.lines())
end

---How wide the icon column is, in characters: the icon the panel draws at the
---start of every entry line, and the space after it.
local ICON_WIDTH = 2

---An entry line as the assertions read it: without its indentation and without
---the icon column, so what is asserted stays the status and the path. The icon
---is mini.icons's, and has an assertion of its own against what mini.icons
---answers.
---@param line string as it is rendered
---@return string|nil entry nil when the line is not an entry
local function entry_of(line)
  local entry = line:match "^  (.+)$"
  if not entry then return nil end
  -- The harness always has mini.icons, so an entry line without an icon column
  -- is the panel being wrong and not a shape to accommodate: taking two
  -- characters off it anyway would eat half the status code and show up as a
  -- confusing failure two assertions later. The column is one character and the
  -- space after it, and the status code that follows never starts with a space.
  assert(
    entry:sub(1, 1) ~= " " and vim.fn.strcharpart(entry, 1, 1) == " " and vim.fn.strcharpart(entry, 2, 1) ~= " ",
    ("entry line without an icon column: %q"):format(line)
  )
  return (vim.fn.strcharpart(entry, ICON_WIDTH))
end

---Whether a line is the header of `section`. A collapsible section — "Vistos"
---is the only one — carries the marker of its state before the label, and the
---reviewer reads it as the same header either way.
---@param line string
---@param section string e.g. "Staged"
---@return boolean
local function is_header(line, section)
  local text = line:match "^▸ (.*)$" or line:match "^▾ (.*)$" or line
  return text:match("^" .. section .. " %(%d+%)$") ~= nil
end

---The entry lines rendered under a section header, in order.
---@param section string e.g. "Staged"
---@return string[] entries without their indentation and without their icon
function M.section(section)
  local entries, inside = {}, false
  for _, line in ipairs(M.lines()) do
    if is_header(line, section) then
      inside = true
    elseif inside then
      local entry = entry_of(line)
      if entry then
        entries[#entries + 1] = entry
      else
        break
      end
    end
  end
  return entries
end

---The count a section header reports, or nil when the section is not rendered.
---@param section string
---@return integer|nil
function M.section_count(section)
  for _, line in ipairs(M.lines()) do
    if is_header(line, section) then return tonumber(line:match "%((%d+)%)") end
  end
end

---Put the cursor on the entry of `section` whose line matches `pattern`, the
---way the reviewer would move to it before pressing a key. The section matters:
---the same file can be listed in more than one of them.
---@param section string e.g. "Staged"
---@param pattern string a Lua pattern
function M.focus(section, pattern)
  local win = assert(M.win(), "the review panel is not open")
  local inside = false
  for lnum, line in ipairs(M.lines()) do
    if is_header(line, section) then
      inside = true
    elseif inside then
      local entry = entry_of(line)
      if not entry then break end
      if entry:match(pattern) then
        vim.api.nvim_win_set_cursor(win, { lnum, 0 })
        return
      end
    end
  end
  error(("no entry matching %q under %q"):format(pattern, section))
end

---Put the cursor on the header line of a section, the way the reviewer would
---move to it before expanding or collapsing it.
---@param section string e.g. "Vistos"
function M.focus_section(section)
  local win = assert(M.win(), "the review panel is not open")
  for lnum, line in ipairs(M.lines()) do
    if is_header(line, section) then
      vim.api.nvim_win_set_cursor(win, { lnum, 0 })
      return
    end
  end
  error(("no section header for %q"):format(section))
end

---The line the cursor is on in the panel, which is where the review is.
---@return integer lnum 1-indexed
function M.cursor()
  local win = assert(M.win(), "the review panel is not open")
  return vim.api.nvim_win_get_cursor(win)[1]
end

---What is written on the line the cursor is on, which is what the reviewer is
---looking at after a key moved it. On an entry, read like the entries of a
---section: without the icon column.
---@return string
function M.current()
  local line = M.lines()[M.cursor()]
  local entry = entry_of(line)
  return entry and "  " .. entry or line
end

---Put the cursor on the first line of the panel, which is never an entry.
function M.focus_header()
  local win = assert(M.win(), "the review panel is not open")
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
end

---Every mark the panel drew, with what it says: the dimming of a seen file, the
---colour of a status code, the numbers put beside a line.
---@return { lnum: integer, col: integer, details: table }[]
local function marks()
  local win = assert(M.win(), "the review panel is not open")
  local namespace = vim.api.nvim_get_namespaces()[FILETYPE]
  if not namespace then return {} end

  local found = vim.api.nvim_buf_get_extmarks(vim.api.nvim_win_get_buf(win), namespace, 0, -1, { details = true })
  return vim.tbl_map(function(mark) return { lnum = mark[2] + 1, col = mark[3], details = mark[4] } end, found)
end

---The line the panel renders matching `pattern`, by number.
---@param pattern string a Lua pattern
---@param lines string[]
---@return integer lnum 1-indexed
local function line_of(pattern, lines)
  for index, line in ipairs(lines) do
    if line:match(pattern) then return index end
  end
  error(("no line matching %q"):format(pattern))
end

---The entry lines the panel is showing dimmed, which is what it does to a seen
---file when the vistos are configured to stay where they are. Only the entries:
---the line of information under the header is drawn dimmed too, and it is not a
---file the reviewer is done with.
---@return string[] entries without their indentation and without their icon
function M.dimmed()
  local lines = M.lines()
  local entries = {}
  for _, mark in ipairs(marks()) do
    if mark.details.line_hl_group then
      local entry = entry_of(lines[mark.lnum])
      if entry then entries[#entries + 1] = entry end
    end
  end
  return entries
end

---Whether the panel is drawing the line matching `pattern` dimmed, which is how
---the line of information is set apart from the header above it.
---@param pattern string a Lua pattern
---@return boolean
function M.is_dimmed(pattern)
  local lnum = line_of(pattern, M.lines())
  for _, mark in ipairs(marks()) do
    if mark.lnum == lnum and mark.details.line_hl_group then return true end
  end
  return false
end

---What the panel is drawing over the line matching `pattern`: the highlight
---group of each stretch of it, by the text that stretch covers. It is how the
---colour of a line is read — the icon in the colour mini.icons gives it, the
---status code in the colour of its kind of change.
---@param pattern string a Lua pattern
---@return table<string, string> group by the text it is drawn over
function M.highlights(pattern)
  local lines = M.lines()
  local lnum = line_of(pattern, lines)

  local groups = {}
  for _, mark in ipairs(marks()) do
    if mark.lnum == lnum and mark.details.hl_group then
      groups[lines[lnum]:sub(mark.col + 1, mark.details.end_col)] = mark.details.hl_group
    end
  end
  return groups
end

---The numbers the panel puts beside the line matching `pattern`: the `+N −M`
---drawn as virtual text at the right edge of the list, which is what says how
---big a change is before it is opened.
---@param pattern string a Lua pattern
---@return string|nil text nil when that line carries no numbers
function M.numbers(pattern)
  local lnum = line_of(pattern, M.lines())
  for _, mark in ipairs(marks()) do
    if mark.lnum == lnum and mark.details.virt_text then
      return table.concat(vim.tbl_map(function(chunk) return chunk[1] end, mark.details.virt_text))
    end
  end
end

---@return integer width in columns
function M.width()
  local win = assert(M.win(), "the review panel is not open")
  return vim.api.nvim_win_get_width(win)
end

---Click the left button on the line the cursor is already on.
---
---A headless editor has no screen to point at, so the click is sent in two
---halves: putting the cursor on the line stands for the press, which is what
---moves it there, and the release is what the panel reacts to. A release fed
---as a key carries no position with it, which is the release the panel reads
---off its own cursor; where the click landed is verified by hand.
function M.click_here() M.feed "<LeftRelease>" end

---Click the entry of `section` whose line matches `pattern`.
---@param section string e.g. "Staged"
---@param pattern string a Lua pattern
function M.click(section, pattern)
  M.focus(section, pattern)
  M.click_here()
end

---Click the header line of a section.
---@param section string e.g. "Vistos"
function M.click_section(section)
  M.focus_section(section)
  M.click_here()
end

---Tell the editor that the cursor of the panel moved.
---
---A headless editor never fires `CursorMoved` on its own: the event belongs to
---the main loop waiting for a key, and a headless editor never gets there — the
---same reason `WinResized` is fired by hand. It is fired on the panel's buffer
---and not on the current one, so that a test can also fire it from outside the
---panel, which is where the preview must not draw anything.
function M.cursor_moved()
  local win = assert(M.win(), "the review panel is not open")
  vim.api.nvim_exec_autocmds("CursorMoved", { buffer = vim.api.nvim_win_get_buf(win) })
end

---Move the cursor in the panel with the key that moves it, the way the reviewer
---does, and tell the editor it moved.
---@param keys string
function M.move(keys)
  M.feed(keys)
  M.cursor_moved()
end

---Send keys to the panel as the reviewer would type them.
---@param keys string
function M.feed(keys)
  local win = assert(M.win(), "the review panel is not open")
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

return M
