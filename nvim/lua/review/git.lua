---Talking to the repository.
---
---Wraps the calls to git: the read that fills the panel, and the three
---commands that change what it is listing (ADR-0005). Translates
---`git status --porcelain=v2 -z` into panel entries. One git record can become
---two entries: a file with both a staged and an unstaged change is two
---different changes to review, so it is listed in both sections.
---
---Rename records carry the old path in a field of their own. It has to be
---consumed as such — a parser that treats it as the next record renders a
---broken line — and only the new path is ever shown.
local M = {}

---@alias ReviewSection "conflicts"|"staged"|"unstaged"|"untracked"

---@class ReviewEntry
---@field section ReviewSection
---@field status string one letter, or the two-letter code of a conflict
---@field path string path relative to the repository root
---@field orig_path string|nil the path a renamed file came from
---@field content string|nil key of the content this entry puts under review

---@class ReviewStatus
---@field root string absolute path of the repository root
---@field branch string current branch, or "(detached)"
---@field has_commits boolean false in a repository where nothing was committed
---@field entries ReviewEntry[]

---@alias ReviewGitFailure "not_a_repo"|"git_failed"

---How long the editor is willing to sit blocked on git. Reading the status is
---synchronous, so without a bound a repository with a huge untracked tree —
---which `--untracked-files=all` walks in full — would freeze the editor with
---no way out. On timeout the call comes back non-zero and the panel says it
---could not read the state, which is recoverable; a frozen editor is not.
local TIMEOUT_MS = 10000

---@param args string[]
---@param cwd string
---@return vim.SystemCompleted
local function git(args, cwd) return vim.system(vim.list_extend({ "git" }, args), { cwd = cwd }):wait(TIMEOUT_MS) end

---What a record carries where an object name would be, when there is no object
---— the index side of a staged deletion, for one.
local NO_OBJECT = ("0"):rep(40)

---The key of a deletion. It cannot be the content of the file, because there
---is none; it is the identity of what was removed, so that the same removal
---seen once is not offered again, and two different removals never share a key.
---@param removed string object name of what is gone
---@return string
local function removal_of(removed) return "removed:" .. removed end

---Split a changed record into the entries it produces.
---
---What each side puts under review is what its diff shows on the right: the
---index blob for a staged change, the file on disk for an unstaged one. Git
---already named the first in the record, so only the second is left to hash.
---@param entries ReviewEntry[]
---@param xy string the two-letter code: index status then worktree status
---@param head string object name in HEAD
---@param index string object name in the index
---@param path string
---@param orig_path string|nil
local function add_changed(entries, xy, head, index, path, orig_path)
  local index_status, worktree_status = xy:sub(1, 1), xy:sub(2, 2)
  if index_status ~= "." then
    entries[#entries + 1] = {
      section = "staged",
      status = index_status,
      path = path,
      orig_path = orig_path,
      content = index ~= NO_OBJECT and index or removal_of(head),
    }
  end
  if worktree_status ~= "." then
    entries[#entries + 1] = {
      section = "unstaged",
      status = worktree_status,
      path = path,
      orig_path = orig_path,
      -- A file deleted from the working tree has nothing on disk to hash.
      content = worktree_status == "D" and removal_of(index) or nil,
    }
  end
end

---@param output string the NUL-separated output of `git status --porcelain=v2 -z`
---@return { branch: string, has_commits: boolean, entries: ReviewEntry[] }
local function parse(output)
  local fields = vim.split(output, "\0", { plain = true })
  local branch, has_commits, entries = "(desconhecida)", true, {}

  local index = 1
  while index <= #fields do
    local field = fields[index]
    index = index + 1
    local kind = field:sub(1, 2)

    if field:sub(1, 1) == "#" then
      local key, value = field:match "^# (%S+) (.*)$"
      if key == "branch.head" then
        branch = value
      elseif key == "branch.oid" then
        has_commits = value ~= "(initial)"
      end
    elseif kind == "1 " then
      local xy, head, staged, path = field:match "^1 (%S+) %S+ %S+ %S+ %S+ (%S+) (%S+) (.*)$"
      if xy then add_changed(entries, xy, head, staged, path, nil) end
    elseif kind == "2 " then
      -- A rename record is followed by its original path in the next field.
      -- Consume it unconditionally, so a record we failed to match cannot
      -- leave the original path behind to be read as a record of its own.
      local orig_path = fields[index]
      index = index + 1
      local xy, head, staged, path = field:match "^2 (%S+) %S+ %S+ %S+ %S+ (%S+) (%S+) %S+ (.*)$"
      if xy then add_changed(entries, xy, head, staged, path, orig_path) end
    elseif kind == "u " then
      local xy, path = field:match "^u (%S+) %S+ %S+ %S+ %S+ %S+ %S+ %S+ %S+ (.*)$"
      if xy then entries[#entries + 1] = { section = "conflicts", status = xy, path = path } end
    elseif kind == "? " then
      entries[#entries + 1] = { section = "untracked", status = "?", path = field:sub(3) }
    end
    -- "! " records are files git is ignoring; the panel never lists them.
  end

  return { branch = branch, has_commits = has_commits, entries = entries }
end

---Identify the content of the entries git left unidentified: the ones under
---review as the file on disk — an unstaged change, an untracked file, a
---conflict. All of them in a single process, because this runs on every draw
---and a process per file is what makes a panel of a hundred files slow.
---Whatever the index or HEAD already named is not hashed again.
---
---A path git cannot read aborts the run, so the hashes that did come out are
---taken in order and the entries after the offending path simply stay
---unidentified: they cannot be marked as seen, which is better than no file in
---the panel being markable because one of them is a submodule.
---@param root string
---@param entries ReviewEntry[]
local function identify(root, entries)
  local paths, position, pending = {}, {}, {}
  for _, entry in ipairs(entries) do
    if not entry.content then
      if not position[entry.path] then
        paths[#paths + 1] = entry.path
        position[entry.path] = #paths
      end
      pending[#pending + 1] = entry
    end
  end
  if #paths == 0 then return end

  local result = git(vim.list_extend({ "hash-object", "--" }, paths), root)
  local hashes = vim.split(vim.trim(result.stdout or ""), "\n", { plain = true })
  for _, entry in ipairs(pending) do
    local hash = hashes[position[entry.path]]
    if hash and hash ~= "" then entry.content = hash end
  end
end

---Read a path as it is in a rev: `HEAD` for the last commit, `:0` for the
---index. A rev that does not have the path — a file only just added, or
---already deleted — is not a failure to report: it is an empty side of a diff.
---@param root string absolute path of the repository root
---@param rev string anything git accepts before the colon in `rev:path`
---@param path string relative to the repository root
---@return string[]|nil lines nil when that rev has no such path
function M.show(root, rev, path)
  local result = git({ "show", ("%s:%s"):format(rev, path) }, root)
  if result.code ~= 0 then return nil end
  -- git ends the blob with its own newline; splitting on it would hand the
  -- buffer one line more than the file has.
  local content = (result.stdout or ""):gsub("\n$", "")
  return vim.split(content, "\n", { plain = true })
end

---Every path a command about this entry has to name.
---
---A rename is two paths in the index — the new one added, the old one deleted
---— and a command that names only the new one leaves the deletion of the old
---one behind it. On the working tree side the old path is gone from the index
---already, and naming it there is a pathspec git refuses, taking the whole
---command down with it.
---@param entry ReviewEntry
---@return string[]
local function paths_of(entry)
  if entry.section == "staged" and entry.orig_path then return { entry.path, entry.orig_path } end
  return { entry.path }
end

---Run a command against the paths of one entry.
---@param command string[]
---@param root string absolute path of the repository root
---@param entry ReviewEntry
---@return boolean ok
---@return string|nil detail git's own error message
local function run_on(command, root, entry)
  local args = vim.list_extend({}, command)
  args[#args + 1] = "--"
  local result = git(vim.list_extend(args, paths_of(entry)), root)
  if result.code ~= 0 then return false, vim.trim(result.stderr or "") end
  return true
end

---Whether the repository has a commit to restore from. Asked of git instead of
---carried down from the status the panel already read: this is one process on a
---key the reviewer presses once in a while and answers a question about before,
---not something every draw pays for.
---@param root string
---@return boolean
local function has_head(root) return git({ "rev-parse", "--verify", "--quiet", "HEAD" }, root).code == 0 end

---Move what the entry stands for into the index. On an untracked file that is
---the file itself; on a deleted one, its deletion.
---@param root string absolute path of the repository root
---@param entry ReviewEntry
---@return boolean ok
---@return string|nil detail
function M.stage(root, entry) return run_on({ "add" }, root, entry) end

---Take what the entry stands for out of the index, leaving the working tree
---as it is. `reset` and not `restore --staged`, because a repository without
---commits has no HEAD for the latter to resolve.
---@param root string absolute path of the repository root
---@param entry ReviewEntry
---@return boolean ok
---@return string|nil detail
function M.unstage(root, entry) return run_on({ "reset", "--quiet" }, root, entry) end

---Throw the change away. What that means is what the entry's own section says:
---an untracked file goes from the disk, an unstaged change goes back to what
---the index has, and a staged change goes back to what HEAD has — in the index
---and on disk at once, because putting only the index back is what `unstage`
---already does.
---
---A conflict never reaches here: picking a side is resolution, and resolution
---is the merge tool's (ADR-0005, ADR-0007).
---@param root string absolute path of the repository root
---@param entry ReviewEntry
---@return boolean ok
---@return string|nil detail
function M.discard(root, entry)
  if entry.section == "untracked" then return run_on({ "clean", "--force", "--quiet" }, root, entry) end
  if entry.section == "unstaged" then return run_on({ "restore" }, root, entry) end
  -- Named rather than left as the last case: what each section means is decided
  -- twice — here and in the question asked before this runs — and a section
  -- that gained a question but no command here would silently get this one.
  if entry.section ~= "staged" then return false, ("não há o que descartar em %s"):format(entry.section) end
  if has_head(root) then return run_on({ "restore", "--staged", "--worktree", "--source=HEAD" }, root, entry) end
  -- No commit to restore from: everything staged here is a file the repository
  -- has never had, and the change goes away with the file.
  return run_on({ "rm", "--force", "--quiet" }, root, entry)
end

---Read the state of the repository containing `cwd`.
---@param cwd string
---@return ReviewStatus|nil status
---@return ReviewGitFailure|nil failure
---@return string|nil detail git's own error message
function M.status(cwd)
  local toplevel = git({ "rev-parse", "--show-toplevel" }, cwd)
  if toplevel.code ~= 0 then return nil, "not_a_repo" end

  -- `--branch` is what carries the branch name and whether HEAD exists yet, so
  -- nothing here has to ask for HEAD and fail in a repository without commits.
  --
  -- `--untracked-files=all` because git's default collapses a new directory
  -- into a single `src/` line: it would make the section count files it is not
  -- counting, and put a line in the panel that is not a file to open.
  local result = git({ "status", "--porcelain=v2", "-z", "--branch", "--untracked-files=all" }, cwd)
  if result.code ~= 0 then return nil, "git_failed", vim.trim(result.stderr or "") end

  local parsed = parse(result.stdout or "")
  local root = vim.trim(toplevel.stdout or "")
  identify(root, parsed.entries)
  return {
    root = root,
    branch = parsed.branch,
    has_commits = parsed.has_commits,
    entries = parsed.entries,
  }
end

return M
