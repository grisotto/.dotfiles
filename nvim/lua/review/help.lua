---Every key of where the reviewer is, in a window of its own.
---
---The winbar of the diff writes two keys, and the context menu is the panel's
---alone: the rest of what the panel and the diff answer to — the way back of
---every pair, the keys that are global — is here, one key away from wherever
---the reviewer is reading. A shortcut nobody sees is the point missed
---(ADR-0008), and what goes in comes from the list the keys are mapped from,
---handed in by whoever maps them, so the window cannot list a key that is not
---there.
local M = {}

---The filetype of the window, which is also how it is found on screen.
local FILETYPE = "review-help"

---What the keys are drawn with, over the column they are in.
local NAMESPACE = vim.api.nvim_create_namespace "review-help"

---The key every floating window of the editor is closed with, besides the one
---that opened this one.
local CLOSE = "q"

---@class ReviewHelpKey
---@field key string as the mapping is written
---@field desc string what it does

---@param text string
---@param width integer columns to fill
---@return string padded on the right, measured as it is drawn and not in bytes
local function padded(text, width) return text .. (" "):rep(math.max(width - vim.fn.strdisplaywidth(text), 0)) end

---Open the window with the cursor in it. It closes on the key that opened it,
---on `q`, and when the reviewer leaves it any other way, and the cursor goes
---back to where it was.
---@param title string what the keys are of, drawn on the border
---@param keys ReviewHelpKey[] in the order they are listed
---@param toggle string the key that opened it
function M.open(title, keys, toggle)
  local column = 0
  for _, key in ipairs(keys) do
    column = math.max(column, vim.fn.strdisplaywidth(key.key))
  end

  local lines, longest = {}, 0
  for _, key in ipairs(keys) do
    lines[#lines + 1] = ("  %s  %s"):format(padded(key.key, column), key.desc)
    longest = math.max(longest, vim.fn.strdisplaywidth(lines[#lines]))
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].filetype = FILETYPE
  for index, key in ipairs(keys) do
    vim.api.nvim_buf_set_extmark(bufnr, NAMESPACE, index - 1, 2, { end_col = 2 + #key.key, hl_group = "Special" })
  end

  local from = vim.api.nvim_get_current_win()
  local width = math.max(math.min(longest + 2, vim.o.columns - 4), 1)
  local height = math.max(math.min(#lines, vim.o.lines - 4), 1)
  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(math.floor((vim.o.lines - height) / 2) - 1, 0),
    col = math.max(math.floor((vim.o.columns - width) / 2), 0),
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
    footer = (" %s ou %s fecha "):format(toggle, CLOSE),
  })
  -- A description wider than the editor goes on under itself, lined up past
  -- the key, instead of being cut where the window ends.
  vim.wo[win].wrap = true
  vim.wo[win].breakindent = true
  vim.wo[win].breakindentopt = "shift:" .. (column + 4)
  vim.wo[win].cursorline = true

  local function close()
    if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
    if vim.api.nvim_win_is_valid(from) then vim.api.nvim_set_current_win(from) end
  end
  for _, lhs in ipairs { toggle, CLOSE } do
    vim.keymap.set("n", lhs, close, { buffer = bufnr, nowait = true, desc = "Fechar a ajuda" })
  end

  -- Left any other way — a click elsewhere, a window command — it closes too: a
  -- list of keys left floating over what the reviewer went on to read is in the
  -- way of it. Scheduled, because a window cannot be closed while the editor is
  -- still leaving it.
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = bufnr,
    once = true,
    desc = "Fechar a ajuda que o revisor deixou",
    callback = function()
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
      end)
    end,
  })
end

return M
