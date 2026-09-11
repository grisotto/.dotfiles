-- The help window: every key of where the reviewer is, with what it does.
--
-- Read the way the long entry is read — the window found on screen by its
-- filetype, and the lines rendered in it — because that is what the reviewer
-- sees: a key, and beside it what the key does.

local M = {}

local FILETYPE = "review-help"

---@return integer|nil winid
function M.win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == FILETYPE then return win end
  end
end

---@return boolean
function M.is_open() return M.win() ~= nil end

---What the window says it lists, which is the title drawn on its border.
---@return string
function M.title()
  local win = assert(M.win(), "the help is not open")
  local title = vim.api.nvim_win_get_config(win).title
  return type(title) == "table" and vim.trim(title[1][1]) or vim.trim(tostring(title))
end

---Every key listed, by the key as it is written, with what it does.
---@return table<string, string>
function M.keys()
  local win = assert(M.win(), "the help is not open")
  local keys = {}
  for _, line in ipairs(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false)) do
    local key, desc = line:match "^%s*(%S+)%s%s+(.-)%s*$"
    if key then keys[key] = desc end
  end
  return keys
end

---Send keys to the window as the reviewer would type them.
---@param keys string
function M.feed(keys)
  local win = assert(M.win(), "the help is not open")
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

return M
