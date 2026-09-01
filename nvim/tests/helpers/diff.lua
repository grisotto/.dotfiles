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

---The window on the right of the diff, the side the reviewer edits.
---@return integer|nil winid
function M.right() return M.windows()[2] end

return M
