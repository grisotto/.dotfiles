---Options of the review panel.
---
---Only presentation and coexistence choices live here. What is data model
---rather than preference — the panel being single with a mode, the boundary
---with neogit — is deliberately not exposed.
local M = {}

---@class ReviewMappings
---@field close string key that closes the panel from inside it
---@field refresh string key that re-reads git and re-renders
---@field diff string key that opens what the line represents
---@field diff_alternate string key that opens the same thing the other way
---@field open string key that opens the file in the window beside the panel
---@field open_split string key that opens the file in a split
---@field toggle_seen string key that marks the file on the line as seen, or unmarks it
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
---@field mappings ReviewMappings
---@field merge_layouts ReviewMergeLayouts
local defaults = {
  position = "left",
  width = 40,
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
    open = "o",
    open_split = "O",
    -- "v" for "visto". The key is local to the panel's buffer, which is a
    -- list, not text to select in visual mode.
    toggle_seen = "v",
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
  validate(options)
  M.options = options
  return options
end

return M
