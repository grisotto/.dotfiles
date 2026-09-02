-- The long entry: the window the reviewer writes an annotation of several
-- lines in.
--
-- Read the way the panel is read — by finding the window on screen by its
-- filetype and looking at the lines rendered in it — because that is what the
-- reviewer sees: a box with the text already there, which they edit and then
-- write or throw away.

local M = {}

local FILETYPE = "review-annotation"

---@return integer|nil winid
function M.win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == FILETYPE then return win end
  end
end

---@return boolean
function M.is_open() return M.win() ~= nil end

---The text currently in the entry, one string per line.
---@return string[]
function M.lines()
  local win = assert(M.win(), "the long entry is not open")
  return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)
end

---What the entry says it is about, which is the title drawn on its border.
---@return string
function M.title()
  local win = assert(M.win(), "the long entry is not open")
  local title = vim.api.nvim_win_get_config(win).title
  return type(title) == "table" and vim.trim(title[1][1]) or vim.trim(tostring(title))
end

---Send keys to the entry as the reviewer would type them.
---@param keys string
function M.feed(keys)
  local win = assert(M.win(), "the long entry is not open")
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

---Type `text` into the empty entry, newlines included, the way the reviewer
---types it: insert mode, and back to normal mode at the end.
---@param text string
function M.type(text) M.feed("i" .. (text:gsub("\n", "<CR>")) .. "<Esc>") end

---Write the annotation and close the entry.
function M.save() M.feed "<C-s>" end

---Throw away what was typed and close the entry.
function M.cancel() M.feed "q" end

return M
