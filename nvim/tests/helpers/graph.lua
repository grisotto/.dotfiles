-- Reading the graph of commits the way the reviewer sees it: by looking at the
-- window that is on screen and the lines rendered in it, exactly as the panel
-- is read. The graph is a list too, and choosing a commit in it is putting the
-- cursor on a line and pressing the key that opens it.

local M = {}

local FILETYPE = "review-graph"

---@return integer|nil winid
function M.win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == FILETYPE then return win end
  end
end

---@return boolean
function M.is_open() return M.win() ~= nil end

---Every line currently rendered in the graph.
---@return string[]
function M.lines()
  local win = assert(M.win(), "the commit graph is not open")
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
---@return integer lnum 1-indexed
local function line_of(pattern)
  for lnum, line in ipairs(M.lines()) do
    if line:match(pattern) then return lnum end
  end
  error(("no commit matching %q in the graph:\n%s"):format(pattern, table.concat(M.lines(), "\n")))
end

---Put the cursor on the commit whose line matches `pattern`, the way the
---reviewer moves to it before choosing it.
---@param pattern string a Lua pattern
function M.focus(pattern)
  local win = assert(M.win(), "the commit graph is not open")
  vim.api.nvim_win_set_cursor(win, { line_of(pattern), 0 })
end

---The line the cursor is on, which is the commit about to be chosen.
---@return string
function M.current()
  local win = assert(M.win(), "the commit graph is not open")
  return M.lines()[vim.api.nvim_win_get_cursor(win)[1]]
end

---Send keys to the graph as the reviewer would type them.
---@param keys string
function M.feed(keys)
  local win = assert(M.win(), "the commit graph is not open")
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

---Choose the commit whose line matches `pattern`: the gesture that switches
---the panel to reviewing it.
---@param pattern string a Lua pattern
function M.choose(pattern)
  M.focus(pattern)
  M.feed "<CR>"
end

---Choose the range from one commit's line to another's: selecting the lines of
---the graph and pressing the key that opens them, which is how the reviewer
---asks for a whole feature at once. The two patterns can come in either order,
---the way a selection can be made upwards or downwards.
---@param from string a Lua pattern
---@param to string a Lua pattern
function M.choose_range(from, to)
  local last = line_of(to)
  M.focus(from)
  M.feed(("V%dG<CR>"):format(last))
end

---Filter the graph by a branch: the key that opens the search, and the branch
---the reviewer picks in it. What is picked is answered through the editor's
---selection UI, which the confirm helper installs.
---@param branch string exactly as the search offers it
function M.filter_by(branch)
  require("tests.helpers.confirm").answer(branch)
  M.feed "b"
end

return M
