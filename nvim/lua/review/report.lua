---The review report: what the reviewer wrote, handed to the AI agent that made
---the change under review.
---
---Two halves of one act. A document the reviewer pastes into the conversation
---with the agent — a header saying where and about what, a preamble saying
---what to do with each item and how to answer, and the items themselves, one
---per annotation, each with an id, a type, the file, the lines and the code
---quoted — and the quickfix, filled with the same points in the same order, so
---the reviewer walks their own remarks with the keys they already have.
---
---In two formats, on two keys (ADR-0006): tags XML and markdown, with exactly
---the same content, so that comparing them measures the format and nothing
---else. Which is why this module is three parts that do not reach into each
---other: building the items reads the repository and the state, rendering
---them in a format reads neither, and generating writes what was rendered.
---
---It is about the current mode alone: the document is about the review
---happening now, not about every remark ever written on this repository. And it is written outside the repository being reviewed
---(ADR-0004), where the reviewer's own list of untracked files cannot see it.
---
---Generating it is delivering them (ADR-0012): the report is frozen in the
---state document as a delivery, and the annotations in it stop being open, so
---the next report takes only what was written after. With nothing open, the
---last delivery of the mode is rendered again — from what was frozen, which is
---what the agent got, and not from the file as it is now.
---
---Where each annotation stands is decided here, and only here. The line
---recorded with it is where it was when it was written, and the file has moved
---on since: the anchor is what finds it again (ADR-0003). An anchor that is
---not in the file anymore goes in all the same, marked as not found and with
---the code it was written about, rather than discarded or pointed at the wrong
---line.
---
---Against the file on disk, which is what the panel lists and what the agent
---edits. A line changed in a buffer and not written yet is not in the file, so
---a remark on it comes out not found — the same answer the reviewer gets from
---`git status` about that edit, and the honest one for a document that leaves
---the editor.
---
---Only what still changes after the remark was written is looked for again —
---the file on disk and the index. A remark on a line of a commit stays on the
---line of the commit, quoting the commit's code: the commit does not change,
---and the agent finds the line by its sha (ADR-0011). The quickfix is the
---exception, because it is the reviewer's way through today's file: its points
---are looked for on disk, whatever the report says.
local annotation = require "review.annotation"
local config = require "review.config"
local git = require "review.git"
local state = require "review.state"

local M = {}

---@alias ReviewReportFormat "xml"|"markdown"

---@class ReviewReportItem one annotation, as the agent gets it
---@field id integer from 1, in the order the report is read in
---@field type string what the reviewer asks for with it
---@field file string from the repository root
---@field first integer|nil the first line it is about; absent on a file
---annotation and on one not found
---@field last integer|nil the last of them, the same as `first` on a line alone
---@field code string[]|nil the lines quoted; on one not found, the lines it was
---written about; absent on a file annotation
---@field text string what the reviewer wrote
---@field found boolean false when its anchor is not in the file anymore

---@class ReviewReportHeader what the report is about
---@field root string absolute path of the repository root
---@field branch string the branch checked out, `(detached)` when none is
---@field reference string what was reviewed: HEAD in the working tree, the
---whole sha and the subject of a commit, `oldest^..newest` of a range
---@field commit string|nil the whole sha of the commit the lines quoted are
---from — the newest of a range; absent in the working tree, where they are the
---file on disk

---@class ReviewReport everything a format renders, and nothing it has to look up
---@field header ReviewReportHeader
---@field items ReviewReportItem[]
---@field types ReviewAnnotationType[] the types the items use, with the
---instruction each had, in the order of the types
---@field template string the template of its preamble, with the markers still in it

---@class ReviewPlacement one annotation, where it stands: in the file as it is
---now, or on the line of the commit it was written on
---@field annotation ReviewAnnotation
---@field line integer|nil where it stands, the first line of a run; absent on a
---file annotation and on a displaced one
---@field end_line integer|nil where a run of lines ends; absent on a line alone
---@field snippet string[]|nil the lines of code it is about, as they read where
---it stands
---@field displaced boolean whether the anchor was not found (ADR-0003)

---The lines of a file of the repository — on disk, or in a commit —, read once
---however many annotations are on it. `false` is a file there is nothing to
---read: deleted since the remark was written, never on disk, or not in that
---commit.
---@param repository string absolute path of the repository root
---@param rev string|nil the commit to read it in; nil is the file on disk
---@param path string the file, from the repository root
---@param cache table<string, string[]|false>
---@return string[]|nil
local function lines_of(repository, rev, path, cache)
  -- `<sha>:<path>` for a commit and `:<path>` for the disk: a sha is never
  -- empty, so a path read in two versions is read twice.
  local key = ("%s:%s"):format(rev or "", path)
  if cache[key] == nil then
    local absolute = repository .. "/" .. path
    if rev then
      cache[key] = git.show(repository, rev, path) or false
    else
      cache[key] = vim.fn.filereadable(absolute) == 1 and vim.fn.readfile(absolute) or false
    end
  end
  return cache[key] or nil
end

---Whether a version is a commit: the one version a line does not move in after
---it was annotated.
---@param version ReviewAnnotationVersion|nil
---@return boolean
local function is_commit(version) return version ~= nil and version ~= "disk" and version ~= "index" end

---The lines of an anchor, one per line of the file it was written about: a
---remark on a run of lines carries all of them.
---@param written ReviewAnnotation with an anchor
---@return string[]
local function anchor_lines(written) return vim.split(written.anchor, "\n", { plain = true }) end

---The line the anchor starts on now: the one it was written on, when the text
---is still there, and otherwise the nearest line from which the file carries it
---again. Nearest, because an edit above the annotation moves every line below
---it by the same amount, and the occurrence closest to where it was is the one
---it was written about.
---
---The text has to match exactly: a line that was re-indented or had a word
---changed is not the line the remark was written about, and answering with it
---would be the wrong line dressed up as the right one. A run of lines matches
---whole, in order and together: its lines scattered around the file are not the
---passage the remark was written about.
---@param lines string[]
---@param anchor string[] the lines of the anchor
---@param written_at integer the line the annotation was written on
---@return integer|nil line nil when the anchor is not in the file anymore
local function anchored_at(lines, anchor, written_at)
  ---@param start integer
  ---@return boolean
  local function holds_at(start)
    for offset, text in ipairs(anchor) do
      if lines[start + offset - 1] ~= text then return false end
    end
    return true
  end

  if holds_at(written_at) then return written_at end

  local nearest = nil
  for start = 1, #lines - #anchor + 1 do
    if holds_at(start) and (not nearest or math.abs(start - written_at) < math.abs(nearest - written_at)) then
      nearest = start
    end
  end
  return nearest
end

---Put every annotation where it stands: on the line of the commit it was
---written on, or in the file as it is now.
---@param repository string absolute path of the repository root
---@param mode ReviewMode the review the annotations are of
---@param annotations ReviewAnnotation[]
---@return ReviewPlacement[]
local function place(repository, mode, annotations)
  local read, placements = {}, {}
  for _, written in ipairs(annotations) do
    -- A file annotation is about all of it: there is no line to lose, and
    -- nothing to reanchor.
    if not written.line then
      placements[#placements + 1] = { annotation = written, displaced = false }
    elseif is_commit(written.version) then
      -- Where it was written, quoting what it was written about: the anchor was
      -- read from the commit, which still reads the same (ADR-0011). Never
      -- displaced, because there is nothing it could have moved away from.
      placements[#placements + 1] = {
        annotation = written,
        line = written.line,
        end_line = written.end_line,
        snippet = written.anchor and anchor_lines(written),
        displaced = false,
      }
    else
      -- Looked for on disk, which is where what still changes after the remark
      -- ends up. Except the line of a commit or a range written without a
      -- version: before a commit had lines of its own it was written on today's
      -- file, and it is looked for in the commit of the mode instead — found
      -- there, it is a remark about the commit like any other.
      local rev = not written.version and mode.rev or nil
      local lines = lines_of(repository, rev, written.path, read)
      -- An annotation tied to a line always carries the text of that line. One
      -- that does not is not a document this code wrote, and there is nothing in
      -- it to look for — least of all a line that happens to be missing too.
      local anchor = written.anchor and anchor_lines(written)
      local line = lines and anchor and anchored_at(lines, anchor, written.line)
      if line then
        local last = line + #anchor - 1
        placements[#placements + 1] = {
          annotation = written,
          line = line,
          end_line = annotation.end_line(line, last),
          snippet = vim.list_slice(lines, line, last),
          displaced = false,
        }
      else
        placements[#placements + 1] = { annotation = written, displaced = true }
      end
    end
  end
  return placements
end

---Where a placement is read, as the pair it is sorted by: the line it stands on
---now, or — for a displaced one — the one it was written on, which is all that
---is left of where it was. No line at all is the file annotation, read before
---every line of its file.
---@param placement ReviewPlacement
---@return integer first
---@return integer last
local function position(placement)
  local first = placement.line or placement.annotation.line or 0
  local last = placement.line and placement.end_line or placement.annotation.end_line
  return first, last or first
end

---The order the report is read in, which is also the order of the ids and of
---the quickfix: by file, and within a file by line, the remark about the whole
---file first. One list, the annotations not found included — the agent goes
---through the code once, in the order it is written.
---@param a ReviewPlacement
---@param b ReviewPlacement
---@return boolean
local function reads_before(a, b)
  if a.annotation.path ~= b.annotation.path then return a.annotation.path < b.annotation.path end
  local a_first, a_last = position(a)
  local b_first, b_last = position(b)
  if a_first ~= b_first then return a_first < b_first end
  -- A line before the run that starts on it, and the rest by what was written:
  -- the order has to be the same every time, and the sort is not stable.
  if a_last ~= b_last then return a_last < b_last end
  return a.annotation.text < b.annotation.text
end

---The items of a report, in the order it is read in.
---@param placements ReviewPlacement[] already sorted
---@return ReviewReportItem[]
local function items_of(placements)
  local items = {}
  for id, placement in ipairs(placements) do
    local written = placement.annotation
    local item = {
      id = id,
      type = annotation.type_of(written),
      file = written.path,
      text = written.text,
      found = true,
    }
    if placement.displaced then
      item.found = false
      item.code = written.anchor and anchor_lines(written)
    elseif placement.line then
      item.first, item.last = placement.line, placement.end_line or placement.line
      item.code = placement.snippet
    end
    items[#items + 1] = item
  end
  return items
end

---What the header says was reviewed, as git names it: the agent reads git, and
---a name it can hand straight back to git is one it cannot misread.
---@param repository string absolute path of the repository root
---@param mode ReviewMode
---@return string
local function reference_of(repository, mode)
  -- The oldest commit is part of the range, and `^` is what says so to anyone
  -- who reads git: `a..b` leaves `a` out.
  if mode.oldest then return ("%s^..%s"):format(mode.oldest, mode.rev) end
  local commit = git.commit(repository, mode.rev or "HEAD")
  if mode.rev then return commit and ("%s %s"):format(commit.sha, commit.subject) or mode.rev end
  -- The working tree is the changes on top of HEAD, which is the base the agent
  -- has to be on for the lines to be the ones quoted.
  return commit and ("HEAD %s"):format(commit.sha) or "HEAD (no commits yet)"
end

---The preamble the agent reads before the items, with its markers — `{types}`,
---`{reference}` and `{not_found}` — filled in from the report. Built in, for
---the reviewer who keeps no template of their own.
local PREAMBLE = [[
Esta é a revisão humana de uma mudança que você fez neste repositório. Cada
anotação abaixo é um pedido sobre um ponto do código, identificado por um id.

O que cada tipo pede:
{types}

{reference}

{not_found}

- Não altere nada além do que as anotações pedem.
- Localize cada trecho pelo código citado, e não só pelo número da linha.
- Não faça commit: a mudança vai ser validada antes.
- Ao terminar, responda com uma linha por id: `feito`, `respondido` ou
  `recusado: motivo`.]]

---Read the template the preamble is written from: the file the reviewer keeps
---it in — the one the options name, or `review/preamble.md` under the editor's
---configuration directory — and the one built in when there is no such file.
---Read at every generation, so an edit to it is in the next report without the
---editor being restarted.
---@return string
local function read_preamble_template()
  local path = config.options.preamble_template or (vim.fn.stdpath "config" .. "/review/preamble.md")
  if vim.fn.filereadable(path) == 1 then return table.concat(vim.fn.readfile(path), "\n") end
  return PREAMBLE
end

---The types the items use, with the instruction each has in the configuration
---now, in the order of the types: what the preamble explains.
---@param items ReviewReportItem[]
---@return ReviewAnnotationType[]
local function types_used(items)
  local used = {}
  for _, item in ipairs(items) do
    used[item.type] = true
  end
  return vim.tbl_filter(function(kind) return used[kind.name] end, annotation.types())
end

---Build the report of the open annotations of a review: the items, placed in
---the file as it is now, the header, the types the items use and the template
---of the preamble — read here, with everything else a format renders, so
---rendering reads nothing but the report. Which is also what makes a delivery
---redone the report the agent got: the configuration and the template read
---then are frozen with it.
---@param repository string absolute path of the repository root
---@param mode ReviewMode
---@param open ReviewAnnotation[] the annotations to deliver
---@return ReviewReport
local function build(repository, mode, open)
  local placements = place(repository, mode, open)
  table.sort(placements, reads_before)
  local items = items_of(placements)

  return {
    header = {
      root = repository,
      branch = git.branch(repository) or "(detached)",
      reference = reference_of(repository, mode),
      commit = mode.rev,
    },
    items = items,
    types = types_used(items),
    template = read_preamble_template(),
  }
end

---The rule of the items not found, said only when there is one: a rule that
---does not apply is one more thing for the agent to read and weigh.
---@param items ReviewReportItem[]
---@return string empty when every item was found
local function not_found_rule(items)
  for _, item in ipairs(items) do
    if not item.found then
      return "Uma anotação marcada como trecho não encontrado traz o código de quando foi escrita, que não "
        .. "está mais no arquivo: procure o trecho você mesmo e, se não o achar, responda "
        .. "`recusado: trecho não encontrado`."
    end
  end
  return ""
end

---Which version the lines quoted are of: a line of a commit and the same
---number on disk are different lines, and an agent that looks in the wrong
---place finds the wrong one. In a commit, also how to read the exact content,
---which is what the agent compares the quote with.
---@param header ReviewReportHeader
---@return string
local function reference_rule(header)
  if not header.commit then return "As linhas citadas são do arquivo como está no disco agora." end
  return ("As linhas citadas são do commit %s, e não do disco: o conteúdo exato de um arquivo nele sai de `git show %s:<arquivo>`."):format(
    header.commit,
    header.commit
  )
end

---The preamble of a report, in lines. A marker that is filled with nothing
---leaves no blank line behind, one the template leaves out is simply not
---there, and one that is not a marker stays as it is: a template of the
---reviewer's never breaks the generation.
---@param report ReviewReport
---@return string[]
local function preamble(report)
  local values = {
    types = table.concat(
      vim.tbl_map(function(kind) return ("- `%s`: %s"):format(kind.name, kind.instruction) end, report.types),
      "\n"
    ),
    reference = reference_rule(report.header),
    not_found = not_found_rule(report.items),
  }
  local text = report.template:gsub("{([%w_]+)}", values)

  local lines = {}
  for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
    if line ~= "" or (lines[#lines] and lines[#lines] ~= "") then lines[#lines + 1] = line end
  end
  while lines[#lines] == "" do
    table.remove(lines)
  end
  return lines
end

---@param item ReviewReportItem
---@return string|nil e.g. "2", "2-4"; nil when the item has no lines
local function span(item)
  if not item.first then return nil end
  if item.last > item.first then return ("%d-%d"):format(item.first, item.last) end
  return tostring(item.first)
end

---An attribute value, between its quotes and as it is. Nothing in the XML is
---escaped — not the text, not the code, not the attributes: the reader is a
---language model, not a parser, and `&amp;` in a commit subject or `&lt;` in a
---line of code is something it has to translate back before looking for it —
---in one of the two formats and not in the other, which would make them carry
---different values.
---@param value string
---@return string
local function attribute(value) return ('"%s"'):format(value) end

---The report in tags XML, the format the Anthropic documentation recommends for
---mixing instructions and data.
---@param report ReviewReport
---@return string[]
local function xml(report)
  local header = report.header
  local lines = {
    ("<code_review root=%s branch=%s reference=%s>"):format(
      attribute(header.root),
      attribute(header.branch),
      attribute(header.reference)
    ),
    "<instructions>",
  }
  vim.list_extend(lines, preamble(report))
  lines[#lines + 1] = "</instructions>"

  for _, item in ipairs(report.items) do
    local tag = ("<comment id=%s type=%s file=%s"):format(
      attribute(tostring(item.id)),
      attribute(item.type),
      attribute(item.file)
    )
    local where = span(item)
    if where then tag = ("%s lines=%s"):format(tag, attribute(where)) end
    if not item.found then tag = tag .. ' status="not-found"' end
    lines[#lines + 1] = tag .. ">"
    if item.code then
      lines[#lines + 1] = "<code>"
      vim.list_extend(lines, item.code)
      lines[#lines + 1] = "</code>"
    end
    vim.list_extend(lines, vim.split(item.text, "\n", { plain = true }))
    lines[#lines + 1] = "</comment>"
  end

  lines[#lines + 1] = "</code_review>"
  return lines
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

---The report in markdown.
---@param report ReviewReport
---@return string[]
local function markdown(report)
  local header = report.header
  local lines = {
    ("# Code review · %s · branch %s · %s"):format(header.root, header.branch, header.reference),
    "",
  }
  vim.list_extend(lines, preamble(report))

  for _, item in ipairs(report.items) do
    local where = span(item)
    local about = where and ("%s:%s"):format(item.file, where) or item.file
    if not item.found then about = about .. " · trecho não encontrado" end
    vim.list_extend(lines, { "", ("## %d. %s · %s"):format(item.id, item.type, about), "" })

    if item.code then
      -- In the language of the file it came from, so it reads as code. The
      -- editor's own detection answers by name alone, which is all there is to
      -- go on for a file that is not open — and all a renderer may look at.
      local edge = fence(table.concat(item.code, "\n"))
      lines[#lines + 1] = edge .. (vim.filetype.match { filename = item.file } or "")
      vim.list_extend(lines, item.code)
      vim.list_extend(lines, { edge, "" })
    end
    vim.list_extend(lines, vim.split(item.text, "\n", { plain = true }))
  end
  return lines
end

---Render a report in a format. Reads nothing but the report: the two formats
---come out of the same source, which is what makes them comparable.
---@param report ReviewReport
---@param format ReviewReportFormat
---@return string[] lines
local function render(report, format)
  if format == "markdown" then return markdown(report) end
  return xml(report)
end

---What the quickfix shows about one point: the id and the type, which are what
---tie it to the agent's line of answer, and the remark on one line, because the
---list is one line per point. A remark of several lines is cut to its first —
---the rest of it is in the document, which is where a paragraph is read.
---@param item ReviewReportItem
---@param on_disk boolean whether the code it quotes is in the file on disk now —
---which is not whether the report found it: a line of a commit is always found
---in the report, and can be gone from disk (ADR-0011)
---@return string
local function summary(item, on_disk)
  local lines = vim.split(item.text, "\n", { plain = true })
  local text = #lines > 1 and (lines[1] .. " …") or lines[1]
  if not on_disk then text = "não está no disco · " .. text end
  return ("#%d %s · %s"):format(item.id, item.type, text)
end

---What the list of the review is called, wherever the editor shows its title.
local QUICKFIX_TITLE = "Anotações da revisão"

---Put the same points in the editor's own list, in the order of the ids, and
---show it: walking the list is walking the report.
---
---Each point is where the code it quotes is on disk right now, looked for from
---the line the report gives it — the report of a commit quotes lines of the
---commit, and the reviewer walks today's file (ADR-0011). The two can give one
---id different lines, and each is right about what it is for.
---
---An item whose code is not on disk goes in without a line — line 0 is the
---file itself, which is where a file annotation lands too. Sending it to the
---line it used to be on is exactly what the anchor exists to prevent, and
---leaving it out would hide it from the reviewer who works from the list.
---
---A list of its own, and not the one that is already there: whatever the
---reviewer was walking before is still a `:colder` away.
---@param repository string absolute path of the repository root
---@param items ReviewReportItem[]
local function fill_quickfix(repository, items)
  local read, entries = {}, {}
  for _, item in ipairs(items) do
    local first, last = nil, nil
    if item.code then
      local lines = lines_of(repository, nil, item.file, read)
      first = lines and anchored_at(lines, item.code, item.first or 1)
      last = first and first + #item.code - 1
    end
    entries[#entries + 1] = {
      filename = repository .. "/" .. item.file,
      lnum = first or 0,
      end_lnum = first and last > first and last or nil,
      col = first and 1 or 0,
      -- Said out loud, because the editor decides it by the line number: a
      -- point without one is filed as invalid, and `:cnext` skips exactly the
      -- entries this list was careful to keep.
      valid = 1,
      text = summary(item, not item.code or first ~= nil),
    }
  end
  vim.fn.setqflist({}, " ", { title = QUICKFIX_TITLE, items = entries })

  -- Opened where the editor opens it, and the cursor stays where it was: the
  -- reviewer pressed a key in the panel, and a key pressed in a list does not
  -- take the cursor out of it.
  local from = vim.api.nvim_get_current_win()
  vim.cmd "copen"
  if vim.api.nvim_win_is_valid(from) then vim.api.nvim_set_current_win(from) end
end

---The extension each format is written with.
---@type table<ReviewReportFormat, string>
local EXTENSIONS = { xml = "xml", markdown = "md" }

---Where the reports are written: the directory the reviewer configured —
---absolute, which is what the options make sure of — or, by default, beside
---the review state under the editor's data directory (ADR-0004).
---@return string
local function directory() return config.options.report_directory or (vim.fn.stdpath "data" .. "/review/reports") end

---One document per repository, mode and format, rewritten by the next
---generation in that format: the report is about the review happening now,
---and a directory filling up with dated copies of it is a history nobody asked
---for — the reviewer who wants to keep one has it in a file they can move.
---
---The root goes into the name percent-encoded, the way the state document's
---does: it keeps the name readable and unambiguous, and a file name cannot
---hold the "/" the root is full of.
---@param repository string absolute path of the repository root
---@param mode string the mode the report is of
---@param format ReviewReportFormat
---@return string path
local function report_path(repository, mode, format)
  local name = (repository:gsub("%%", "%%25"):gsub("/", "%%2F"))
  return ("%s/%s-%s.%s"):format(directory(), name, mode, EXTENSIONS[format])
end

---Generate the report of the review under way in a format: deliver the open
---annotations of the mode — or, with none open, redo the last delivery of it —,
---write the document, and fill the quickfix with the same points.
---
---Delivered before the file is written: the document is built all the same
---when writing fails, and it still goes to the clipboard, which is how it
---reaches the agent.
---
---Nothing is written when the mode has nothing open and nothing delivered: a
---report of an empty review says nothing. What an earlier generation left goes
---with it, in both formats — the documents and the list are this review as it
---stands, and one still holding a delivery that is gone would be saying what
---the review no longer says, in the file they hand to the agent.
---@param repository string absolute path of the repository root
---@param mode ReviewMode the review to report
---@param format ReviewReportFormat
---@return string|nil path where it was written; nil when there was nothing to
---write, or writing failed
---@return integer count of annotations in it
---@return string[]|nil lines of the document, written or not — it is built
---before the file is; nil when there was nothing to write
---@return boolean redone whether it is the last delivery made again, and not a
---new one
function M.generate(repository, mode, format)
  local delivery = state.deliver(repository, mode.key, function(open) return build(repository, mode, open) end)
  local redone = false
  if not delivery then
    delivery = state.last_delivery(repository, mode.key)
    redone = delivery ~= nil
  end
  if not delivery then
    for other in pairs(EXTENSIONS) do
      vim.fn.delete(report_path(repository, mode.key, other))
    end
    vim.fn.setqflist({}, " ", { title = QUICKFIX_TITLE, items = {} })
    return nil, 0, nil, false
  end

  local path = report_path(repository, mode.key, format)
  local lines = render(delivery, format)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  if vim.fn.writefile(lines, path) ~= 0 then
    vim.notify("review: não foi possível gravar o relatório em " .. path, vim.log.levels.WARN)
    return nil, #delivery.items, lines, redone
  end

  -- Looked for on disk now, a redone delivery included: the report is what the
  -- agent got, and the list is the reviewer's way through today's file.
  fill_quickfix(repository, delivery.items)
  return path, #delivery.items, lines, redone
end

return M
