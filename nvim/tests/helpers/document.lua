-- The review state document, read back from where it was written.
--
-- The seen marks are judged by what the panel shows, and need nothing from
-- here. An annotation carries fields no one can see yet: the anchor and the
-- instant only reach the reviewer through the review report, which is the next
-- slice. Until then the document is where they are observable, and it is the
-- right place to look at them: it is a persisted artifact with a schema of its
-- own — the contract the report will read — and not a structure inside the
-- plugin.
--
-- Found by looking under the editor's data directory rather than by rebuilding
-- the name the state module gives it: that a test finds it there at all is
-- half of what it is asserting (ADR-0004).

local M = {}

---@return string[] paths of the documents written by the review
local function written() return vim.fn.glob(vim.fn.stdpath "data" .. "/review/*.json", false, true) end

---@return boolean whether the review has written any state at all
function M.exists() return #written() > 0 end

---The document of the repository under review. There is one: each test gets a
---data directory of its own (`fixture.data_dir`) and reviews one repository.
---@return table
local function read()
  local documents = written()
  assert(#documents == 1, ("expected one review document, found %d"):format(#documents))
  return vim.json.decode(table.concat(vim.fn.readfile(documents[1]), "\n"))
end

---The annotations of the repository under review, in the order they were
---written. None at all when nothing was ever written.
---@return table[]
function M.annotations()
  if not M.exists() then return {} end
  return read().annotations or {}
end

---Put an annotation into the document by hand, as a review of another mode
---would have left it there.
---
---The only way to write one today: the panel lists the working tree and
---nothing else, so the annotation of a commit — which the report has to leave
---out — cannot be written through the editor yet. The document is the contract
---between the two, which is why the annotation is planted in it and not in a
---structure inside the plugin.
---@param annotation table
function M.plant(annotation)
  local documents = written()
  assert(#documents == 1, ("expected one review document, found %d"):format(#documents))
  local content = read()
  content.annotations = content.annotations or {}
  content.annotations[#content.annotations + 1] = annotation
  assert(vim.fn.writefile({ vim.json.encode(content) }, documents[1]) == 0, "could not write the review document")
end

return M
