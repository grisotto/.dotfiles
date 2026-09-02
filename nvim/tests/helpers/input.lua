-- The one-line entry of the test editor.
--
-- An annotation of one line is asked through the editor's own input UI, the
-- same way the confirmation before discarding goes through its selection UI.
-- The suite installs one it can read — what the entry asked, and what it came
-- prefilled with, which is how editing an annotation that is already there
-- shows itself — and one it can drive: what the reviewer types into it.

local M = {}

---@class TestEntryPrompt what one call to the entry put on screen
---@field prompt string what it asked
---@field default string what it came prefilled with

---Every entry shown since `M.install`, in order.
---@type TestEntryPrompt[]
local asked = {}

---What the reviewer types from here on. Nothing is what a reviewer who presses
---Esc leaves behind, and it is the default on purpose: a test that forgot to
---type must not silently write an annotation.
---@type string|nil
local answer = nil

---The editor's own input UI, put back by `M.restore`.
---@type function|nil
local previous = nil

---Make this the editor's input UI.
function M.install()
  asked, answer = {}, nil
  previous = previous or vim.ui.input
  vim.ui.input = function(opts, on_confirm)
    asked[#asked + 1] = { prompt = opts and opts.prompt or "", default = opts and opts.default or "" }
    on_confirm(answer)
  end
end

---What the reviewer types from here on.
---@param text string|nil nil is a cancelled entry
function M.answer(text) answer = text end

---@return string[] the prompts the entry has shown, in order
function M.prompts()
  return vim.tbl_map(function(shown) return shown.prompt end, asked)
end

---@return string[] what each entry came prefilled with, in order
function M.defaults()
  return vim.tbl_map(function(shown) return shown.default end, asked)
end

---Give the editor its own input UI back.
function M.restore()
  if previous then vim.ui.input = previous end
  previous, asked, answer = nil, {}, nil
end

return M
