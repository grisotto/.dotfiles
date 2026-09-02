-- The review report, read back from where it was written.
--
-- It is the document the reviewer leaves the editor with, so what a test reads
-- here is its text: the file headings, and the lines under each of them.
--
-- Found by sweeping the editor's data directory rather than by rebuilding the
-- name the report module gives it: that a test finds it outside the repository
-- under review is half of what it is asserting (ADR-0004).

local M = {}

---@return string[] paths of the reports written by the review
local function written() return vim.fn.glob(vim.fn.stdpath "data" .. "/**/*.md", false, true) end

---@return boolean whether a report was generated at all
function M.exists() return #written() > 0 end

---The report of the repository under review. There is one: each test gets a
---data directory of its own (`fixture.data_dir`) and reviews one repository.
---@return string path
function M.path()
  local reports = written()
  assert(#reports == 1, ("expected one review report, found %d"):format(#reports))
  return reports[1]
end

---@return string[] every line of the report, in order
function M.lines() return vim.fn.readfile(M.path()) end

---@return string text of the whole report
function M.text() return table.concat(M.lines(), "\n") end

---The headings the report is grouped by, in order: one per file with
---annotations, plus the section of the displaced ones when there is one.
---@return string[]
function M.headings()
  local headings = {}
  for _, line in ipairs(M.lines()) do
    local heading = line:match "^## (.+)$"
    if heading then headings[#headings + 1] = heading end
  end
  return headings
end

---@param lines string[]
---@return string[] without the blank lines at either end
local function trimmed(lines)
  while lines[1] == "" do
    table.remove(lines, 1)
  end
  while lines[#lines] == "" do
    table.remove(lines)
  end
  return lines
end

---What is written under one heading of the report, up to the next one.
---@param heading string e.g. "a.txt"
---@return string[] lines
function M.section(heading)
  local lines, inside = {}, false
  for _, line in ipairs(M.lines()) do
    if line:match "^## " then
      if inside then break end
      inside = line == "## " .. heading
    elseif inside then
      lines[#lines + 1] = line
    end
  end
  assert(inside, ("no section %q in the report:\n%s"):format(heading, M.text()))
  return trimmed(lines)
end

return M
