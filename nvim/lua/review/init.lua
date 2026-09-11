---Painel de revisão de código com Git.
---
---A janela lateral que lista os arquivos em revisão, agrupados por estado, e
---que é o ponto de partida de toda ação de revisão. Este módulo é toda a API
---pública do plugin.
local M = {}

---The global keys `setup` mapped, by mode, with the function each one runs —
---which is what tells a key still ours from one somebody else has put on the
---same lhs since.
---@type { mode: string, run: fun() }[]
local global_keys = {}

---Map the global keys of the review, in every buffer: the ones that annotate —
---in normal mode on the line of the cursor, in visual mode on the run of lines
---selected — and the one that marks what is being read as seen and opens the
---next one still to read.
---
---From the options, and at the moment they are set: the winbar of the diff
---writes these same keys, and a mapping read from anywhere before the options
---are is a second copy of the key, which disagrees the first time the reviewer
---changes it. The keys a previous `setup` mapped go first, so changing one moves
---it instead of leaving the old one behind.
---@param mappings ReviewMappings
local function map_global_keys(mappings)
  for _, key in ipairs(global_keys) do
    for _, map in ipairs(vim.api.nvim_get_keymap(key.mode)) do
      if map.callback == key.run then pcall(vim.keymap.del, key.mode, map.lhs) end
    end
  end
  global_keys = {}

  local function annotate() M.annotate() end
  local function annotate_long() M.annotate { long = true } end
  local function seen_and_next() M.seen_and_next() end
  for _, key in ipairs {
    { mode = "n", lhs = mappings.annotate_line, run = annotate, desc = "Anotar a linha" },
    { mode = "n", lhs = mappings.annotate_line_long, run = annotate_long, desc = "Anotar a linha em várias linhas" },
    { mode = "x", lhs = mappings.annotate_line, run = annotate, desc = "Anotar o trecho" },
    { mode = "x", lhs = mappings.annotate_line_long, run = annotate_long, desc = "Anotar o trecho em várias linhas" },
    {
      mode = "n",
      lhs = mappings.seen_and_open_next,
      run = seen_and_next,
      desc = "Marcar como visto e abrir a próxima não vista",
    },
  } do
    vim.keymap.set(key.mode, key.lhs, key.run, { desc = key.desc })
    global_keys[#global_keys + 1] = { mode = key.mode, run = key.run }
  end
end

---Override the panel's options, and map from them the global keys of the
---review. The panel opens without it, with the defaults; the keys that work
---from inside a file are only there once it has run.
---@param opts table|nil see `ReviewConfig`
---@return ReviewConfig
function M.setup(opts)
  local options = require("review.config").setup(opts)
  map_global_keys(options.mappings)
  return options
end

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

---Write the annotation of the line the cursor is on, in the file being read —
---or, called from a key pressed in visual mode, of the lines selected. A point
---that already has one is edited, instead of gaining a second remark.
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
---annotations grouped by file, written outside the repository and put in the
---clipboard, and the same points in the quickfix. Of the repository the panel
---of this tabpage is listing, or of the one containing the current directory
---when there is no panel here.
function M.report()
  local panel = require "review.panel"
  require("review.actions").report(panel.repository(), panel.mode())
end

return M
