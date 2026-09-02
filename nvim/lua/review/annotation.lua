---What the reviewer writes about a point of the code.
---
---An annotation is tied to a file and, when it was written from the code
---itself, to a line of it. Along with the text it records the anchor — the
---text of that line at the moment it was written (ADR-0003). The anchor is
---only recorded here; whoever uses it to find the line again after the file
---changed is the review report.
---
---Writing where something is already written edits it, rather than piling a
---second observation on the same point: two remarks about one line are one
---remark revised.
---
---The entry is of one line by default, because nearly every review remark is a
---sentence, and there is a second one for the times it is not (ADR-0006 is the
---same idea applied to the diff). Both are the editor's own: the short one is
---`vim.ui.input`, so it arrives wherever the reviewer already answers
---questions, and the long one is a window with a scratch buffer in it.
local git = require "review.git"
local root = require "review.root"
local state = require "review.state"

local M = {}

---@class ReviewPoint what an annotation is attached to
---@field root string absolute path of the repository root
---@field path string the file, from the repository root
---@field mode string the mode of the review it is being written in
---@field line integer|nil the line; absent on a file annotation
---@field anchor string|nil the text of that line; absent on a file annotation

---The whole file, without a line: what a line of the panel points at is a
---file, and the remark written from there is about all of it.
---@param repository string absolute path of the repository root
---@param path string the file, from the repository root
---@param mode ReviewMode the review it is being written in
---@return ReviewPoint
function M.point_of_file(repository, path, mode) return { root = repository, path = path, mode = mode.key } end

---The point the reviewer is on in the file they are reading: the line the
---cursor is on, in the repository that file belongs to.
---@param mode ReviewMode the review it is being written in
---@return ReviewPoint|nil nil when this buffer is not a file of a repository
function M.point_under_cursor(mode)
  local bufnr = vim.api.nvim_get_current_buf()
  -- Everything the panel puts on screen that is not the file itself — the
  -- panel, a side of the diff, the long entry — is a buffer with nothing on
  -- disk behind it, and there is no line of the repository to tie a remark to
  -- in one of those.
  if vim.bo[bufnr].buftype ~= "" then return nil end

  local file = vim.api.nvim_buf_get_name(bufnr)
  local directory = file ~= "" and vim.fs.dirname(file) or ""
  if vim.fn.isdirectory(directory) == 0 then return nil end

  local repository = git.root(directory)
  local path = repository and root.relative_to(repository, file)
  if not repository or not path then return nil end

  return {
    root = repository,
    path = path,
    mode = mode.key,
    line = vim.api.nvim_win_get_cursor(0)[1],
    -- The anchor is the line as it stands right now, which is what the remark
    -- being written is about (ADR-0003).
    anchor = vim.api.nvim_get_current_line(),
  }
end

---The annotations of one review: the ones written in that mode, in the order
---they were written. The remarks of another mode belong to another review, and
---neither the panel's counts nor the report are about them.
---@param repository string absolute path of the repository root
---@param mode ReviewMode
---@return ReviewAnnotation[]
function M.of_mode(repository, mode)
  return vim.tbl_filter(function(written) return written.mode == mode.key end, state.annotations(repository))
end

---How many annotations each file of the repository has in this mode, by path,
---so the panel can put the count on the file's line.
---@param repository string absolute path of the repository root
---@param mode ReviewMode
---@return table<string, integer>
function M.counts(repository, mode)
  local counts = {}
  for _, written in ipairs(M.of_mode(repository, mode)) do
    counts[written.path] = (counts[written.path] or 0) + 1
  end
  return counts
end

---What the entry says it is about, so a reviewer who pressed the key on the
---wrong line sees it before writing.
---@param point ReviewPoint
---@return string
local function about(point)
  if point.line then return ("Anotação em %s:%d"):format(point.path, point.line) end
  return ("Anotação em %s"):format(point.path)
end

---The filetype of the long entry's buffer, which is also how it is found on
---screen.
local ENTRY_FILETYPE = "review-annotation"

---The keys of the long entry. They are the window's own, like the answers to
---the question asked before discarding: what they do is written on its border,
---and there is nothing else to press in there.
local SAVE, CANCEL = "<C-s>", "q"

---How much of the editor the long entry takes: enough for a paragraph, and
---never wider than the editor itself.
local ENTRY_WIDTH, ENTRY_HEIGHT = 72, 10

---Ask for the text in a window of its own, prefilled with what is already
---written. The reviewer edits it as they edit anything else, and the two keys
---on the border say how it ends.
---@param point ReviewPoint
---@param text string what is already written, empty for a new annotation
---@param done fun(written: string|nil) nil when the reviewer gave it up
local function long_entry(point, text, done)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = ENTRY_FILETYPE
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(text, "\n", { plain = true }))

  local width = math.min(ENTRY_WIDTH, vim.o.columns - 4)
  local height = math.min(ENTRY_HEIGHT, math.max(vim.o.lines - 4, 1))
  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(math.floor((vim.o.lines - height) / 2) - 1, 0),
    col = math.max(math.floor((vim.o.columns - width) / 2), 0),
    style = "minimal",
    border = "rounded",
    title = " " .. about(point) .. " ",
    footer = (" %s grava · %s cancela "):format(SAVE, CANCEL),
  })

  -- The window closes exactly once, with exactly one answer: the keys close it
  -- themselves, and a reviewer who closes it any other way — `:q`, another
  -- window taking the screen — gave the annotation up, which the autocommand
  -- below is what notices.
  local answered = false
  ---@param written string|nil
  local function finish(written)
    if answered then return end
    answered = true
    if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, true) end
    done(written)
  end

  vim.keymap.set({ "n", "i" }, SAVE, function()
    -- Read before closing: the buffer is wiped along with its window.
    finish(table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n"))
  end, { buffer = bufnr, nowait = true, desc = "Gravar a anotação" })

  vim.keymap.set("n", CANCEL, function() finish(nil) end, {
    buffer = bufnr,
    nowait = true,
    desc = "Cancelar a anotação",
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    once = true,
    desc = "Desistir da anotação cuja entrada foi fechada",
    callback = function() finish(nil) end,
  })

  -- The cursor at the end of what is there, which is where the reviewer
  -- continues from. Insert mode is not started for them: the two keys that end
  -- the entry are normal mode keys, and a box that opens typing would hide
  -- them behind an Esc.
  vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(bufnr), 0 })
end

---Ask for the text on one line, prefilled with what is already written. The
---editor's own input UI, so it is asked wherever the reviewer already reads
---the editor's questions.
---@param point ReviewPoint
---@param text string
---@param done fun(written: string|nil) nil when the reviewer gave it up
local function one_line_entry(point, text, done) vim.ui.input({ prompt = about(point) .. ": ", default = text }, done) end

---Write the annotation of a point, asking the reviewer for the text and
---editing what is already there.
---
---An annotation that does not fit on one line is edited in the long entry
---whichever key asked for it: prefilling a one-line box with a paragraph would
---show the reviewer a single unreadable run of text and make them lose the
---rest of it by pressing Enter.
---@param point ReviewPoint
---@param opts { long: boolean|nil }|nil `long` opens the entry of several lines
---@param done fun() called after the annotation is written, and not when the
---reviewer gave it up; with a picker in front of `vim.ui.input` it arrives long
---after this function returns
function M.write(point, opts, done)
  local existing = state.annotation_at(point)
  local text = existing and existing.text or ""

  local ask = (opts and opts.long or text:find "\n") and long_entry or one_line_entry
  ask(point, text, function(written)
    if not written then return end
    state.annotate(point, vim.trim(written))
    done()
  end)
end

return M
