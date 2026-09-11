---The review state that outlives the session.
---
---What is seen and what was annotated are written under the editor's data
---directory, in one JSON document per repository (ADR-0004): the review never
---writes inside the repository being reviewed, where it would show up as
---untracked in the very list the panel is displaying. Each seen mark is keyed
---by the content under review, not by the path (ADR-0002), which is what makes
---a file that changed after being marked come back as unseen.
---
---Nothing is cached in memory: the document is read on every draw and written
---on every mark. It is a small file, and reading it is what makes the panel of
---a second editor — or of the same one, reopened — show what was marked
---elsewhere instead of a stale copy of it.
local WORKTREE = require("review.mode").WORKTREE

local M = {}

---The schema of the document written here. A document of any other version is
---not read: this one is a convenience, and misreading a future schema would be
---worse than starting the marks over.
---
---The annotations went into this same version instead of bumping it. The
---version exists to refuse a document this code cannot make sense of, and a
---document written before them is not one: it simply has no annotations in it,
---which is what a review that never wrote one looks like anyway. Bumping would
---throw away the seen marks of every review under way to announce a field
---whose absence already reads correctly.
---
---The version of the line an annotation was read in went in the same way: a
---line written before it has none, and in the working tree reads as the file on
---disk, which was the only place a line could be annotated then.
---
---And so did the deliveries: a document written before them has none, and every
---annotation in it is open — nothing had been handed to an agent as a delivery
---yet, so the next report takes them all, which is what it took then.
local VERSION = 1

---@return string directory the documents live in
local function directory() return vim.fn.stdpath "data" .. "/review" end

---The document of a repository. The root goes into the name percent-encoded,
---which keeps it readable and unambiguous — a file name cannot hold the "/"
---the root is full of.
---@param root string absolute path of the repository root
---@return string path
local function document_path(root)
  local name = (root:gsub("%%", "%%25"):gsub("/", "%%2F"))
  return ("%s/%s.json"):format(directory(), name)
end

---@class ReviewMark what is known about one content marked as seen
---@field path string the path it was marked from, for whoever reads the file
---@field at string when it was marked, in UTC

---@class ReviewAnnotation what the reviewer wrote about one point of the code
---@field path string the file it is about, from the repository root
---@field mode string the mode of the review it was written in
---@field line integer|nil the line it is tied to, the first of a run of them;
---absent on a file annotation
---@field end_line integer|nil the last line of a run; absent on a line alone
---@field version ReviewAnnotationVersion|nil the version the line was read in;
---absent on a file annotation, and on a line written before annotations had a
---version — which was the file on disk, and in a commit or a range is looked
---for in the commit of the mode when the report is generated (ADR-0011)
---@field anchor string|nil the text of those lines when it was written, one per
---line (ADR-0003)
---@field type string|nil what the reviewer asks the agent for with it; absent on
---one written before annotations had a type, which counts as `issue`
---@field text string what the reviewer wrote
---@field at string when it was written, in UTC
---@field delivery integer|nil the id of the delivery it went out in; absent on
---an open one (ADR-0012)

---@class ReviewDelivery: ReviewReport the open annotations of a mode that went
---out together in a report, frozen as the agent got them: the header, the
---items with the lines and the code of that moment, and what the preamble was
---written from
---@field id integer
---@field mode string the mode it is of
---@field at string when it was made, in UTC

---@class ReviewDocument
---@field version integer
---@field seen table<string, ReviewMark> indexed by content key
---@field annotations ReviewAnnotation[] in the order they were written
---@field deliveries ReviewDelivery[] in the order they were made

---@return ReviewDocument
local function empty() return { version = VERSION, seen = {}, annotations = {}, deliveries = {} } end

---@return string now, in UTC
local function now()
  return os.date "!%Y-%m-%dT%H:%M:%SZ" --[[@as string]]
end

---@param root string
---@return ReviewDocument
local function load(root)
  local path = document_path(root)
  if vim.fn.filereadable(path) == 0 then return empty() end

  local ok, document = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(path), "\n")) end)
  if not ok or type(document) ~= "table" or document.version ~= VERSION then return empty() end
  if type(document.seen) ~= "table" then document.seen = {} end
  if type(document.annotations) ~= "table" then document.annotations = {} end
  if type(document.deliveries) ~= "table" then document.deliveries = {} end
  return document
end

---@param root string
---@param document ReviewDocument
local function save(root, document)
  vim.fn.mkdir(directory(), "p")
  -- An empty table is a list to the encoder, and a document whose `seen` came
  -- back as `[]` would not be a document of this schema anymore.
  if not next(document.seen) then document.seen = vim.empty_dict() end

  -- Written beside the document and moved onto it, so an interrupted write
  -- leaves the previous state instead of half a document.
  local path = document_path(root)
  local partial = path .. ".tmp"
  if vim.fn.writefile({ vim.json.encode(document) }, partial) ~= 0 or not vim.uv.fs_rename(partial, path) then
    vim.notify("review: não foi possível gravar o estado da revisão.", vim.log.levels.WARN)
  end
end

---The contents marked as seen in a repository.
---@param root string absolute path of the repository root
---@return table<string, true>
function M.seen(root)
  local seen = {}
  for content in pairs(load(root).seen) do
    seen[content] = true
  end
  return seen
end

---Mark a content as seen, or unmark it when it already is.
---@param root string absolute path of the repository root
---@param content string key of the content under review
---@param path string the path it was marked from
---@return boolean seen what the content became
function M.toggle(root, content, path)
  local document = load(root)
  if document.seen[content] then
    document.seen[content] = nil
  else
    document.seen[content] = { path = path, at = now() }
  end

  local seen = document.seen[content] ~= nil
  save(root, document)
  return seen
end

---The version the line of an annotation was read in. One on a line of the
---working tree written before annotations had a version was written on the
---file itself, which is the only place a line could be annotated then.
---@param annotation ReviewAnnotation|ReviewPoint
---@return ReviewAnnotationVersion|nil nil on a file annotation, and on a line of
---a commit or a range written without a version
local function version_of(annotation)
  if annotation.version or not annotation.line then return annotation.version end
  if annotation.mode == WORKTREE.key then return "disk" end
end

---Whether an annotation is still open: not out in any report yet (ADR-0012).
---@param annotation ReviewAnnotation
---@return boolean
local function is_open(annotation) return annotation.delivery == nil end

---Whether an annotation is the open one written at `point`: the same file, in
---the same mode, read in the same version, on the same lines — where no line at
---all is the file annotation, of which there is one open per file and mode. Line
---5 of the index is another point than line 5 of the disk, because they are
---different lines. A run of lines is another point than its first line alone:
---the remark about a passage is not the remark about one line of it.
---
---A delivered one is not there anymore, as far as writing goes: after it went
---out the agent changed the code, and what is written on the same point is
---another request, not the correction of the one delivered.
---@param annotation ReviewAnnotation
---@param point ReviewPoint
---@return boolean
local function is_at(annotation, point)
  return is_open(annotation)
    and annotation.path == point.path
    and annotation.mode == point.mode
    and version_of(annotation) == version_of(point)
    and annotation.line == point.line
    and annotation.end_line == point.end_line
end

---The open annotations of one review among `annotations`: the ones written in
---that mode and not delivered yet, in the order they were written. The remarks
---of another mode belong to another review, and the delivered ones were already
---handed over.
---@param annotations ReviewAnnotation[]
---@param mode string the mode of the review
---@return ReviewAnnotation[]
local function open_in(annotations, mode)
  return vim.tbl_filter(function(annotation) return annotation.mode == mode and is_open(annotation) end, annotations)
end

---The open annotations of one review.
---@param root string absolute path of the repository root
---@param mode string the mode of the review
---@return ReviewAnnotation[]
function M.open_annotations(root, mode) return open_in(load(root).annotations, mode) end

---Deliver the open annotations of a mode: freeze what the report of them says,
---keep it as a delivery, and mark each of them with it — in one write, so the
---annotations delivered are exactly the ones the report was built from.
---
---The report is built by `build` from the annotations, and kept whole: the
---lines and the code of this moment, and what the preamble was written from.
---Redoing the delivery is rendering it again, and it has to be what the agent
---got however the file, the template or the configuration moved on since.
---@param root string absolute path of the repository root
---@param mode string the mode of the review
---@param build fun(open: ReviewAnnotation[]): ReviewReport
---@return ReviewDelivery|nil nil when there is no open annotation in the mode,
---which is nothing to deliver
function M.deliver(root, mode, build)
  local document = load(root)
  local open = open_in(document.annotations, mode)
  if #open == 0 then return nil end

  -- Past every id there is, and not the count of them: an id is what an
  -- annotation points at, and two deliveries must never share one.
  local id = 1
  for _, earlier in ipairs(document.deliveries) do
    id = math.max(id, earlier.id + 1)
  end

  local delivery = vim.tbl_extend("error", build(open), { id = id, mode = mode, at = now() })
  for _, annotation in ipairs(open) do
    annotation.delivery = id
  end
  document.deliveries[#document.deliveries + 1] = delivery
  save(root, document)
  return delivery
end

---The last delivery of a mode, if there is one.
---@param root string absolute path of the repository root
---@param mode string the mode of the review
---@return ReviewDelivery|nil
function M.last_delivery(root, mode)
  local deliveries = load(root).deliveries
  for index = #deliveries, 1, -1 do
    if deliveries[index].mode == mode then return deliveries[index] end
  end
end

---The open annotation already written at a point, if there is one.
---@param point ReviewPoint
---@return ReviewAnnotation|nil
function M.annotation_at(point)
  for _, annotation in ipairs(load(point.root).annotations) do
    if is_at(annotation, point) then return annotation end
  end
end

---Write the annotation of a point, replacing the open one that was there: the
---same point annotated twice is one observation revised, not two piled on the
---same place. A delivered one stays as it is, beside the new one.
---
---Empty text removes it. The entry comes prefilled with what is already
---written, so clearing it is how the reviewer takes an observation back — and
---an annotation with nothing in it would be a line in the report saying
---nothing.
---
---The anchor comes from the point and not from what was there before: it is
---the text of the line as the reviewer is reading it now, which is what the
---observation being written is about (ADR-0003).
---@param point ReviewPoint
---@param text string
---@param kind string the type of the annotation
function M.annotate(point, text, kind)
  local document = load(point.root)

  local kept = {}
  for _, annotation in ipairs(document.annotations) do
    if not is_at(annotation, point) then kept[#kept + 1] = annotation end
  end
  if text ~= "" then
    kept[#kept + 1] = {
      path = point.path,
      mode = point.mode,
      version = point.version,
      line = point.line,
      end_line = point.end_line,
      anchor = point.anchor,
      type = kind,
      text = text,
      at = now(),
    }
  end

  document.annotations = kept
  save(point.root, document)
end

return M
