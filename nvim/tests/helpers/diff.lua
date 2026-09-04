-- Reading the diff the panel builds, the way the reviewer sees it: the windows
-- that are in diff mode on screen, ordered from left to right.

local M = {}

---@return integer[] winids in diff mode, left to right
function M.windows()
  local wins = vim.tbl_filter(function(win) return vim.wo[win].diff end, vim.api.nvim_tabpage_list_wins(0))
  table.sort(wins, function(a, b) return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2] end)
  return wins
end

---The lines of each side of the diff, left to right.
---@return string[][]
function M.sides()
  return vim.tbl_map(
    function(win) return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false) end,
    M.windows()
  )
end

---The buffer name of each side, left to right.
---@return string[]
function M.names()
  return vim.tbl_map(function(win) return vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) end, M.windows())
end

---The winbar of each side, left to right: what says which version the window
---is showing, and where the keys of the diff are written.
---@return string[]
function M.winbars()
  return vim.tbl_map(function(win) return vim.wo[win].winbar end, M.windows())
end

---The window on the right of the diff, the side the reviewer edits.
---@return integer|nil winid
function M.right() return M.windows()[2] end

---Send keys to the diff as the reviewer would type them, from the side they
---are reading: the rightmost one, which is where the diff leaves them.
---@param keys string
function M.feed(keys)
  local wins = M.windows()
  assert(#wins > 0, "there is no diff on screen")
  vim.api.nvim_set_current_win(wins[#wins])
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

---The line the cursor is on in the side the reviewer is reading, which is where
---the keys that walk the changes of a file leave it.
---@return integer
function M.cursor()
  local wins = M.windows()
  assert(#wins > 0, "there is no diff on screen")
  return vim.api.nvim_win_get_cursor(wins[#wins])[1]
end

---Put the cursor at the top of the side the reviewer is reading, which is where
---a file that has just been opened is read from.
function M.to_top()
  local wins = M.windows()
  assert(#wins > 0, "there is no diff on screen")
  vim.api.nvim_win_set_cursor(wins[#wins], { 1, 0 })
end

---Whether the reviewer is inside the diff, which is where its keys leave them.
---@return boolean
function M.focused() return vim.tbl_contains(M.windows(), vim.api.nvim_get_current_win()) end

---The file the diff on screen is of, read from the side the reviewer edits:
---the name of the buffer, short of the directories, which is how the sides are
---told apart.
---@return string
function M.reading()
  local names = M.names()
  assert(#names > 0, "there is no diff on screen")
  return vim.fn.fnamemodify(names[#names], ":t")
end

return M
