---The panel's actions in the editor's context menu, each shown with the key
---that runs it — which is how the reviewer finds out what the panel can do
---without reading documentation.
---
---The menu of the editor is one, global, and not something a buffer owns: the
---entries are put in when the reviewer enters the panel and taken out when they
---leave it, so the right button means the same thing everywhere else as it
---always did.
local M = {}

---The menu the right button opens.
local ROOT = "PopUp"

---Ahead of the editor's own entries, which stay below ours: the reviewer opened
---this menu on a list of files, and the entries for the text under the cursor
---are not what they are looking for.
local PRIORITY = 100

---Between ours and the editor's, so the two blocks read as two blocks. A name
---between dashes is what the editor draws as a divider.
local SEPARATOR = "-review-"

---@class ReviewMenuItem one entry of the context menu
---@field label string what the action does, in the reviewer's words
---@field key string the key that runs the same action in the panel
---@field run fun()

---What each entry runs, by the position it was put in the menu. A menu entry
---carries keys, not a function, so it calls back in here for the one it stands
---for.
---@type fun()[]
local handlers = {}

---The entries currently in the menu, by the name they were created under, which
---is also the name they have to be removed under.
---@type string[]
local installed = {}

---Run the action of the entry that was chosen.
---@param index integer
function M.run(index)
  local handler = handlers[index]
  if handler then handler() end
end

---A menu name as the editor's own commands take it: the dot separates levels
---and the space separates arguments, so neither can be left as it is inside a
---name. The ampersand is the odd one out — it marks the letter that opens the
---entry from the keyboard, and is written twice to mean itself.
---@param name string
---@return string
local function escaped(name)
  return (name:gsub("[ \\.|&]", function(char) return char == "&" and "&&" or "\\" .. char end))
end

---@param text string
---@param width integer columns to fill
---@return string padded on the right, measured as it is drawn and not in bytes
local function padded(text, width) return text .. (" "):rep(math.max(width - vim.fn.strdisplaywidth(text), 0)) end

---Take the panel's entries out of the menu. Everything else in it — the
---editor's own entries, and whatever another plugin put there — is left alone.
function M.remove()
  for _, name in ipairs(installed) do
    pcall(vim.cmd, "aunmenu " .. ROOT .. "." .. name)
  end
  installed, handlers = {}, {}
end

---Put the panel's actions in the context menu, replacing the ones that are
---already there.
---
---The key goes inside the entry's own text, in a column of its own, and not in
---the accelerator field the editor has for exactly this: that field is drawn by
---graphical menus only, and in the terminal — where this menu is read — it is
---not shown at all. A shortcut nobody sees is the whole point missed.
---
---The one key the editor eats is `<Tab>`: written inside a menu name it *is*
---the separator of that accelerator field. A panel key configured as `<Tab>`
---shows its entry without the shortcut beside it — the entry still works, and
---still leaves the menu with the others.
---@param items ReviewMenuItem[]
function M.install(items)
  M.remove()

  local width = 0
  for _, item in ipairs(items) do
    width = math.max(width, vim.fn.strdisplaywidth(item.label))
  end

  for index, item in ipairs(items) do
    local name = escaped(padded(item.label, width) .. "  " .. item.key)
    handlers[index] = item.run
    vim.cmd(
      ("anoremenu %d.%d %s.%s <Cmd>lua require('review.menu').run(%d)<CR>"):format(
        PRIORITY,
        index * 10,
        ROOT,
        name,
        index
      )
    )
    installed[#installed + 1] = name
  end

  if #items > 0 then
    vim.cmd(("anoremenu %d.%d %s.%s <Nop>"):format(PRIORITY, (#items + 1) * 10, ROOT, SEPARATOR))
    installed[#installed + 1] = SEPARATOR
  end
end

return M
