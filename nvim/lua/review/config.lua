---Options of the review panel.
---
---Only presentation and coexistence choices live here. What is data model
---rather than preference — the panel being single with a mode, the boundary
---with neogit — is deliberately not exposed.
---
---The form of the annotation entry is not an option either, though the spec of
---the epic lists it as one. It went the way the two diff presentations went
---(ADR-0006): where both forms are worth having, they are both switched on, on
---keys of their own, instead of one of them being hidden behind a setting the
---reviewer has to change to reach it. Which key opens which entry is
---configurable here like every other key; that is the whole of the preference
---there is to express.
local M = {}

---@class ReviewMappings
---@field close string key that closes the panel from inside it
---@field refresh string key that re-reads git and re-renders
---@field diff string key that opens what the line represents
---@field diff_alternate string key that opens the same thing the other way
---@field diff_conflict string key that opens the three versions of a conflict beside the panel
---@field open string key that opens the file in the window beside the panel
---@field open_split string key that opens the file in a split
---@field open_rev string key that opens the file as it is in another rev, read only
---@field diff_rev string key that compares the file with its version in another rev
---@field toggle_seen string key that marks the file on the line as seen, or unmarks it
---@field annotate string key that writes the annotation of the file on the line
---@field annotate_long string key that writes it in the entry of several lines
---@field report string key that generates the report of the review under way
---@field graph string key that opens the graph of commits, to review one of them
---@field graph_alternate string key that opens the graph the other way
---@field branch string key of the graph that restricts it to a branch chosen in a search
---@field worktree string key that leaves the commit mode and lists the working tree again
---@field stage string key that moves the file on the line into the index
---@field unstage string key that takes the file on the line out of the index
---@field discard string key that throws the change on the line away, after confirming
---@field copy_relative_path string key that copies the path from the root of the file's project
---@field copy_absolute_path string key that copies the whole path of the file

---@class ReviewMergeLayouts diffview layouts a conflict opens in
---@field conflict string ours, the merge and theirs
---@field conflict_with_base string the same, plus the base version

---@class ReviewConfig
---@field position "left"|"right" side of the editor the panel opens on
---@field width integer width of the panel in columns
---@field seen_display "section"|"dimmed" where a file marked as seen is shown
---@field neo_tree "close"|"ignore" what to do with a neo-tree window in the way
---@field report_directory string|nil where the review report is written
---@field mappings ReviewMappings
---@field merge_layouts ReviewMergeLayouts
local defaults = {
  position = "left",
  width = 40,
  -- Where the report is written, as an absolute path. Absent, it goes beside
  -- the review state under the editor's data directory — outside the
  -- repository being reviewed, which is the part that is not a preference
  -- (ADR-0004). Pointing it at a directory inside the repository is the
  -- reviewer's own doing, and the panel says so: the report shows up as
  -- untracked in the list it is displaying.
  --
  -- The default is resolved when the report is generated and not here, so it
  -- follows the data directory of the editor that is running instead of the
  -- one that was running when the options were read.
  report_directory = nil,
  -- Both presentations of a seen file are meant to be tried in use: the
  -- section of its own at the end, which leaves only what is left on the list,
  -- and the dimming in place, which keeps the file where it is.
  seen_display = "section",
  neo_tree = "close",
  mappings = {
    close = "q",
    refresh = "r",
    -- Two keys for the same line, on purpose: the default presentation and the
    -- alternative one, to be compared in use before either becomes the
    -- standard (ADR-0006).
    diff = "<CR>",
    diff_alternate = "d",
    -- A conflict has a third presentation, and it gets the shifted key beside
    -- the other one: the pair reads like the copy keys below, two forms of the
    -- same gesture, and this is the form that keeps the list on screen.
    diff_conflict = "D",
    open = "o",
    open_split = "O",
    -- "e" de "em outro rev", e o par lê como os de cima: a tecla simples é a
    -- consulta — o arquivo como ele está lá, para ler —, a shifted é a
    -- comparação com o que está aqui. Como "v" e "w", a tecla é local a uma
    -- lista, onde andar por palavra não é gesto de ninguém.
    open_rev = "e",
    diff_rev = "E",
    -- "v" for "visto". The key is local to the panel's buffer, which is a
    -- list, not text to select in visual mode.
    toggle_seen = "v",
    -- "a" for "anotar", and the pair reads like the copy keys below: the plain
    -- key is the one-line remark, which is nearly every remark, and the shifted
    -- one opens the entry of several lines for when it is not.
    annotate = "a",
    annotate_long = "A",
    -- "R" for "relatório", beside the "r" that refreshes: the two are the
    -- panel's own keys, about the review and not about a line of it.
    report = "R",
    -- "c" for "commits", and the pair reads like the diff keys: the plain key
    -- is the graph built beside the panel, the shifted one the gitgraph's
    -- drawing of the same history, both switched on to be compared in use
    -- (ADR-0006). Not "g", which is a prefix — the panel is a list, and `gg`
    -- has to keep taking the reviewer to the top of it.
    graph = "c",
    graph_alternate = "C",
    -- "b" for "branch", and it is a key of the graph, not of the panel: the
    -- filter exists for the reviewer already looking at the history and finding
    -- too much of it. The panel's own keys are all about the list in front of
    -- it.
    branch = "b",
    -- "w" for "working tree", which is the mode it goes back to. Like "v" for
    -- visto, the key is local to a list, where moving by word is not a gesture
    -- anyone has.
    worktree = "w",
    -- The letters the git plugins already use for these, so the gesture is the
    -- one the reviewer's fingers know. Discarding is the shifted key: it is the
    -- one that loses work, and it does not sit next to the other two.
    stage = "s",
    unstage = "u",
    discard = "X",
    -- "y" for yank, and the pair reads like the one above it: the plain key is
    -- the short path, the shifted one the whole path. The relative path gets
    -- the plain key because it is the one that goes into a PR or a message.
    copy_relative_path = "y",
    copy_absolute_path = "Y",
  },
  merge_layouts = {
    conflict = "diff3_horizontal",
    conflict_with_base = "diff4_mixed",
  },
}

---@type ReviewConfig
M.options = vim.deepcopy(defaults)

---@param options ReviewConfig
local function validate(options)
  if options.position ~= "left" and options.position ~= "right" then
    error(('review: position must be "left" or "right", got %q'):format(tostring(options.position)))
  end
  if type(options.width) ~= "number" or options.width < 1 then
    error(("review: width must be a positive number, got %s"):format(tostring(options.width)))
  end
  if options.seen_display ~= "section" and options.seen_display ~= "dimmed" then
    error(('review: seen_display must be "section" or "dimmed", got %q'):format(tostring(options.seen_display)))
  end
  -- A typo here would be silent otherwise: any value that is not "close" reads
  -- as "ignore", so the panel would just quietly stop making room for itself.
  if options.neo_tree ~= "close" and options.neo_tree ~= "ignore" then
    error(('review: neo_tree must be "close" or "ignore", got %q'):format(tostring(options.neo_tree)))
  end
  -- Absent is the default — beside the review state. Anything else has to be a
  -- directory, and an absolute one: a relative path is resolved from the
  -- editor's current directory, which during a review is the repository being
  -- reviewed, and the report would land in the very list the panel is showing
  -- (ADR-0004).
  if options.report_directory ~= nil then
    if type(options.report_directory) ~= "string" or options.report_directory == "" then
      error(("review: report_directory must be a non-empty string, got %s"):format(tostring(options.report_directory)))
    end
    if not vim.startswith(options.report_directory, "/") then
      error(("review: report_directory must be an absolute path, got %q"):format(options.report_directory))
    end
  end
  for name, key in pairs(options.mappings) do
    if type(key) ~= "string" or key == "" then
      error(("review: mappings.%s must be a non-empty string, got %s"):format(name, tostring(key)))
    end
  end
  -- The names themselves are the diffview's to validate; what would be silent
  -- here is a value that is not a layout name at all.
  for name, layout in pairs(options.merge_layouts) do
    if type(layout) ~= "string" or layout == "" then
      error(("review: merge_layouts.%s must be a non-empty string, got %s"):format(name, tostring(layout)))
    end
  end
end

---Replace the options with the defaults overridden by `opts`.
---@param opts table|nil
---@return ReviewConfig
function M.setup(opts)
  local options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  -- The "~" of a path written by hand is the reviewer's shorthand for their
  -- home, and what the report writes into is the directory it stands for.
  if type(options.report_directory) == "string" then
    options.report_directory = vim.fs.normalize(options.report_directory)
  end
  validate(options)
  M.options = options
  return options
end

return M
