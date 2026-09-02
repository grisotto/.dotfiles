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
---@return string[] entries without their indentation
function M.section(section)
  local entries, inside = {}, false
  for _, line in ipairs(M.lines()) do
    if is_header(line, section) then
      inside = true
    elseif inside then
      local entry = line:match "^  (.+)$"
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
      local entry = line:match "^  (.+)$"
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

---Put the cursor on the first line of the panel, which is never an entry.
function M.focus_header()
  local win = assert(M.win(), "the review panel is not open")
  vim.api.nvim_win_set_cursor(win, { 1, 0 })
end

---The entry lines the panel is showing dimmed, which is what it does to a seen
---file when the vistos are configured to stay where they are.
---@return string[] entries without their indentation
function M.dimmed()
  local win = assert(M.win(), "the review panel is not open")
  local namespace = vim.api.nvim_get_namespaces()[FILETYPE]
  if not namespace then return {} end

  local lines = M.lines()
  local marks = vim.api.nvim_buf_get_extmarks(vim.api.nvim_win_get_buf(win), namespace, 0, -1, {})
  return vim.tbl_map(function(mark) return (lines[mark[2] + 1]:match "^  (.+)$") end, marks)
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

---Send keys to the panel as the reviewer would type them.
---@param keys string
function M.feed(keys)
  local win = assert(M.win(), "the review panel is not open")
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

return M
