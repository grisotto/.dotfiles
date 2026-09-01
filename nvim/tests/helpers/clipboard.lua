-- The clipboard of the test editor.
--
-- Copying a path is only observable in the clipboard, so the suite needs one
-- it can read. It also needs one it can write to without consequence: the
-- machine's clipboard belongs to whoever is running the tests, and a suite
-- that overwrote what they had copied would be a nuisance.
--
-- Neovim resolves its clipboard provider once, on the first use of a register,
-- so this has to be installed before any of it happens — `tests/minimal_init.lua`
-- does it, and a later install would silently not take.

local M = {}

---What has been copied, per register, as the provider receives it.
---@type table<string, string[]>
local board = {}

---Make this the editor's clipboard provider.
function M.install()
  vim.g.clipboard = {
    name = "fixture",
    copy = {
      ["+"] = function(lines) board["+"] = lines end,
      ["*"] = function(lines) board["*"] = lines end,
    },
    paste = {
      ["+"] = function() return board["+"] or {} end,
      ["*"] = function() return board["*"] or {} end,
    },
  }
end

---What is in the clipboard now.
---@return string
function M.content() return table.concat(board["+"] or {}, "\n") end

---Empty it, so what a test reads is what it copied and not what the one before
---it left there.
function M.clear() board = {} end

return M
