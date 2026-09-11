---What the panel is listing: the working tree, a commit, or a range of commits.
---
---There is one panel with a mode, not a panel per context (ADR-0001), so the
---mode is a value that travels: the annotations are written in one, the report
---is of one, and the counts on the panel's lines are of one. It is passed
---around instead of assumed, which is what keeps a remark written about a
---commit out of the review of the working tree.
---
---The key is what goes into the state document and into the report's file
---name. The revs are what the report tells the agent was reviewed.
local M = {}

---@class ReviewMode the review a moment belongs to
---@field key string as it is written in the state document
---@field rev string|nil the commit under review — the newest of a range;
---absent in the working tree
---@field oldest string|nil the commit a range starts at; absent otherwise

---@type ReviewMode
M.WORKTREE = { key = "worktree" }

---The mode a reading of the repository puts the panel in.
---
---The whole object name in the key, and not the short one git prints: the key
---is what the annotations of this commit are filed under, and an abbreviation
---is only unambiguous in the repository as it stands today. A range is filed
---under both of its ends, because a range is what it covers: the same commit
---reviewed alone and reviewed as the end of a feature are two readings, and the
---remarks of one are not remarks of the other.
---@param status ReviewStatus|nil nil when the repository could not be read
---@return ReviewMode
function M.of(status)
  if not status or not status.rev then return M.WORKTREE end
  if status.range then
    return {
      key = ("range-%s..%s"):format(status.range.oldest, status.range.newest),
      rev = status.rev,
      oldest = status.range.oldest,
    }
  end
  return { key = "commit-" .. status.rev, rev = status.rev }
end

return M
