-- The confirmation prompt of the test editor.
--
-- Discarding a change asks before acting, and it asks through the editor's own
-- selection UI, the same way copying goes through the editor's own clipboard
-- provider. The suite installs one it can read — what the panel asked — and
-- one it can drive — what the reviewer answers.

local M = {}

---Every prompt shown since `M.install`, in order.
---@type string[]
local asked = {}

---What the reviewer picks on the next prompt. Nothing is what a reviewer who
---presses Esc leaves behind, and it is the default on purpose: a test that
---forgot to answer must not silently discard anything.
---@type string|nil
local answer = nil

---The editor's own selection UI, put back by `M.restore`.
---@type function|nil
local previous = nil

---Make this the editor's selection UI.
function M.install()
  asked, answer = {}, nil
  previous = previous or vim.ui.select
  vim.ui.select = function(items, opts, on_choice)
    asked[#asked + 1] = opts and opts.prompt or ""
    local choice, index = nil, nil
    for position, item in ipairs(items) do
      if item == answer then
        choice, index = item, position
      end
    end
    on_choice(choice, index)
  end
end

---What the reviewer answers from here on.
---@param choice string|nil one of the offered items; nil is a cancelled prompt
function M.answer(choice) answer = choice end

---@return string[] the prompts the panel has shown, in order
function M.prompts() return vim.deepcopy(asked) end

---Give the editor its own selection UI back.
function M.restore()
  if previous then vim.ui.select = previous end
  previous, asked, answer = nil, {}, nil
end

return M
