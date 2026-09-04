---Painel de revisão de código com Git.
---
---A janela lateral que lista os arquivos em revisão, agrupados por estado, e
---que é o ponto de partida de toda ação de revisão. Este módulo é toda a API
---pública do plugin.
local M = {}

---Override the panel's options. Optional: the defaults apply without it.
---@param opts table|nil see `ReviewConfig`
---@return ReviewConfig
function M.setup(opts) return require("review.config").setup(opts) end

---Open the panel on the repository containing the current directory.
function M.open() require("review.panel").open() end

---Close the panel.
function M.close() require("review.panel").close() end

---Open the panel, or close it when it is already open.
function M.toggle() require("review.panel").toggle() end

---Re-read git and re-render every panel that is open. The panel is one per
---tabpage, but the repository it is listing is not.
function M.refresh() require("review.panel").refresh() end

---Review a commit: the panel of this tabpage lists the files of that commit
---instead of the working tree, with the same sections and the same keys
---(ADR-0001). It opens if it was closed.
---
---This is what the graph calls with the commit the reviewer chose, ours and
---the gitgraph's alike.
---@param rev string anything git resolves to a commit
function M.commit(rev) require("review.panel").commit(rev) end

---Review a range of commits: the panel lists what changed across the whole
---range instead of the working tree, with the same sections and the same keys.
---Both ends are part of it. It opens if it was closed.
---
---This is what the graph calls with the range the reviewer selected.
---@param oldest string the commit the range starts at
---@param newest string the commit it ends at
function M.range(oldest, newest) require("review.panel").range(oldest, newest) end

---Go back to reviewing the working tree.
function M.worktree() require("review.panel").worktree() end

---Write the annotation of the line the cursor is on, in the file being read.
---A line that already has one is edited, instead of gaining a second remark.
---@param opts { long: boolean|nil }|nil `long = true` opens the entry of
---several lines, for an observation that does not fit in a sentence
function M.annotate(opts)
  local panel = require "review.panel"
  -- In the mode the panel of this tabpage is in: the remark belongs to the
  -- review being made, and the review being made is the one on the list beside
  -- the file.
  require("review.actions").annotate_line(panel.mode(), opts, panel.refresh)
end

---Mark the file the review is on as seen and open the next one still to read.
---
---The loop of the list, on a key that works from inside the file being read,
---which is where the reviewer is nearly all the time. What it marks is the
---entry under the panel's cursor: that cursor is the position of the review
---(ADR-0009), and the file on the screen would not answer which of the entries
---of a file changed twice is being read.
function M.seen_and_next() require("review.panel").seen_and_next() end

---Generate the report of the review under way: a markdown document with the
---annotations grouped by file, written outside the repository, and the same
---points in the quickfix. Of the repository the panel of this tabpage is
---listing, or of the one containing the current directory when there is no
---panel here.
function M.report()
  local panel = require "review.panel"
  require("review.actions").report(panel.repository(), panel.mode())
end

return M
