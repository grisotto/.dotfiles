-- Reading the context menu the way the reviewer sees it when the right button
-- opens it: the entries of the editor's own popup menu, in the order it lists
-- them, and choosing one of them the way a click does.

local M = {}

local ROOT = "PopUp"

---A menu name as the editor's own commands take it: the separator between
---levels is the dot, so everything that is not one has to be escaped.
---@param name string
---@return string
local function escaped(name) return (name:gsub("([ \\.|])", "\\%1")) end

---Every entry of the context menu, in the order it shows them.
---@return string[]
function M.entries()
  local root = vim.fn.menu_get(ROOT)[1]
  if not root then return {} end
  return vim.tbl_map(function(item) return item.name end, root.submenus or {})
end

---@param pattern string a Lua pattern
---@return string|nil entry
function M.entry_matching(pattern)
  for _, entry in ipairs(M.entries()) do
    if entry:match(pattern) then return entry end
  end
end

---The entries that name an action and a key, as the key it shows mapped to the
---action beside it. An entry with a single column — a separator, or an entry of
---the editor's own — is not one of them.
---@return table<string, string> key to action
function M.actions()
  local actions = {}
  for _, entry in ipairs(M.entries()) do
    local action, key = entry:match "^(.-)%s%s+(%S+)$"
    if action then actions[key] = action end
  end
  return actions
end

---Choose the entry matching `pattern`, which is what clicking it does.
---@param pattern string a Lua pattern
function M.choose(pattern)
  local entry = assert(M.entry_matching(pattern), ("no context menu entry matching %q"):format(pattern))
  vim.cmd("emenu " .. ROOT .. "." .. escaped(entry))
  -- `:emenu` puts the entry's keys in the queue; this is what runs them.
  vim.api.nvim_feedkeys("", "x", false)
end

return M
