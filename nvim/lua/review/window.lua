---Where what the panel opens lands.
---
---The panel keeps its side of the tabpage and everything it opens goes into
---the window next to it, in the same tabpage, so the list stays visible while
---the reviewer reads.
local config = require "review.config"

local M = {}

---@class ReviewTarget what a line of the panel points at
---@field entry ReviewEntry the file on that line
---@field root string absolute path of the repository root
---@field panel integer winid of the panel the line was read from

---@param panel integer winid
---@return integer|nil winid the first window of the tabpage that is not the panel
local function beside_the_panel(panel)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    -- A floating window is something on top of the layout, not a place to open
    -- a file into.
    if win ~= panel and vim.api.nvim_win_get_config(win).relative == "" then return win end
  end
end

---The window the panel opens into, created showing `bufnr` when the panel is
---alone in the tabpage.
---@param panel integer winid
---@param bufnr integer buffer to show if the window has to be created
---@return integer winid
function M.content(panel, bufnr)
  local win = beside_the_panel(panel)
  if win then return win end

  -- Splitting the panel halves it, so it gets its width back right after —
  -- the width it has, not the configured one, which the reviewer may have
  -- already adjusted by hand.
  local width = vim.api.nvim_win_get_width(panel)
  local opened = vim.api.nvim_open_win(bufnr, false, {
    split = config.options.position == "left" and "right" or "left",
    win = panel,
  })
  vim.api.nvim_win_set_width(panel, width)
  return opened
end

---A window to the right of `win`, which is where the second side of a diff goes.
---@param win integer winid
---@param bufnr integer
---@return integer winid
function M.beside(win, bufnr) return vim.api.nvim_open_win(bufnr, false, { split = "right", win = win }) end

---A window below `win`, which is the split the reviewer asks for.
---@param win integer winid
---@param bufnr integer
---@return integer winid
function M.below(win, bufnr) return vim.api.nvim_open_win(bufnr, false, { split = "below", win = win }) end

return M
