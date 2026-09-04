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
---@field panel integer|nil winid of the panel the line was read from; nil when
---the list is not on screen, which is the reviewer reading a file with the
---whole width of the editor
---@field mode ReviewMode the review the line is part of: the working tree, or a commit

---Whether the release is a click on a line of the list, which is the only
---release that means anything in one.
---
---The press already put the cursor on the right line; what is left to ask is
---whether the button came up over a line at all. Below the list the editor
---answers the last line of the buffer — and sends the cursor there too — so
---without this a click on the empty rows would act on whatever the list
---happens to end with. What tells the two apart is the row inside the window,
---which is not clamped to the text. A release outside the window is a drag
---that ended elsewhere, and means nothing here either.
---
---A release carrying no position at all is not a click: `<LeftRelease>` also
---arrives fed by a script or a macro, and there the list reads its own cursor,
---like every other key it has.
---
---Here rather than in the panel because the graph of commits is the same kind
---of list, with the same empty rows below it and the same key on a line.
---@param win integer winid of the list
---@return boolean
function M.is_click_on_a_line(win)
  local mouse = vim.fn.getmousepos()
  if mouse.winid == 0 then return true end
  if mouse.winid ~= win then return false end
  local line = vim.fn.line("w0", win) + mouse.winrow - 1
  return line <= vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
end

---@param panel integer|nil winid; nil is a list that is not on screen, and then
---every ordinary window of the tabpage is beside it
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
---
---With no panel on screen it is any ordinary window of the tabpage: the diff
---the reviewer is reading takes the whole width, and what is opened next takes
---the place of what is there.
---@param panel integer|nil winid; nil while the list is not on screen
---@param bufnr integer buffer to show if the window has to be created
---@return integer winid
function M.content(panel, bufnr)
  local win = beside_the_panel(panel)
  if win then return win end

  -- Splitting the panel halves it, so it gets its width back right after —
  -- the width it has, not the configured one, which the reviewer may have
  -- already adjusted by hand.
  local width = panel and vim.api.nvim_win_get_width(panel)
  local opened = vim.api.nvim_open_win(bufnr, false, {
    split = config.options.position == "left" and "right" or "left",
    win = panel or 0,
  })
  if panel and width then vim.api.nvim_win_set_width(panel, width) end
  return opened
end

---What the reviewer has open beside the panel, when it is a file of their own:
---the buffer of the first ordinary window there that is showing one.
---
---It is what a consultation that takes that space has to come back to. Our own
---buffers are never it — a side of a diff, the graph, the file read in another
---rev: they are wiped when they leave the screen, so there is nothing in them
---to come back to.
---@param panel integer winid
---@return integer|nil bufnr
function M.file_beside(panel)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= panel and vim.api.nvim_win_get_config(win).relative == "" then
      local bufnr = vim.api.nvim_win_get_buf(win)
      if vim.bo[bufnr].buftype == "" then return bufnr end
    end
  end
end

---A window to the right of `win`, which is where the next side of a diff goes:
---the second of two, and the second and third of the three versions of a
---conflict.
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
