-- The review report, read back from where it was written.
--
-- It is the document the reviewer hands to the agent, in one of two formats —
-- tags XML from `R`, markdown from `M` (ADR-0006) — with the same content in
-- both. So what a test reads here is that content, whichever format carried
-- it: the header, the preamble and the items, each with its id, type, file,
-- lines, quoted code and text. Reading both formats into the same shape is
-- what lets a test say that the two carry the same items.
--
-- Found by sweeping the editor's data directory rather than by rebuilding the
-- name the report module gives it: that a test finds it outside the repository
-- under review is half of what it is asserting (ADR-0004).

local M = {}

---@alias TestReportFormat "xml"|"markdown"

---The extension each format is written with.
---@type table<TestReportFormat, string>
local EXTENSIONS = { xml = "xml", markdown = "md" }

---@param format TestReportFormat|nil nil for either
---@return string[] paths of the reports written by the review
local function written(format)
  local found = {}
  for name, extension in pairs(EXTENSIONS) do
    if not format or format == name then
      vim.list_extend(found, vim.fn.glob(vim.fn.stdpath "data" .. "/**/*." .. extension, false, true))
    end
  end
  return found
end

---@param format TestReportFormat|nil nil for either
---@return boolean whether a report was generated at all
function M.exists(format) return #written(format) > 0 end

---The report of the repository under review, in one format. There is one: each
---test gets a data directory of its own (`fixture.data_dir`) and reviews one
---repository.
---@param format TestReportFormat|nil nil when only one format was generated
---@return string path
function M.path(format)
  local reports = written(format)
  assert(#reports == 1, ("expected one review report, found %d"):format(#reports))
  return reports[1]
end

---@param format TestReportFormat|nil
---@return string[] every line of the report, in order
function M.lines(format) return vim.fn.readfile(M.path(format)) end

---@param format TestReportFormat|nil
---@return string text of the whole report
function M.text(format) return table.concat(M.lines(format), "\n") end

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

---@class TestReportHeader what the report says it is about
---@field root string absolute path of the repository root
---@field branch string
---@field reference string what was reviewed: HEAD, a commit, a range

---@class TestReportItem one annotation, as the agent reads it
---@field id integer
---@field type string
---@field file string from the repository root
---@field lines string|nil "2" or "2-4"; absent on a file annotation and on one not found
---@field code string[]|nil the quoted lines; absent on a file annotation
---@field text string what the reviewer wrote
---@field not_found boolean whether the quoted code was not found

---@param tag string the inside of an opening tag, after its name
---@return table<string, string>
local function attributes(tag)
  local found = {}
  for name, value in tag:gmatch '([%w_]+)="(.-)"' do
    found[name] = value
  end
  return found
end

---@param lines string[] of the XML document
---@return TestReportHeader header
---@return string instructions
---@return TestReportItem[] items
local function read_xml(lines)
  local root = assert(lines[1]:match "^<code_review(.*)>$", "the XML report does not start with <code_review>")
  local header = attributes(root)

  local instructions, items = {}, {}
  local inside, item = nil, nil
  for index = 2, #lines do
    local line = lines[index]
    if inside == "instructions" then
      if line == "</instructions>" then
        inside = nil
      else
        instructions[#instructions + 1] = line
      end
    elseif inside == "code" then
      if line == "</code>" then
        inside = "comment"
      else
        item.code[#item.code + 1] = line
      end
    elseif inside == "comment" then
      if line == "</comment>" then
        item.text = table.concat(trimmed(item.text), "\n")
        items[#items + 1] = item
        inside, item = nil, nil
      elseif line == "<code>" and #item.text == 0 then
        item.code, inside = {}, "code"
      else
        item.text[#item.text + 1] = line
      end
    elseif line == "<instructions>" then
      inside = "instructions"
    elseif line:match "^<comment " then
      local found = attributes(line:match "^<comment(.*)>$")
      item = {
        id = tonumber(found.id),
        type = found.type,
        file = found.file,
        lines = found.lines,
        text = {},
        not_found = found.status == "not-found",
      }
      inside = "comment"
    end
  end

  return header, table.concat(trimmed(instructions), "\n"), items
end

---@param lines string[] of the markdown document
---@return TestReportHeader header
---@return string instructions
---@return TestReportItem[] items
local function read_markdown(lines)
  local root, branch, reference = lines[1]:match "^# Code review · (.-) · branch (.-) · (.*)$"
  assert(root, "the markdown report does not start with its title: " .. lines[1])

  local instructions, items = {}, {}
  local item, fence = nil, nil
  for index = 2, #lines do
    local line = lines[index]
    local id, kind, about = nil, nil, nil
    if not fence then
      id, kind, about = line:match "^## (%d+)%. (%S+) · (.*)$"
    end

    if id then
      if item then item.text = table.concat(trimmed(item.text), "\n") end
      local not_found = about:match " · trecho não encontrado$" ~= nil
      about = about:gsub(" · trecho não encontrado$", "")
      local file, span = about:match "^(.*):(%d+%-?%d*)$"
      item = {
        id = tonumber(id),
        type = kind,
        file = file or about,
        lines = span,
        text = {},
        not_found = not_found,
      }
      items[#items + 1] = item
    elseif not item then
      instructions[#instructions + 1] = line
    elseif fence then
      if line == fence then
        fence = nil
      else
        item.code[#item.code + 1] = line
      end
    elseif not item.code and #trimmed(vim.list_slice(item.text)) == 0 and line:match "^```" then
      fence, item.code = line:match "^(`+)", {}
    else
      item.text[#item.text + 1] = line
    end
  end
  if item then item.text = table.concat(trimmed(item.text), "\n") end

  return { root = root, branch = branch, reference = reference }, table.concat(trimmed(instructions), "\n"), items
end

---@param format TestReportFormat
---@return TestReportHeader header
---@return string instructions
---@return TestReportItem[] items
local function read(format)
  local lines = M.lines(format)
  if format == "xml" then return read_xml(lines) end
  return read_markdown(lines)
end

---What the report says it is about, before anything else in it.
---@param format TestReportFormat
---@return TestReportHeader
function M.header(format) return (read(format)) end

---The preamble: what the agent is asked to do with the items.
---@param format TestReportFormat
---@return string
function M.instructions(format)
  local _, instructions = read(format)
  return instructions
end

---Every item of the report, in the order it lists them.
---@param format TestReportFormat
---@return TestReportItem[]
function M.items(format)
  local _, _, items = read(format)
  return items
end

return M
