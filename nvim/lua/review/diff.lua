---The two-way diff the panel builds in its own tabpage.
---
---What is compared comes from the section of the line: on a staged line, the
---HEAD against the index; on an unstaged or untracked line, the index against
---the working tree. The working tree side is the file itself, not a copy of
---it, so the reviewer can fix what they are reading right there.
---
---A conflicted file has no content at stage zero of the index, so no two-way
---diff of it means anything. Conflicts go to the merge tool instead, which is
---the diffview's (ADR-0005).
local git = require "review.git"
local window = require "review.window"

local M = {}

---@class ReviewDiffSide
---@field label string what the side is called in the buffer name
---@field rev string|nil rev to read the content from; nil is the file on disk
---@field path string path relative to the repository root

---The windows this module opened in each tabpage, so opening another diff
---there can take them down. Per tabpage, like the panel: the diff of one
---tabpage is not the diff the reviewer is reading in another.
---@type table<integer, integer[]>
local wins_by_tab = {}

---@param entry ReviewEntry
---@return ReviewDiffSide left
---@return ReviewDiffSide right
local function sides(entry)
  local index = { label = "índice", rev = ":0", path = entry.path }
  if entry.section == "staged" then
    -- A renamed file has its old content under the old path in HEAD.
    return { label = "HEAD", rev = "HEAD", path = entry.orig_path or entry.path }, index
  end
  -- Unstaged and untracked read the same way: what the index has of the file —
  -- nothing at all, for an untracked one — against what is on disk.
  return index, { label = "working tree", rev = nil, path = entry.path }
end

---A read-only buffer with the content of one side. Wiped with the window that
---shows it: these buffers are the diff, and they have no life after it.
---@param root string
---@param side ReviewDiffSide
---@return integer bufnr
local function rev_buf(root, side)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, git.show(root, side.rev, side.path) or { "" })
  vim.bo[bufnr].modifiable = false

  -- The name is what the reviewer reads to tell the sides apart, and it is
  -- also all the syntax highlighting has to go on.
  pcall(vim.api.nvim_buf_set_name, bufnr, ("review://%s/%s"):format(side.label, side.path))
  vim.bo[bufnr].filetype = vim.filetype.match { filename = side.path } or ""

  return bufnr
end

---@param root string
---@param path string
---@return integer bufnr the buffer of the file itself
local function file_buf(root, path)
  local bufnr = vim.fn.bufadd(root .. "/" .. path)
  vim.fn.bufload(bufnr)
  return bufnr
end

---Take down the diff of this tabpage. The rev buffers go with their windows;
---the working tree side is the reviewer's own file buffer and stays, unsaved
---edits included.
function M.close()
  local tab = vim.api.nvim_get_current_tabpage()
  local open = wins_by_tab[tab] or {}
  wins_by_tab[tab] = nil
  for _, win in ipairs(open) do
    if vim.api.nvim_win_is_valid(win) then
      -- Closing the last window of a tabpage closes the tabpage with it. The
      -- diff can go without taking the reviewer's tab along.
      if #vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(win)) > 1 then
        pcall(vim.api.nvim_win_close, win, true)
      else
        vim.api.nvim_win_call(win, function() vim.cmd "diffoff" end)
      end
    end
  end
end

---Build the diff of `target` beside its panel, replacing whatever diff was
---there. Focus goes to the working tree side, which is the one to edit.
---@param target ReviewTarget
function M.open(target)
  local left, right = sides(target.entry)
  local left_buf = rev_buf(target.root, left)
  local right_buf = right.rev and rev_buf(target.root, right) or file_buf(target.root, right.path)

  M.close()

  local left_win = window.content(target.panel, left_buf)
  vim.api.nvim_win_set_buf(left_win, left_buf)
  local right_win = window.beside(left_win, right_buf)

  local opened = { left_win, right_win }
  -- A tabpage that is gone took its diff with it; what is left here is only
  -- the winids of tabpages still on screen.
  for tab in pairs(wins_by_tab) do
    if not vim.api.nvim_tabpage_is_valid(tab) then wins_by_tab[tab] = nil end
  end
  wins_by_tab[vim.api.nvim_get_current_tabpage()] = opened

  for _, win in ipairs(opened) do
    vim.api.nvim_win_call(win, function() vim.cmd "diffthis" end)
  end
  vim.api.nvim_set_current_win(right_win)
end

return M
