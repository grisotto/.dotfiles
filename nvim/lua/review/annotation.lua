---What the reviewer writes about a point of the code.
---
---An annotation is tied to a file and, when it was written from the code
---itself, to a line of it — or to a run of lines, when the key was pressed on a
---selection. Along with the text it records the anchor — the text of those
---lines at the moment it was written (ADR-0003). The anchor is only recorded
---here; whoever uses it to find the lines again after the file changed is the
---review report.
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
---
---Before either of them comes the type of the annotation — what the reviewer
---asks the agent for with it —, in the editor's own selection UI: deciding
---whether a remark is a fix, a question or a "leave this as it is" is part of
---writing it, and the report tells the agent what each type asks for.
---
---Or, by option (`annotation_type_entry = "prefix"`), in the text itself: no
---selector comes before the entry, the reviewer writes `question: …`, and the
---name of a type in front of the text is the type. Editing brings the prefix
---back in front of the text, so changing the type is editing it too.
local config = require "review.config"
local diff = require "review.diff"
local git = require "review.git"
local root = require "review.root"
local state = require "review.state"
local WORKTREE = require("review.mode").WORKTREE

local M = {}

---@alias ReviewAnnotationVersion "disk"|"index"|string the version of the file a
---line was read in: the file on disk, the index, or the whole sha of the commit
---— the newest one, in a range

---@class ReviewPoint what an annotation is attached to
---@field root string absolute path of the repository root
---@field path string the file, from the repository root
---@field mode string the mode of the review it is being written in
---@field version ReviewAnnotationVersion|nil the version the line was read in; absent on
---a file annotation
---@field line integer|nil the line, the first of a run of them; absent on a file annotation
---@field end_line integer|nil the last line of a run; absent on a point of one line
---@field anchor string|nil the text of those lines, one per line; absent on a file annotation

---The whole file, without a line: what a line of the panel points at is a
---file, and the remark written from there is about all of it.
---@param repository string absolute path of the repository root
---@param path string the file, from the repository root
---@param mode ReviewMode the review it is being written in
---@return ReviewPoint
function M.point_of_file(repository, path, mode) return { root = repository, path = path, mode = mode.key } end

---The `end_line` a point from `first` to `last` is written with: none on a point
---of one line, which is that line alone and not a run of one.
---@param first integer
---@param last integer
---@return integer|nil
function M.end_line(first, last) return last > first and last or nil end

---The lines the key was pressed on: the ones a visual selection holds, when it
---was pressed on one, and the line of the cursor otherwise.
---
---Out of the selection before anything is asked: what comes next is an entry
---in a prompt or a window of its own, and a visual mode left running under it
---is not something to hand the reviewer back. The "x" is what makes the editor
---leave it now instead of after this returns.
---@return integer first
---@return integer last
local function pointed_lines()
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  if not vim.fn.mode():find "^[vV\22]" then return cursor, cursor end

  local other = vim.fn.line "v"
  vim.api.nvim_feedkeys(vim.keycode "<Esc>", "nx", false)
  return math.min(other, cursor), math.max(other, cursor)
end

---What the key says on the side before the change of a diff.
local ON_THE_SIDE_BEFORE =
  "review: o lado de antes do diff não se anota: o que se anota é o que a mudança passou a ter."

---What the key says anywhere else there is no line of the repository to write
---on.
local NOT_A_LINE_OF_THE_FILE = "review: só dá para anotar uma linha do arquivo em si; abra-o pelo painel."

---What the key says on today's file when the review is of a commit or a range:
---where the line of the commit is, which is the diff one jump back. Asked for
---when the key is pressed, because the key back is the reviewer's to configure.
---@return string
local function on_today_s_file()
  return ("review: no modo commit ou intervalo o arquivo de hoje não se anota; volte ao diff com %s e anote o lado de depois."):format(
    config.options.mappings.back_to_diff
  )
end

---The point of lines `first` to `last` of a buffer, read in `version`.
---@param repository string absolute path of the repository root
---@param path string the file, from the repository root
---@param mode ReviewMode
---@param version ReviewAnnotationVersion|nil
---@param bufnr integer the buffer the lines are read from
---@param first integer
---@param last integer
---@return ReviewPoint
local function point_on_lines(repository, path, mode, version, bufnr, first, last)
  return {
    root = repository,
    path = path,
    mode = mode.key,
    version = version,
    line = first,
    -- A selection of one line is that line: the same point the key pressed
    -- without a selection writes, and so the same remark.
    end_line = M.end_line(first, last),
    -- The anchor is the lines as they stand right now, in the buffer the
    -- reviewer is reading them in, which is what the remark being written is
    -- about (ADR-0003).
    anchor = table.concat(vim.api.nvim_buf_get_lines(bufnr, first - 1, last, false), "\n"),
  }
end

---The point the reviewer is on in what they are reading: the line the cursor is
---on, or the lines selected, of the file on disk or of the side of a diff that
---takes an annotation.
---@param mode ReviewMode the review it is being written in
---@return ReviewPoint|nil nil when there is no line here to annotate
---@return string|nil refusal what to tell the reviewer, when there is none
function M.point_under_cursor(mode)
  local first, last = pointed_lines()
  local bufnr = vim.api.nvim_get_current_buf()

  -- A side of a diff says what it is: the side before the change is refused,
  -- and the side after it is written in the version it shows.
  local side = diff.side_in(vim.api.nvim_get_current_win())
  if side then
    if side.before then return nil, ON_THE_SIDE_BEFORE end
    if not side.version then return nil, NOT_A_LINE_OF_THE_FILE end
    return point_on_lines(side.root, side.path, mode, side.version, bufnr, first, last)
  end

  -- Everything else the panel puts on screen that is not the file itself — the
  -- panel, the long entry — is a buffer with nothing on disk behind it, and
  -- there is no line of the repository to tie a remark to in one of those.
  if vim.bo[bufnr].buftype ~= "" then return nil, NOT_A_LINE_OF_THE_FILE end

  local file = vim.api.nvim_buf_get_name(bufnr)
  local directory = file ~= "" and vim.fs.dirname(file) or ""
  if vim.fn.isdirectory(directory) == 0 then return nil, NOT_A_LINE_OF_THE_FILE end

  local repository = git.root(directory)
  local path = repository and root.relative_to(repository, file)
  if not repository or not path then return nil, NOT_A_LINE_OF_THE_FILE end

  -- The file on disk is the disk version of the working tree. In a commit or a
  -- range it is no version of the review at all: the report of a commit has
  -- one reference, the commit, and a line of today's file in it would be a line
  -- of another version under the same sha (ADR-0011). The way back to the diff
  -- is the key the reviewer came from it with.
  if mode.key ~= WORKTREE.key then return nil, on_today_s_file() end
  return point_on_lines(repository, path, mode, "disk", bufnr, first, last)
end

---How many open annotations each file of the repository has in this mode, by
---path, so the panel can put the count on the file's line. Only the open ones:
---the count is what is still to be handed to the agent (ADR-0012).
---@param repository string absolute path of the repository root
---@param mode ReviewMode
---@return table<string, integer>
function M.counts(repository, mode)
  local counts = {}
  for _, written in ipairs(state.open_annotations(repository, mode.key)) do
    counts[written.path] = (counts[written.path] or 0) + 1
  end
  return counts
end

---@class ReviewAnnotationType what the reviewer can ask the agent for with an annotation
---@field name string how the report writes it, in the words of the Conventional Comments
---@field instruction string what it asks the agent for, as the preamble says it

---The type of an annotation the reviewer did not choose one for: nearly every
---remark on an agent's change is "this is wrong".
local DEFAULT_TYPE = "issue"

---The types of the Conventional Comments, in the order the selector offers them
---and the preamble lists them.
---@type ReviewAnnotationType[]
local TYPES = {
  { name = "issue", instruction = "corrija o problema apontado." },
  { name = "refactor", instruction = "refatore o trecho sem mudar o comportamento." },
  { name = "test", instruction = "crie ou ajuste o teste pedido." },
  { name = "revert", instruction = "desfaça a sua mudança neste trecho." },
  { name = "question", instruction = "responda à pergunta sem alterar o código." },
  { name = "suggestion", instruction = "avalie a sugestão e aplique-a, ou recuse-a dizendo o motivo." },
  { name = "nitpick", instruction = "faça o ajuste trivial pedido." },
  { name = "praise", instruction = "mantenha o trecho como está, também ao refazer o resto." },
}

---The types an annotation can have, in order: the built-in ones with the
---instruction the reviewer gave to any of them, and after them the ones the
---reviewer added (`annotation_types`).
---@return ReviewAnnotationType[]
function M.types()
  local types = vim.deepcopy(TYPES)
  for _, configured in ipairs(config.options.annotation_types) do
    local known = vim.iter(types):find(function(kind) return kind.name == configured.name end)
    if known then
      known.instruction = configured.instruction
    else
      types[#types + 1] = { name = configured.name, instruction = configured.instruction }
    end
  end
  return types
end

---The type of an annotation, or of the one about to be written where there is
---none yet. One written before annotations had a type has none either, and it
---is what every annotation was then.
---@param written ReviewAnnotation|nil
---@return string
function M.type_of(written) return written and written.type or DEFAULT_TYPE end

---Where a point is, as the entries say it: a reviewer who pressed the key on
---the wrong line sees it before writing.
---@param point ReviewPoint
---@return string e.g. "a.clj", "a.clj:42", "a.clj:42-44"
local function where(point)
  if point.end_line then return ("%s:%d-%d"):format(point.path, point.line, point.end_line) end
  if point.line then return ("%s:%d"):format(point.path, point.line) end
  return point.path
end

---Ask for the type of the annotation of a point, in the editor's own selection
---UI. Each type is offered with what it asks the agent for, so the reviewer
---decides what they are asking before writing it; `current` comes first, so
---that the key that picks the first one keeps what is there.
---@param point ReviewPoint
---@param current string
---@param done fun(kind: string|nil) nil when the reviewer gave it up
local function choose_type(point, current, done)
  local offered = {}
  for _, kind in ipairs(M.types()) do
    if kind.name == current then
      table.insert(offered, 1, kind)
    else
      offered[#offered + 1] = kind
    end
  end
  local items = vim.tbl_map(function(kind) return ("%s — %s"):format(kind.name, kind.instruction) end, offered)
  vim.ui.select(
    items,
    { prompt = ("Tipo da anotação em %s"):format(where(point)) },
    function(_, index) done(index and offered[index].name) end
  )
end

---The type written in front of a text and the text without it, when the
---reviewer gives the type by prefix (`question: por que isto?`). Only the exact
---name of a type is one: a prefix that is not — `nota: …`, or an abbreviation —
---is part of a sentence of the reviewer's, and the text stays as it was. The
---characters of a name are the ones `annotation_types` accepts in the config.
---@param text string
---@return string|nil kind nil when the text does not start with a type
---@return string text
local function split_prefix(text)
  local name, rest = text:match "^([%w_-]+):%s*(.*)$"
  if name and vim.iter(M.types()):any(function(kind) return kind.name == name end) then return name, rest end
  return nil, text
end

---What the entry comes prefilled with when the type is given by prefix: the
---text with the type written in front, so that changing the type is editing the
---text. The default type goes without one — it is what a text without a prefix
---already is —, unless the text itself starts with the name of a type, its own
---included: written back untouched, that name would be read as the prefix and
---leave the text.
---@param kind string
---@param text string
---@return string
local function with_prefix(kind, text)
  if kind == DEFAULT_TYPE and not split_prefix(text) then return text end
  return ("%s: %s"):format(kind, text)
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
---@param about string what is being written, e.g. "issue em a.clj:42-44", or only the point when the type is given by prefix
---@param text string what is already written, empty for a new annotation
---@param done fun(written: string|nil) nil when the reviewer gave it up
local function long_entry(about, text, done)
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
    title = " " .. about .. " ",
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
---@param about string what is being written, e.g. "issue em a.clj:42-44", or only the point when the type is given by prefix
---@param text string
---@param done fun(written: string|nil) nil when the reviewer gave it up
local function one_line_entry(about, text, done) vim.ui.input({ prompt = about .. ": ", default = text }, done) end

---Write the annotation of a point, asking the reviewer for the type and then
---the text, and editing what is already there. With the type given by prefix
---there is only the text to ask for, and the type is read from it.
---
---Giving up any question gives the annotation up: what is already written
---stays as it was.
---
---An annotation that does not fit on one line is edited in the long entry
---whichever key asked for it: prefilling a one-line box with a paragraph would
---show the reviewer a single unreadable run of text and make them lose the
---rest of it by pressing Enter.
---@param point ReviewPoint
---@param opts { long: boolean|nil }|nil `long` opens the entry of several lines
---@param done fun() called after the annotation is written, and not when the
---reviewer gave it up; with a picker in front of `vim.ui.select` or
---`vim.ui.input` it arrives long after this function returns
function M.write(point, opts, done)
  local existing = state.annotation_at(point)
  local text = existing and existing.text or ""
  local ask = (opts and opts.long or text:find "\n") and long_entry or one_line_entry

  if config.options.annotation_type_entry == "prefix" then
    ask(where(point), with_prefix(M.type_of(existing), text), function(written)
      if not written then return end
      local kind, rest = split_prefix(vim.trim(written))
      state.annotate(point, rest, kind or DEFAULT_TYPE)
      done()
    end)
    return
  end

  choose_type(point, M.type_of(existing), function(kind)
    if not kind then return end
    ask(("%s em %s"):format(kind, where(point)), text, function(written)
      if not written then return end
      state.annotate(point, vim.trim(written), kind)
      done()
    end)
  end)
end

return M
