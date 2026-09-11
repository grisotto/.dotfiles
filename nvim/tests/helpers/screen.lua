-- The screen of the test editor, the way the reviewer sees it.
--
-- Read cell by cell after the editor has drawn, for what no buffer shows
-- because it only exists once the editor composes the windows: a float over the
-- panel, the title and the footer on a border, virtual text where it lands
-- against the edge of a window, the colour a line ends up with once every mark
-- on it is drawn. It is what mini.test's `child.get_screenshot` does, in this
-- editor instead of a child one.
--
-- The size of the screen is fixed by `tests/minimal_init.lua`.

local M = {}

---Let the editor draw what is pending: a turn of the loop, for what the plugin
---schedules after a key, and then two redraws. The specs run from `-c`, before
---`VimEnter`, and there the first `:redraw` after a float opens draws it in the
---corner of the screen, without what is under it; the second puts it in place.
---Neither the turn of the loop nor `:redraw!` does.
local function draw()
  vim.wait(20)
  vim.cmd.redraw()
  vim.cmd.redraw()
end

---@class ScreenRow
---@field row integer where it is on the screen, 1-indexed
---@field col integer the screen column of its first cell, 1-indexed
---@field cells string[] what each cell shows; the second half of a wide
---character shows nothing

---@param row integer 1-indexed
---@param first integer first column, 1-indexed
---@param last integer last column, inclusive
---@return ScreenRow
local function read(row, first, last)
  local cells = {}
  for col = first, last do
    cells[#cells + 1] = vim.fn.screenstring(row, col)
  end
  return { row = row, col = first, cells = cells }
end

---@param rows ScreenRow[]
---@return string[]
local function texts(rows)
  return vim.tbl_map(function(row) return table.concat(row.cells) end, rows)
end

---@param rows string[]
---@param pattern string a Lua pattern
---@return string|nil row
---@return integer|nil index
local function matching(rows, pattern)
  for index, row in ipairs(rows) do
    if row:match(pattern) then return row, index end
  end
end

---The rectangle of the screen a window covers. A window of the layout starts at
---its winbar, which its height already counts. A float with a border starts at
---the corner of the border, and its height and width leave the border out; the
---border is taken to go all around it.
---@param win integer
---@return ScreenRow[]
local function window_rows(win)
  draw()
  local row, col = unpack(vim.fn.win_screenpos(win))
  local border = vim.api.nvim_win_get_config(win).border
  local edges = (border == nil or border == "none") and 0 or 2
  local height = vim.api.nvim_win_get_height(win) + edges
  local last = col + vim.api.nvim_win_get_width(win) + edges - 1

  local rows = {}
  for r = row, row + height - 1 do
    rows[#rows + 1] = read(r, col, last)
  end
  return rows
end

---Every row of the screen: the windows, the floats over them with their
---borders, the winbars, the statuslines and the command line.
---@return string[]
function M.lines()
  draw()
  local rows = {}
  for row = 1, vim.o.lines do
    rows[#rows + 1] = read(row, 1, vim.o.columns)
  end
  return texts(rows)
end

---The rows of the screen a window covers, cut to its columns: its winbar, in a
---window of the layout, and its border, in a float. What is drawn there,
---whichever window drew it — which is how a float is read in its place, and
---not found anywhere on the screen, where a float drawn in the wrong place would
---show the same border.
---@param win integer
---@return string[]
function M.window(win) return texts(window_rows(win)) end

---The row of the screen a window covers that matches `pattern`.
---@param win integer
---@param pattern string a Lua pattern
---@return string|nil
function M.window_line_matching(win, pattern) return (matching(M.window(win), pattern)) end

---How `text` looks where it is drawn, on the row of the window matching
---`pattern`: the attribute of its first cell. The number means nothing on its
---own — `screenattr()` only tells whether two cells are drawn alike —, so it is
---for comparing with another look. The highlight group is read from the marks.
---@param win integer
---@param pattern string a Lua pattern
---@param text string plain text on that row
---@return integer
function M.look(win, pattern, text)
  local rows = window_rows(win)
  local lines = texts(rows)
  local line, index = matching(lines, pattern)
  if not line then error(("no row of the window matching %q:\n%s"):format(pattern, table.concat(lines, "\n"))) end
  local start = line:find(text, 1, true)
  if not start then error(("no %q on the row %q"):format(text, line)) end

  local row, offset = rows[index], 1
  for i, cell in ipairs(row.cells) do
    if offset == start then return vim.fn.screenattr(row.row, row.col + i - 1) end
    offset = offset + #cell
  end
  error(("%q does not start on a cell of the row %q"):format(text, line))
end

return M
