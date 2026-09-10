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
---@field anchor string|nil the text of those lines when it was written, one per
---line (ADR-0003)
---@field text string what the reviewer wrote
---@field at string when it was written, in UTC

---@class ReviewDocument
---@field version integer
---@field seen table<string, ReviewMark> indexed by content key
---@field annotations ReviewAnnotation[] in the order they were written

---@return ReviewDocument
local function empty() return { version = VERSION, seen = {}, annotations = {} } end

---@param root string
---@return ReviewDocument
local function load(root)
  local path = document_path(root)
  if vim.fn.filereadable(path) == 0 then return empty() end

  local ok, document = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(path), "\n")) end)
  if not ok or type(document) ~= "table" or document.version ~= VERSION then return empty() end
  if type(document.seen) ~= "table" then document.seen = {} end
  if type(document.annotations) ~= "table" then document.annotations = {} end
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
    document.seen[content] = { path = path, at = os.date "!%Y-%m-%dT%H:%M:%SZ" }
  end

  local seen = document.seen[content] ~= nil
  save(root, document)
  return seen
end

---Whether an annotation is the one written at `point`: the same file, in the
---same mode, on the same lines — where no line at all is the file annotation,
---of which there is one per file and mode. A run of lines is another point than
---its first line alone: the remark about a passage is not the remark about one
---line of it.
---@param annotation ReviewAnnotation
---@param point ReviewPoint
---@return boolean
local function is_at(annotation, point)
  return annotation.path == point.path
    and annotation.mode == point.mode
    and annotation.line == point.line
    and annotation.end_line == point.end_line
end

---Every annotation of a repository, in the order they were written.
---@param root string absolute path of the repository root
---@return ReviewAnnotation[]
function M.annotations(root) return load(root).annotations end

---The annotation already written at a point, if there is one.
---@param point ReviewPoint
---@return ReviewAnnotation|nil
function M.annotation_at(point)
  for _, annotation in ipairs(load(point.root).annotations) do
    if is_at(annotation, point) then return annotation end
  end
end

---Write the annotation of a point, replacing whatever was there: the same
---point annotated twice is one observation revised, not two piled on the same
---place.
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
function M.annotate(point, text)
  local document = load(point.root)

  local kept = {}
  for _, annotation in ipairs(document.annotations) do
    if not is_at(annotation, point) then kept[#kept + 1] = annotation end
  end
  if text ~= "" then
    kept[#kept + 1] = {
      path = point.path,
      mode = point.mode,
      line = point.line,
      end_line = point.end_line,
      anchor = point.anchor,
      text = text,
      at = os.date "!%Y-%m-%dT%H:%M:%SZ",
    }
  end

  document.annotations = kept
  save(point.root, document)
end

return M
