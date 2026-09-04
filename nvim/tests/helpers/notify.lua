-- The messages the editor shows.

-- Most keys of the panel answer with what they put on the screen, and the test
-- reads that. A key that finds the end of something has nothing to move, and
-- then the message is the whole of the answer: the suite installs a `vim.notify`
-- it can read, the same way it installs a clipboard and a selection UI.

local M = {}

---Everything said since `M.install`, in order.
---@type string[]
local said = {}

---The editor's own `vim.notify`, put back by `M.restore`.
---@type function|nil
local previous = nil

---Make this the editor's notification UI.
function M.install()
  said = {}
  previous = previous or vim.notify
  vim.notify = function(message)
    said[#said + 1] = message
    return nil
  end
end

---@return string[] what the panel has said, in order
function M.messages() return vim.deepcopy(said) end

---@return string the last thing it said, and the empty string when it said nothing
function M.last() return said[#said] or "" end

---Give the editor its own notification UI back.
function M.restore()
  if previous then vim.notify = previous end
  previous, said = nil, {}
end

return M
