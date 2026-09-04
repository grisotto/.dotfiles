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

---@alias ReviewSection "conflicts"|"staged"|"unstaged"|"untracked"|"commit"

---@class ReviewEntry
---@field section ReviewSection
---@field status string one letter, or the two-letter code of a conflict
---@field path string path relative to the repository root
---@field orig_path string|nil the path a renamed file came from
---@field content string|nil key of the content this entry puts under review
---@field rev string|nil rev the change is read from; absent in the working tree
---@field base string|nil rev it is read against; absent in the working tree
---@field added integer|nil lines the change puts in; absent where there are
---none to count — an untracked file, a conflict, a binary file
---@field removed integer|nil lines the change takes out

---@class ReviewStatus
---@field root string absolute path of the repository root
---@field title string what the panel says it is listing: the branch, the commit,
---or the range
---@field rev string|nil the commit being listed — the newest of a range;
---absent in the working tree
---@field range { oldest: string, newest: string }|nil the two ends of the range
---being listed, when what is listed is one
---@field has_commits boolean false in a repository where nothing was committed
---@field entries ReviewEntry[]
---@field added integer lines put in by everything on the list
---@field removed integer lines taken out by everything on the list
---@field author string|nil who wrote the commit being listed; absent in the
---working tree and in a range, which has as many authors as it has commits
---@field date string|nil the day that commit was written, as `YYYY-MM-DD`
---@field commits integer|nil how many commits a range holds; absent otherwise

---@alias ReviewGitFailure "not_a_repo"|"git_failed"|"no_such_rev"

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

---Whether a record carries no object where an object name would be — the index
---side of a staged deletion, for one. Git writes it as an object name of all
---zeroes, as long as object names are in this repository: the length is the
---hash's, not a constant, and a repository on SHA-256 writes sixty-four of
---them.
---@param name string
---@return boolean
local function is_no_object(name) return name:match "^0+$" ~= nil end

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
      content = not is_no_object(index) and index or removal_of(head),
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

---@class ReviewNumbers how many lines a change puts in and takes out
---@field added integer
---@field removed integer

---Read one `--numstat -z` record, which is `add`, `del` and the path, tabs
---between them.
---
---A rename writes no path in the record itself: the old one and the new one
---come in the two fields after it, and have to be consumed as part of it — read
---as records of their own, they corrupt everything that follows. It is the same
---shape the rename record of `porcelain=v2` has, and for the same reason.
---
---A binary file has no lines to count, and git writes `-` in both columns: it
---goes without numbers, which is what it has.
---@param numbers table<string, ReviewNumbers> the record is written into it,
---which is what makes this the same call wherever numstat records show up
---@param fields string[] the NUL-separated output, split
---@param index integer where the record starts
---@return integer next where the record after this one starts
local function read_numstat(numbers, fields, index)
  local added, removed, path = fields[index]:match "^([%d-]+)\t([%d-]+)\t(.*)$"
  index = index + 1
  if not added then return index end
  if path == "" then
    path = fields[index + 1]
    index = index + 2
  end
  if not path or path == "" or added == "-" then return index end
  numbers[path] = { added = tonumber(added) or 0, removed = tonumber(removed) or 0 }
  return index
end

---Read `git diff --numstat -z` into the numbers of each path it names.
---@param output string
---@return table<string, ReviewNumbers>
local function parse_numstat(output)
  local fields = vim.split(output, "\0", { plain = true })
  local numbers = {}

  local index = 1
  while index <= #fields do
    index = read_numstat(numbers, fields, index)
  end

  return numbers
end

---How much the whole list adds and removes, which is what the panel writes in
---its header. Counted over the entries and not over the files: a file changed
---in the index and changed again on disk is two changes to read, and the header
---counts changes the same way the sections do.
---@param entries ReviewEntry[]
---@return integer added
---@return integer removed
local function totals(entries)
  local added, removed = 0, 0
  for _, entry in ipairs(entries) do
    added = added + (entry.added or 0)
    removed = removed + (entry.removed or 0)
  end
  return added, removed
end

---Give each entry of a section the numbers git counted for its path.
---
---By section, because the two sides of the index are two different diffs: what
---`--cached` counts is HEAD against the index, and what the plain call counts is
---the index against the disk. Untracked files and conflicts are left out
---altogether: counting the lines of an untracked file would cost a process per
---file, and a conflict has no two sides to compare.
---@param entries ReviewEntry[]
---@param section ReviewSection
---@param numbers table<string, ReviewNumbers>
local function count_lines(entries, section, numbers)
  for _, entry in ipairs(entries) do
    local found = entry.section == section and numbers[entry.path] or nil
    if found then
      entry.added, entry.removed = found.added, found.removed
    end
  end
end

---Split one record of `git diff-tree -r -z --raw` into the entry it produces.
---
---The raw format is the one that names the objects on both sides, which is
---what makes a commit readable without hashing anything: the object on the
---right *is* the content this entry puts under review, so the mark left on it
---is the same mark the working tree gets for the same text (ADR-0002). The
---name-status format would have cost one `hash-object` per file to arrive at
---the same keys.
---@param entries ReviewEntry[]
---@param before string object name on the left, all zeroes when the file is new
---@param after string object name on the right, all zeroes when it is gone
---@param status string the letter, with the score a rename carries
---@param path string
---@param orig_path string|nil
---@param rev string the commit being read — the newest end, in a range
---@param base string the rev it is being read against
local function add_committed(entries, before, after, status, path, orig_path, rev, base)
  entries[#entries + 1] = {
    section = "commit",
    -- Short of the score: `R100` in the column the other sections fill with one
    -- letter would push every path of the list one column to the right.
    status = status:sub(1, 1),
    path = path,
    orig_path = orig_path,
    content = not is_no_object(after) and after or removal_of(before),
    rev = rev,
    base = base,
  }
end

---Read what `git diff-tree -r -z --raw --numstat` wrote: the raw records first,
---which is what names the objects, and the numstat records after them, which is
---what counts the lines. Two formats out of one process, so a commit still
---costs the panel exactly the two it always cost.
---@param output string the NUL-separated output
---@param rev string the commit it was read from — the newest end, in a range
---@param base string the rev it was read against
---@return ReviewEntry[]
local function parse_commit(output, rev, base)
  local fields = vim.split(output, "\0", { plain = true })
  local entries, numbers = {}, {}

  local index = 1
  while index <= #fields do
    local field = fields[index]
    -- `:<mode before> <mode after> <object before> <object after> <status>`,
    -- with the paths in the fields that follow.
    local before, after, status = field:match "^:%S+ %S+ (%S+) (%S+) (%S+)$"
    if status then
      index = index + 1
      local path = fields[index]
      index = index + 1
      -- A rename and a copy name two paths, the old one first. Consumed as
      -- part of the record it belongs to, the way the rename record of the
      -- status is: read as a record of its own it would render a broken line.
      local orig_path = nil
      local kind = status:sub(1, 1)
      if kind == "R" or kind == "C" then
        orig_path, path = path, fields[index]
        index = index + 1
      end
      if path then add_committed(entries, before, after, status, path, orig_path, rev, base) end
    else
      index = read_numstat(numbers, fields, index)
    end
  end

  count_lines(entries, "commit", numbers)
  return entries
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

---Where the repository containing `cwd` begins.
---@param cwd string absolute path of a directory
---@return string|nil root nil when `cwd` is not inside a repository
function M.root(cwd)
  local result = git({ "rev-parse", "--show-toplevel" }, cwd)
  if result.code ~= 0 then return nil end
  return vim.trim(result.stdout or "")
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

---Count the lines of one side of the index. `-z` for the same reason the status
---is read with it: the paths come exactly as they are on disk.
---@param cwd string
---@param section "staged"|"unstaged" which side is being counted: the index
---against HEAD, or the disk against the index
---@return string output empty when git could not be read, which is a side with
---no numbers rather than a panel that does not open
local function numstat(cwd, section)
  local args = { "diff", "--numstat", "-z" }
  if section == "staged" then args[#args + 1] = "--cached" end
  local result = git(args, cwd)
  if result.code ~= 0 then return "" end
  return result.stdout or ""
end

---Read the state of the repository containing `cwd`.
---@param cwd string
---@return ReviewStatus|nil status
---@return ReviewGitFailure|nil failure
---@return string|nil detail git's own error message
function M.status(cwd)
  local root = M.root(cwd)
  if not root then return nil, "not_a_repo" end

  -- `--branch` is what carries the branch name and whether HEAD exists yet, so
  -- nothing here has to ask for HEAD and fail in a repository without commits.
  --
  -- `--untracked-files=all` because git's default collapses a new directory
  -- into a single `src/` line: it would make the section count files it is not
  -- counting, and put a line in the panel that is not a file to open.
  local result = git({ "status", "--porcelain=v2", "-z", "--branch", "--untracked-files=all" }, cwd)
  if result.code ~= 0 then return nil, "git_failed", vim.trim(result.stderr or "") end

  local parsed = parse(result.stdout or "")
  identify(root, parsed.entries)

  -- One process per side of the index, because they are two different diffs.
  -- Both are asked for even when nothing is staged: what they cost is a process
  -- that answers nothing, and what telling beforehand would cost is a walk of
  -- the entries to find out.
  for _, section in ipairs { "staged", "unstaged" } do
    count_lines(parsed.entries, section, parse_numstat(numstat(cwd, section)))
  end

  local added, removed = totals(parsed.entries)
  return {
    root = root,
    title = parsed.branch,
    has_commits = parsed.has_commits,
    entries = parsed.entries,
    added = added,
    removed = removed,
  }
end

---Read the files of one commit, the way the panel lists them in commit mode.
---
---Two processes, whatever the commit has in it: one for what identifies the
---commit and one for its files. The second is `diff-tree` and not `show`
---because only the raw format names the objects, and those are the keys the
---marks are left under.
---
---What a merge shows is what it brought in against its first parent, which is
---what there is to review in one — `diff-tree` left alone says a merge changed
---nothing at all, and a panel that answered "Nenhuma mudança" for every merge
---of the graph would look broken. `--diff-merges=first-parent` and not
---`-m --first-parent`: the second is a limit on which commits are walked, not
---on which parent the merge is compared against, and it lists the change twice
---— once against each parent — in a commit that has two.
---@param root string absolute path of the repository root
---@param rev string anything git resolves to a commit
---@return ReviewStatus|nil status
---@return ReviewGitFailure|nil failure
---@return string|nil detail git's own error message
function M.commit_status(root, rev)
  -- The author and the day, beside what identifies the commit: whoever is
  -- reading someone else's commit has to know whose it is and from when, and
  -- that is what the panel writes in the line under its header. In the same
  -- process that was already being run — it is one more field of the format.
  local described = git({ "show", "--no-patch", "--date=short", "--format=%H%x00%h%x00%an%x00%ad%x00%s", rev }, root)
  if described.code ~= 0 then return nil, "no_such_rev", vim.trim(described.stderr or "") end
  local sha, short, author, date, subject = unpack(vim.split(vim.trim(described.stdout or ""), "\0", { plain = true }))
  if not sha or sha == "" then return nil, "no_such_rev" end

  -- `--root` so the first commit of the repository lists what it added instead
  -- of nothing: it has no parent to be diffed against, and that is exactly the
  -- commit a reviewer opens the graph at the bottom to read.
  -- `--raw` written out, and not left to be the default: `--numstat` on its own
  -- replaces the default format, and what would be lost is the object names —
  -- which are the keys the marks are left under.
  local listed = git({
    "diff-tree",
    "-r",
    "-z",
    "--no-abbrev",
    "--no-commit-id",
    "--find-renames",
    "--root",
    "--diff-merges=first-parent",
    "--raw",
    "--numstat",
    sha,
  }, root)
  if listed.code ~= 0 then return nil, "git_failed", vim.trim(listed.stderr or "") end

  -- What the commit is read against is what it changed: its first parent. A
  -- commit that has none — the first of the repository — leaves this rev
  -- unresolvable, which is an empty left side and not a failure.
  local entries = parse_commit(listed.stdout or "", sha, sha .. "^")
  local added, removed = totals(entries)
  return {
    root = root,
    title = ("%s %s"):format(short, subject),
    rev = sha,
    has_commits = true,
    entries = entries,
    added = added,
    removed = removed,
    author = author,
    date = date,
  }
end

---The object name of the empty tree, which is what a range that reaches the
---first commit of the repository starts from: that commit has no parent to be
---compared against, and comparing against nothing is comparing against the
---tree with nothing in it. Asked of git rather than written here as a constant,
---because it is the hash of this repository — forty hex digits on SHA-1,
---sixty-four on SHA-256 — and nothing is written to the object database to
---answer it.
---@param root string
---@return string|nil
local function empty_tree(root)
  local result = git({ "hash-object", "-t", "tree", "/dev/null" }, root)
  if result.code ~= 0 then return nil end
  return vim.trim(result.stdout or "")
end

---Whether one commit is on the way to the other, which is what makes two
---commits the ends of a range at all.
---
---The graph draws every branch, so two lines next to each other on screen are
---not necessarily on the same line of history: the commits of a branch and the
---ones of another are drawn side by side. Comparing two divergent tips answers
---with everything that differs between the branches, which is not the range
---anybody meant to select.
---
---Asked of git on the gesture and not on every draw, the same way the panel
---asks whether the repository has a HEAD before it offers to restore from it.
---@param root string absolute path of the repository root
---@param oldest string
---@param newest string
---@return boolean
function M.is_ancestor(root, oldest, newest)
  return git({ "merge-base", "--is-ancestor", oldest, newest }, root).code == 0
end

---Read the files of a range of commits, the way the panel lists them when the
---reviewer selected more than one line of the graph.
---
---What a range shows is its net change: the two trees at the ends compared
---directly, which is what `A..B` means in git and what reviewing a whole
---feature at once asks for. A file created inside the range and gone by the end
---of it is not in the list, because there is nothing left in it to read.
---
---That also settles the merges the range walks over: a comparison of two trees
---has no commit in it to have parents, so nothing has to be said about which
---parent a merge is read against.
---@param root string absolute path of the repository root
---@param oldest string the commit the range starts at, itself included
---@param newest string the commit it ends at
---@return ReviewStatus|nil status
---@return ReviewGitFailure|nil failure
---@return string|nil detail git's own error message
function M.range_status(root, oldest, newest)
  -- One process for both ends: `show` writes a record per rev it is given.
  local described = git({ "show", "--no-patch", "--format=%H%x00%h", oldest, newest }, root)
  if described.code ~= 0 then return nil, "no_such_rev", vim.trim(described.stderr or "") end
  local records = vim.split(vim.trim(described.stdout or ""), "\n", { plain = true })
  local from = vim.split(records[1] or "", "\0", { plain = true })
  -- A range of one rev is described once: both ends are the same commit.
  local to = vim.split(records[2] or records[1] or "", "\0", { plain = true })
  if not from[1] or from[1] == "" or not to[1] or to[1] == "" then return nil, "no_such_rev" end

  -- The range starts before its oldest commit, so that commit's own change is
  -- part of what is being reviewed.
  local base = from[1] .. "^"
  -- How many commits the range holds, which is what says a whole feature is on
  -- the list. It is also what asks git whether the range has a beginning at
  -- all: a `^` that does not resolve fails the count, and saves this from
  -- having to ask about the parent in a process of its own.
  local starts_at = base
  local counted = git({ "rev-list", "--count", ("%s..%s"):format(base, to[1]) }, root)
  if counted.code ~= 0 then
    -- The oldest commit of the range is the first of the repository, and there
    -- is nothing before it for the range to start at.
    starts_at = empty_tree(root)
    counted = git({ "rev-list", "--count", to[1] }, root)
  end
  if not starts_at or counted.code ~= 0 then return nil, "git_failed", vim.trim(counted.stderr or "") end
  local commits = tonumber(vim.trim(counted.stdout or "")) or 0

  local listed =
    git({ "diff-tree", "-r", "-z", "--no-abbrev", "--find-renames", "--raw", "--numstat", starts_at, to[1] }, root)
  if listed.code ~= 0 then return nil, "git_failed", vim.trim(listed.stderr or "") end

  -- Read against the parent of the oldest commit, and not against the tree
  -- the comparison used: the empty tree is how git is asked for "everything
  -- there is", and `<sha>^` is what the reviewer reads on the side of the
  -- diff — the same unresolvable rev a first commit shows, and the same empty
  -- side.
  local entries = parse_commit(listed.stdout or "", to[1], base)
  local added, removed = totals(entries)
  return {
    root = root,
    -- Written the way git would be given it, `^` included: `a..b` excludes `a`
    -- to anyone who reads git, and this range does not — the oldest commit is
    -- part of what is being reviewed. It is also the rev the left side of every
    -- diff of this range is named after, so the header and the buffer beside it
    -- say the same thing.
    title = ("%s^..%s · %d %s"):format(from[2], to[2], commits, commits == 1 and "commit" or "commits"),
    rev = to[1],
    range = { oldest = from[1], newest = to[1] },
    has_commits = true,
    entries = entries,
    added = added,
    removed = removed,
    commits = commits,
  }
end

---The branches the graph can be restricted to, most recently worked on first,
---which is the order a reviewer looks for one in.
---
---The remote ones too: the branch a reviewer goes looking for is often someone
---else's, and it is in the repository already. What is left out is the pointer
---git keeps to a remote's default branch — `refs/remotes/origin/HEAD` is not a
---branch to review, it is the name of another one.
---
---Which is why the whole ref name is read beside the short one: git shortens
---that pointer to `origin`, with no `HEAD` left in it to recognise it by, and a
---search offering "origin" would be offering a branch that does not exist under
---that name.
---@param root string absolute path of the repository root
---@return string[]|nil branches nil when git could not be read
function M.branches(root)
  local result = git({
    "branch",
    "--all",
    "--format=%(refname)%00%(refname:short)",
    "--sort=-committerdate",
  }, root)
  if result.code ~= 0 then return nil end

  local branches = {}
  for _, line in ipairs(vim.split(vim.trim(result.stdout or ""), "\n", { plain = true })) do
    local ref, name = unpack(vim.split(line, "\0", { plain = true }))
    if name and name ~= "" and not vim.endswith(ref, "/HEAD") then branches[#branches + 1] = name end
  end
  return branches
end

---@class ReviewRevChoice one rev the search offers
---@field label string as the reviewer reads it in the list
---@field rev string as git is given it

---The revs one file can be read at: the branches of the repository, and the
---commits that touched that file, newest first.
---
---The branches come first because they are few and always the same, and a
---search that buried them under the history of the file would be a search
---where they cannot be reached at all. What identifies a commit in the list is
---the short sha, the date and the subject — the same fields the graph draws —
---so that nobody has to type a sha.
---
---A renamed file is asked for under both of its names: its history is under the
---old one up to the rename, and a search offering nothing at all — which is
---what the new name alone answers for a rename that is not committed yet — is
---the one answer that is certainly wrong.
---
---A `git log` that fails is a file with no commits behind it — an untracked
---one, or a repository where nothing was ever committed — and the branches
---alone are still an answer. What is not an answer is a repository git could
---not be read from at all, which is what nil means here.
---@param root string absolute path of the repository root
---@param entry ReviewEntry the file the search is about
---@param limit integer how many commits of the file to read at most
---@return ReviewRevChoice[]|nil choices nil when git could not be read
function M.revs_of(root, entry, limit)
  local branches = M.branches(root)
  if not branches then return nil end

  local choices = {}
  for _, branch in ipairs(branches) do
    choices[#choices + 1] = { label = branch, rev = branch }
  end

  -- Nothing after the separator but the paths, so a file whose name is also a
  -- rev is read as the path it is.
  local args = {
    "log",
    "--date=short",
    "--format=%H%x00%h%x00%ad%x00%s",
    "--max-count=" .. limit,
    "--",
    entry.path,
  }
  if entry.orig_path then args[#args + 1] = entry.orig_path end

  local result = git(args, root)
  if result.code ~= 0 then return choices end

  for _, line in ipairs(vim.split(vim.trim(result.stdout or ""), "\n", { plain = true })) do
    local sha, short, date, subject = unpack(vim.split(line, "\0", { plain = true }))
    if sha and sha ~= "" then
      choices[#choices + 1] = { label = ("%s %s %s"):format(short, date, subject), rev = sha }
    end
  end
  return choices
end

---@class ReviewLogEntry one line of the graph
---@field sha string|nil the full object name; absent on a line that only draws
---@field graph string the lines and corners git drew, which is the line itself
---when there is no commit on it
---@field short string|nil
---@field date string|nil
---@field refs string|nil the branches and tags pointing here, empty when none
---@field subject string|nil

---Read the commits of the repository as a graph, newest first.
---
---Bounded, because this is read into a buffer in one go and a repository with
---a hundred thousand commits would freeze the editor for as long as git takes
---to walk it — the same reason the calls here have a timeout at all. What the
---bound cuts off is the oldest end, which is not where a reviewer is looking.
---@param root string absolute path of the repository root
---@param opts { branch: string|nil, limit: integer } `branch` walks that one
---alone, which is what the filter is made of; without it, every branch is
---walked
---@return ReviewLogEntry[]|nil entries nil when git could not be read
function M.log(root, opts)
  local args = { "log", "--graph", "--date=short", "--format=%H%x00%h%x00%ad%x00%d%x00%s" }
  args[#args + 1] = opts.branch or "--all"
  args[#args + 1] = "--max-count=" .. opts.limit
  -- Nothing after the separator, so a branch whose name is also a path in the
  -- repository is read as the rev it is, instead of git refusing an argument it
  -- cannot tell apart.
  args[#args + 1] = "--"

  local result = git(args, root)
  if result.code ~= 0 then return nil end

  local entries = {}
  for _, line in ipairs(vim.split(result.stdout or "", "\n", { plain = true })) do
    local fields = vim.split(line, "\0", { plain = true })
    -- The lines git draws between two commits carry no commit of their own,
    -- and the object name is what tells them apart: it is the first thing the
    -- format writes, so what ends in one is a line to select and what does not
    -- is a line that only draws. Read as the run of hex the line ends with,
    -- and not as its last forty characters: nothing git draws — `*`, `|`, `/`,
    -- `\`, `_`, a space — is a hex digit, and the name is as long as this
    -- repository's hash, which on SHA-256 is sixty-four.
    local graph, sha = fields[1]:match "^(.-)(%x+)$"
    if #fields > 1 and sha then
      entries[#entries + 1] = {
        sha = sha,
        graph = graph,
        short = fields[2] or "",
        date = fields[3] or "",
        refs = fields[4] or "",
        subject = fields[5] or "",
      }
    elseif line ~= "" then
      entries[#entries + 1] = { graph = line }
    end
  end

  return entries
end

return M
