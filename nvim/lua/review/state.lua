---The review state that outlives the session.
---
---What is seen is written under the editor's data directory, in one JSON
---document per repository (ADR-0004): the review never writes inside the
---repository being reviewed, where it would show up as untracked in the very
---list the panel is displaying. Each mark is keyed by the content under
---review, not by the path (ADR-0002), which is what makes a file that changed
---after being marked come back as unseen.
---
---Nothing is cached in memory: the document is read on every draw and written
---on every mark. It is a small file, and reading it is what makes the panel of
---a second editor — or of the same one, reopened — show what was marked
---elsewhere instead of a stale copy of it.
local M = {}

---The schema of the document written here. A document of any other version is
---not read: this one is a convenience, and misreading a future schema would be
---worse than starting the marks over.
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

---@class ReviewDocument
---@field version integer
---@field seen table<string, ReviewMark> indexed by content key

---@param root string
---@return ReviewDocument
local function load(root)
  local path = document_path(root)
  if vim.fn.filereadable(path) == 0 then return { version = VERSION, seen = {} } end

  local ok, document = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(path), "\n")) end)
  if not ok or type(document) ~= "table" or document.version ~= VERSION then return { version = VERSION, seen = {} } end
  if type(document.seen) ~= "table" then document.seen = {} end
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

return M
