-- Selecting lines in the window being read, the way the reviewer does it.
--
-- A key pressed on a selection reads the selection while visual mode is still
-- on, so the selection and the key go to the editor as one run of typed keys —
-- the way `graph.choose_range` selects commits in the graph.

local M = {}

---Select from line `first` to line `last` of the current window and press
---`keys` on the selection. A `last` above `first` is a selection made from the
---bottom up.
---@param first integer
---@param last integer
---@param keys string in the notation of a mapping, `<Leader>` included
function M.press_on_lines(first, last, keys)
  vim.api.nvim_win_set_cursor(0, { first, 0 })
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(("V%dG%s"):format(last, keys), true, false, true), "x", false)
end

return M
