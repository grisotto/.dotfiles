-- Putting the test editor back the way it was found.
--
-- A spec that opens a diff, a file or a panel in a tabpage of its own leaves
-- all of it on screen. The next spec would then start in an editor another one
-- arranged — with its windows, its file buffers, and, in the case of the panel,
-- the state it keeps per tabpage, like whether the Vistos section is expanded.

local M = {}

---Leave the editor with a single empty window in a single tabpage and no
---leftover file buffers.
---
---Back to the first tabpage before dropping the others: `tabonly!` keeps the
---current one, and keeping a tabpage of the spec that just ran would carry its
---panel along. The panel's own buffer survives on purpose — it is reused
---across open and close, and deleting it out from under the plugin is not
---something a reviewer ever does.
function M.reset()
  require("review").close()
  vim.cmd "tabfirst"
  vim.cmd "tabonly!"
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= vim.api.nvim_get_current_win() then pcall(vim.api.nvim_win_close, win, true) end
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].filetype ~= "review" then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end
  end
end

return M
