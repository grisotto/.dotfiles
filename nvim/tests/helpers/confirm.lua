-- The selection UI of the test editor.
--
-- Discarding a change asks before acting, and choosing the branch the graph is
-- filtered by is a search: both go through the editor's own selection UI, the
-- same way copying goes through the editor's own clipboard provider. The suite
-- installs one it can read — what was asked, and what was offered — and one it
-- can drive — what the reviewer picks.

local M = {}

---Every prompt shown since `M.install`, in order.
---@type string[]
local asked = {}

---What each of those prompts offered to choose from.
---@type string[][]
local offered = {}

---What the reviewer picks on the next prompt. Nothing is what a reviewer who
---presses Esc leaves behind, and it is the default on purpose: a test that
---forgot to answer must not silently discard anything.
---@type string|nil
local answer = nil

---The pattern the reviewer picks by, for a list whose lines a test cannot
---spell out: a commit is offered with its short sha in it, and the sha is the
---repository's to decide.
---@type string|nil
local pattern = nil

---The editor's own selection UI, put back by `M.restore`.
---@type function|nil
local previous = nil

---Make this the editor's selection UI.
function M.install()
  asked, offered, answer, pattern = {}, {}, nil, nil
  previous = previous or vim.ui.select
  vim.ui.select = function(items, opts, on_choice)
    asked[#asked + 1] = opts and opts.prompt or ""
    offered[#offered + 1] = vim.deepcopy(items)
    local choice, index = nil, nil
    for position, item in ipairs(items) do
      if item == answer or (pattern and item:match(pattern)) then
        choice, index = item, position
      end
    end
    on_choice(choice, index)
  end
end

---What the reviewer answers from here on.
---@param choice string|nil one of the offered items; nil is a cancelled prompt
function M.answer(choice)
  answer, pattern = choice, nil
end

---The line the reviewer picks from here on, read the way they read the list:
---by what is written on it. It is how a commit is chosen in a search that
---offers it with its short sha, which the test has no way of writing down.
---@param by string a Lua pattern; nothing matching it is a cancelled prompt
function M.answer_matching(by)
  answer, pattern = nil, by
end

---@return string[] the prompts the panel has shown, in order
function M.prompts() return vim.deepcopy(asked) end

---What the last prompt gave the reviewer to choose from, which is the list a
---search shows.
---@return string[]
function M.offered() return vim.deepcopy(offered[#offered] or {}) end

---Give the editor its own selection UI back.
function M.restore()
  if previous then vim.ui.select = previous end
  previous, asked, offered, answer, pattern = nil, {}, {}, nil, nil
end

return M
