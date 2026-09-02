---The review report: what the reviewer wrote, taken out of the editor.
---
---Two halves of one act. A markdown document grouped by file, each remark with
---the path, the line and the line of code quoted, so whoever reads it
---understands without opening the repository — and the quickfix, filled with
---the same points in the same order, so the reviewer walks their own remarks
---with the keys they already have instead of reopening anything.
---
---It holds the annotations of the current mode alone: the document is about
---the review happening now, not about every remark ever written on this
---repository. And it is written outside the repository being reviewed
---(ADR-0004), where the reviewer's own list of untracked files cannot see it.
---
---Where each annotation stands is decided here, and only here. The line
---recorded with it is where it was when it was written, and the file has moved
---on since: the anchor is what finds it again (ADR-0003). An anchor that is
---not in the file anymore leaves the annotation displaced — in a section of its
---own, in the quickfix without a line — rather than discarded or pointed at
---the wrong line.
---
---Against the file on disk, which is what the panel lists and what whoever
---reads the report will find in the repository. A line changed in a buffer
---and not written yet is not in the file, so a remark on it comes out
---displaced — the same answer the reviewer gets from `git status` about that
---edit, and the honest one for a document that leaves the editor.
local annotation = require "review.annotation"
local config = require "review.config"

local M = {}

---@class ReviewPlacement one annotation, in the file as it is now
---@field annotation ReviewAnnotation
---@field line integer|nil where it stands now; absent on a file annotation and
---on a displaced one
---@field snippet string|nil the line of code it is about, as it reads now
---@field displaced boolean whether the anchor was not found (ADR-0003)

---The lines of a file of the repository, read once however many annotations
---are on it. `false` is a file there is nothing to read: deleted since the
---remark was written, or never on disk.
---@param repository string absolute path of the repository root
---@param path string the file, from the repository root
---@param cache table<string, string[]|false>
---@return string[]|nil
local function lines_of(repository, path, cache)
  if cache[path] == nil then
    local absolute = repository .. "/" .. path
    cache[path] = vim.fn.filereadable(absolute) == 1 and vim.fn.readfile(absolute) or false
  end
  return cache[path] or nil
end

---The line the anchor is on now: the one it was written on, when the text is
---still there, and otherwise the nearest line that carries it. Nearest,
---because an edit above the annotation moves every line below it by the same
---amount, and the occurrence closest to where it was is the one it was written
---about.
---
---The text has to match exactly: a line that was re-indented or had a word
---changed is not the line the remark was written about, and answering with it
---would be the wrong line dressed up as the right one.
---@param lines string[]
---@param written ReviewAnnotation
---@return integer|nil line nil when the anchor is not in the file anymore
local function anchored_at(lines, written)
  -- An annotation tied to a line always carries the text of that line. One
  -- that does not is not a document this code wrote, and there is nothing in
  -- it to look for — least of all a line that happens to be missing too.
  if not written.anchor then return nil end
  if lines[written.line] == written.anchor then return written.line end

  local nearest = nil
  for lnum, text in ipairs(lines) do
    if text == written.anchor and (not nearest or math.abs(lnum - written.line) < math.abs(nearest - written.line)) then
      nearest = lnum
    end
  end
  return nearest
end

---Put every annotation where it stands in the file as it is now.
---@param repository string absolute path of the repository root
---@param annotations ReviewAnnotation[]
---@return ReviewPlacement[]
local function place(repository, annotations)
  local read, placements = {}, {}
  for _, written in ipairs(annotations) do
    -- A file annotation is about all of it: there is no line to lose, and
    -- nothing to reanchor.
    if not written.line then
      placements[#placements + 1] = { annotation = written, displaced = false }
    else
      local lines = lines_of(repository, written.path, read)
      local line = lines and anchored_at(lines, written)
      placements[#placements + 1] = line
          and { annotation = written, line = line, snippet = lines[line], displaced = false }
        or { annotation = written, displaced = true }
    end
  end
  return placements
end

---The order the report is read in, which is also the order the quickfix is
---walked in: by file, the remark about the whole file before the ones about
---its lines, and the displaced ones last — where the document puts them, in a
---section of their own.
---@param a ReviewPlacement
---@param b ReviewPlacement
---@return boolean
local function reads_before(a, b)
  if a.displaced ~= b.displaced then return b.displaced end
  if a.annotation.path ~= b.annotation.path then return a.annotation.path < b.annotation.path end
  -- Within a file, the line each one is on — for a displaced annotation, the
  -- line it was written on, which is all that is left of where it was.
  return (a.line or a.annotation.line or 0) < (b.line or b.annotation.line or 0)
end

---A fence long enough to hold `text`: a snippet with backticks in it — a
---markdown file under review, a line of documentation — would close a fence of
---three from the inside.
---@param text string
---@return string
local function fence(text)
  local longest = 0
  for run in text:gmatch "`+" do
    longest = math.max(longest, #run)
  end
  return ("`"):rep(math.max(3, longest + 1))
end

---The quoted line, in the language of the file it came from, so the report
---reads as code wherever it is pasted. The editor's own filetype detection
---answers by name alone, which is all there is to go on for a file that is not
---open.
---
---A remark written on an empty line quotes nothing: a fence with nothing
---inside it is a hole in the document, and the line number above it already
---says where the remark is.
---@param lines string[] the document being built, appended to
---@param path string the file the snippet came from
---@param snippet string|nil
local function quote(lines, path, snippet)
  if not snippet or snippet == "" then return end

  local language = vim.filetype.match { filename = path } or ""
  local edge = fence(snippet)
  lines[#lines + 1] = edge .. language
  lines[#lines + 1] = snippet
  lines[#lines + 1] = edge
  lines[#lines + 1] = ""
end

---The text of the annotation, which is the reviewer's own writing and goes in
---as it was written — several lines included, since the long entry exists
---exactly for the remark that does not fit in one.
---@param lines string[] the document being built, appended to
---@param text string
local function remark(lines, text)
  vim.list_extend(lines, vim.split(text, "\n", { plain = true }))
  lines[#lines + 1] = ""
end

---@param count integer
---@param singular string
---@param plural string
---@return string
local function counted(count, singular, plural) return ("%d %s"):format(count, count == 1 and singular or plural) end

---What the report says it is, before anything else in it: which review it came
---from, and how much of it there is.
---@param repository string absolute path of the repository root
---@param mode ReviewMode the review it came from
---@param placements ReviewPlacement[]
---@return string[]
local function heading(repository, mode, placements)
  local files = {}
  for _, placement in ipairs(placements) do
    files[placement.annotation.path] = true
  end

  return {
    "# Revisão de " .. vim.fs.basename(repository),
    "",
    ("%s · %s em %s · gerado em %s"):format(
      mode.label,
      counted(#placements, "anotação", "anotações"),
      counted(vim.tbl_count(files), "arquivo", "arquivos"),
      os.date "!%Y-%m-%dT%H:%M:%SZ"
    ),
    "",
  }
end

---What the reviewer left on a file, under the file's own heading.
---@param lines string[] the document being built, appended to
---@param path string
---@param placements ReviewPlacement[] of this file, in order, none displaced
local function file_section(lines, path, placements)
  lines[#lines + 1] = "## " .. path
  lines[#lines + 1] = ""
  for _, placement in ipairs(placements) do
    lines[#lines + 1] = placement.line and ("**Linha %d**"):format(placement.line) or "**O arquivo inteiro**"
    lines[#lines + 1] = ""
    quote(lines, path, placement.snippet)
    remark(lines, placement.annotation.text)
  end
end

---The annotations whose anchor is gone, at the end and marked as such: the
---reviewer decides what to do with each one, and deciding needs the remark and
---the line it was written about, which is the anchor itself (ADR-0003).
---@param lines string[] the document being built, appended to
---@param placements ReviewPlacement[] the displaced ones, in order
local function displaced_section(lines, placements)
  if #placements == 0 then return end

  lines[#lines + 1] = "## Anotações deslocadas"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "A âncora destas anotações não está mais no arquivo. O trecho citado é o que"
  lines[#lines + 1] = "havia quando cada uma foi escrita."
  lines[#lines + 1] = ""
  for _, placement in ipairs(placements) do
    local written = placement.annotation
    lines[#lines + 1] = ("**%s · linha %d quando foi escrita**"):format(written.path, written.line)
    lines[#lines + 1] = ""
    quote(lines, written.path, written.anchor)
    remark(lines, written.text)
  end
end

---The whole document.
---@param repository string absolute path of the repository root
---@param mode ReviewMode the review it came from
---@param placements ReviewPlacement[] in the order they are read in
---@return string[] lines
local function document(repository, mode, placements)
  local lines = heading(repository, mode, placements)

  local displaced, path, of_this_file = {}, nil, {}
  for _, placement in ipairs(placements) do
    if placement.displaced then
      displaced[#displaced + 1] = placement
    else
      -- The placements are already grouped by path by the ordering, so a path
      -- that is not the one being written is the start of the next file.
      if placement.annotation.path ~= path then
        if path then file_section(lines, path, of_this_file) end
        path, of_this_file = placement.annotation.path, {}
      end
      of_this_file[#of_this_file + 1] = placement
    end
  end
  if path then file_section(lines, path, of_this_file) end

  displaced_section(lines, displaced)
  -- Every block ends with a blank line so the next one starts apart from it;
  -- the last one has no next one.
  while lines[#lines] == "" do
    table.remove(lines)
  end
  return lines
end

---What the quickfix shows about one point: the remark itself, on one line,
---because the list is one line per point. A remark of several lines is cut to
---its first — the rest of it is in the document, which is where a paragraph is
---read.
---@param placement ReviewPlacement
---@return string
local function summary(placement)
  local lines = vim.split(placement.annotation.text, "\n", { plain = true })
  local text = #lines > 1 and (lines[1] .. " …") or lines[1]
  return placement.displaced and ("deslocada · " .. text) or text
end

---What the list of the review is called, wherever the editor shows its title.
local QUICKFIX_TITLE = "Anotações da revisão"

---Put the same points in the editor's own list, in the order the document
---reads, and show it: walking the list is walking the report.
---
---A displaced annotation goes in without a line — line 0 is the file itself,
---which is where a file annotation lands too. Sending it to the line it used
---to be on is exactly what the anchor exists to prevent, and leaving it out
---would hide it from the reviewer who works from the list.
---
---A list of its own, and not the one that is already there: whatever the
---reviewer was walking before is still a `:colder` away.
---@param repository string absolute path of the repository root
---@param placements ReviewPlacement[]
local function fill_quickfix(repository, placements)
  local items = {}
  for _, placement in ipairs(placements) do
    items[#items + 1] = {
      filename = repository .. "/" .. placement.annotation.path,
      lnum = placement.line or 0,
      col = placement.line and 1 or 0,
      -- Said out loud, because the editor decides it by the line number: a
      -- point without one is filed as invalid, and `:cnext` skips exactly the
      -- entries this list was careful to keep.
      valid = 1,
      text = summary(placement),
    }
  end
  vim.fn.setqflist({}, " ", { title = QUICKFIX_TITLE, items = items })

  -- Opened where the editor opens it, and the cursor stays where it was: the
  -- reviewer pressed a key in the panel, and a key pressed in a list does not
  -- take the cursor out of it.
  local from = vim.api.nvim_get_current_win()
  vim.cmd "copen"
  if vim.api.nvim_win_is_valid(from) then vim.api.nvim_set_current_win(from) end
end

---Where the reports are written: the directory the reviewer configured —
---absolute, which is what the options make sure of — or, by default, beside
---the review state under the editor's data directory (ADR-0004).
---@return string
local function directory() return config.options.report_directory or (vim.fn.stdpath "data" .. "/review/reports") end

---One document per repository and mode, rewritten by the next generation: the
---report is about the review happening now, and a directory filling up with
---dated copies of it is a history nobody asked for — the reviewer who wants to
---keep one has it in a file they can move.
---
---The root goes into the name percent-encoded, the way the state document's
---does: it keeps the name readable and unambiguous, and a file name cannot
---hold the "/" the root is full of.
---@param repository string absolute path of the repository root
---@param mode string the mode the report is of
---@return string path
local function report_path(repository, mode)
  local name = (repository:gsub("%%", "%%25"):gsub("/", "%%2F"))
  return ("%s/%s-%s.md"):format(directory(), name, mode)
end

---Generate the report of the review under way: write the document, and fill
---the quickfix with the same points.
---
---Nothing is written when there is no annotation in this mode: a report of an
---empty review says nothing. What an earlier generation left goes with it —
---the document and the list are this review as it stands, and one still
---holding a remark the reviewer took back would be saying what the review no
---longer says, in the file they hand to someone else.
---@param repository string absolute path of the repository root
---@param mode ReviewMode the review to report
---@return string|nil path where it was written; nil when there was nothing to
---write, or writing failed
---@return integer count of annotations in it
function M.generate(repository, mode)
  local path = report_path(repository, mode.key)
  local placements = place(repository, annotation.of_mode(repository, mode))
  if #placements == 0 then
    vim.fn.delete(path)
    vim.fn.setqflist({}, " ", { title = QUICKFIX_TITLE, items = {} })
    return nil, 0
  end
  table.sort(placements, reads_before)

  vim.fn.mkdir(vim.fs.dirname(path), "p")
  if vim.fn.writefile(document(repository, mode, placements), path) ~= 0 then
    vim.notify("review: não foi possível gravar o relatório em " .. path, vim.log.levels.WARN)
    return nil, #placements
  end

  fill_quickfix(repository, placements)
  return path, #placements
end

return M
