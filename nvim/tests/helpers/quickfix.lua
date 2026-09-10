-- The editor's own quickfix list, which is where generating the report puts
-- the annotated points so the reviewer can walk them.
--
-- Read from the editor and not from anything of ours: `:cnext` and the list
-- window read exactly this, so it is what the reviewer gets.

local M = {}

---@class TestQuickfixItem one point in the list
---@field file string absolute path of the file
---@field lnum integer line, 0 when the point has none
---@field end_lnum integer|nil last line, only on a point that spans several
---@field text string what the list shows about it

---Every point in the current list, in order.
---@return TestQuickfixItem[]
function M.items()
  return vim.tbl_map(function(item)
    return {
      file = item.bufnr ~= 0 and vim.api.nvim_buf_get_name(item.bufnr) or "",
      lnum = item.lnum,
      -- Only on a point of several lines, so a point of one reads as it
      -- always did.
      end_lnum = item.end_lnum > item.lnum and item.end_lnum or nil,
      text = item.text,
    }
  end, vim.fn.getqflist())
end

---@return string title the list was given, empty when it has none
function M.title() return vim.fn.getqflist({ title = true }).title end

---Whether the list window is on screen, which is how the reviewer sees the
---points without asking for them.
---@return boolean
function M.is_open()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.fn.getwininfo(win)[1].quickfix == 1 then return true end
  end
  return false
end

---Throw away every list the editor is holding, so a spec starts with none.
function M.clear()
  vim.cmd "cclose"
  vim.fn.setqflist({}, "f")
end

return M
