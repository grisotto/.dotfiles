-- Temporary git repositories for the headless suite.
--
-- Every scenario the spec asks for is built by running real `git` against a
-- real directory: only staged, only unstaged, both at once, untracked,
-- renamed, deleted, conflicted, a repository with no commits, and a directory
-- that is not a repository at all.

local M = {}

---Directories created by this module, removed by `M.cleanup`.
---@type string[]
local created = {}

---Git environment that ignores the machine's own git configuration, so a
---developer's `init.defaultBranch` or signing setup cannot change a result.
local GIT_ENV = {
  GIT_CONFIG_GLOBAL = "/dev/null",
  GIT_CONFIG_SYSTEM = "/dev/null",
  GIT_AUTHOR_NAME = "Fixture",
  GIT_AUTHOR_EMAIL = "fixture@example.com",
  GIT_COMMITTER_NAME = "Fixture",
  GIT_COMMITTER_EMAIL = "fixture@example.com",
  GIT_AUTHOR_DATE = "2026-01-01T00:00:00+00:00",
  GIT_COMMITTER_DATE = "2026-01-01T00:00:00+00:00",
}

---@param prefix string
---@return string dir
local function tempdir(prefix)
  local dir = vim.fn.tempname() .. "-" .. prefix
  assert(vim.fn.mkdir(dir, "p") == 1, "could not create " .. dir)
  created[#created + 1] = dir
  return dir
end

---@class FixtureRepo
---@field root string absolute path to the repository (or plain directory)
local Repo = {}
Repo.__index = Repo

---Run git in the repository, asserting success.
---@param args string[]
---@return string stdout
function Repo:git(args)
  local result = self:try_git(args)
  assert(
    result.code == 0,
    ("git %s failed (%d):\n%s%s"):format(table.concat(args, " "), result.code, result.stdout or "", result.stderr or "")
  )
  return result.stdout or ""
end

---Run git in the repository, tolerating failure (a conflicting merge exits 1).
---@param args string[]
---@return vim.SystemCompleted
function Repo:try_git(args)
  local cmd = vim.list_extend({ "git" }, args)
  return vim.system(cmd, { cwd = self.root, env = GIT_ENV, text = true }):wait()
end

---@param path string relative to the repository root
---@param content string
function Repo:write(path, content)
  local absolute = self.root .. "/" .. path
  vim.fn.mkdir(vim.fn.fnamemodify(absolute, ":h"), "p")
  local handle = assert(io.open(absolute, "w"))
  handle:write(content)
  handle:close()
end

---What is on disk under `path`, which is how an action that changes the
---working tree is judged.
---@param path string relative to the repository root
---@return string content
function Repo:read(path)
  local handle = assert(io.open(self.root .. "/" .. path), "no such file: " .. path)
  local content = handle:read "a"
  handle:close()
  return content
end

---@param path string relative to the repository root
---@return boolean
function Repo:exists(path) return vim.uv.fs_stat(self.root .. "/" .. path) ~= nil end

---@param path string relative to the repository root
function Repo:delete(path) assert(vim.fn.delete(self.root .. "/" .. path) == 0, "could not delete " .. path) end

---@param ... string paths relative to the repository root
function Repo:add(...) self:git(vim.list_extend({ "add", "--" }, { ... })) end

---@param message string
function Repo:commit(message) self:git { "commit", "--no-gpg-sign", "-m", message } end

---Write, stage and commit in one step.
---@param path string
---@param content string
---@param message string|nil
function Repo:commit_file(path, content, message)
  self:write(path, content)
  self:add(path)
  self:commit(message or ("add " .. path))
end

---@return string branch
function Repo:branch() return vim.trim(self:git { "rev-parse", "--abbrev-ref", "HEAD" }) end

---Write the two sides of a conflict on `path` — one on a branch, one on the
---branch the repository is on — and merge them, asserting that it does
---conflict. What is committed on each is what the index then holds in the
---stage of that side, which is what a test comparing the versions reads.
---@param repo FixtureRepo
---@param path string
local function conflicting_sides(repo, path)
  local branch = "conflicting-" .. vim.fn.fnamemodify(path, ":t:r")
  local ours = repo:branch()
  repo:git { "checkout", "-b", branch }
  repo:commit_file(path, "entrando\n", "their side of " .. path)
  repo:git { "checkout", ours }
  repo:commit_file(path, "atual\n", "our side of " .. path)
  local merge = repo:try_git { "merge", "--no-gpg-sign", branch }
  assert(merge.code ~= 0, "expected the merge of " .. path .. " to conflict")
end

---Leave `path` conflicted by merging a branch that changed it differently.
---Git holds the three sides of it in the index: the base both came from, our
---version and the one coming in.
---@param path string
function Repo:conflict(path)
  -- The version both sides changed away from, which is the one git keeps in
  -- stage 1 of the index.
  self:commit_file(path, "base\n", "base for " .. path)
  conflicting_sides(self, path)
end

---Leave `path` conflicted by merging a branch that added it too: a conflict the
---two sides created from nothing, so git has no base of it to keep in stage 1.
---@param path string
function Repo:conflict_without_base(path) conflicting_sides(self, path) end

---A repository with one commit already in it.
---@param opts { commits?: boolean }|nil `commits = false` leaves it empty
---@return FixtureRepo
function M.repo(opts)
  opts = opts or {}
  local repo = setmetatable({ root = tempdir "repo" }, Repo)
  repo:git { "init", "-b", "main" }
  if opts.commits ~= false then repo:commit_file(".gitkeep", "", "initial commit") end
  return repo
end

---A repository where `git init` has run but nothing was ever committed.
---@return FixtureRepo
function M.repo_without_commits() return M.repo { commits = false } end

---A directory that is not a git repository.
---@return string dir
function M.plain_dir() return tempdir "plain" end

---What `PATH` was before `M.trace_git` put a git of ours in front of it.
---@type string|nil
local previous_path = nil

---A `git` that records what it is called with before handing over to the real
---one, put first on `PATH`. How many processes the panel spawns to read a
---repository is the difference between opening instantly and stopping to hash
---one file at a time, and the only way to see it from outside is to count them.
---@return fun(): string[] calls one line per git process, in order
function M.trace_git()
  local dir = tempdir "gitshim"
  local log = dir .. "/calls"
  local script = {
    "#!/bin/sh",
    ("printf '%%s\\n' \"$*\" >> %s"):format(log),
    ('exec %s "$@"'):format(vim.fn.exepath "git"),
  }
  assert(vim.fn.writefile(script, dir .. "/git") == 0, "could not write the git shim")
  vim.fn.setfperm(dir .. "/git", "rwxr-xr-x")

  previous_path = previous_path or vim.env.PATH
  vim.env.PATH = dir .. ":" .. vim.env.PATH

  return function() return vim.fn.filereadable(log) == 1 and vim.fn.readfile(log) or {} end
end

---What `XDG_DATA_HOME` was before `M.data_dir` moved it, so `M.cleanup` can
---put it back. The environment is process-wide: leaving it moved would send
---the state of every later test — and of the developer's own editor, in a
---interactive run — to a directory that no longer exists.
---@type string|nil
local previous_data_home = nil
local data_home_moved = false

---A data directory of the editor's own, empty: the review state is written
---under it (ADR-0004), so a test that asks for one starts with nothing seen
---and writes nothing into the real data directory.
---@return string dir
function M.data_dir()
  if not data_home_moved then
    previous_data_home = vim.env.XDG_DATA_HOME
    data_home_moved = true
  end
  local dir = tempdir "data"
  vim.env.XDG_DATA_HOME = dir
  return dir
end

---What `XDG_CONFIG_HOME` was before `M.config_dir` moved it, put back by
---`M.cleanup` for the same reason as the data directory's.
---@type string|nil
local previous_config_home = nil
local config_home_moved = false

---A configuration directory of the editor's own, empty: the template of the
---report's preamble is read from under it by default, so a test that asks for
---one writes the template there instead of into the reviewer's configuration.
---@return string dir
function M.config_dir()
  if not config_home_moved then
    previous_config_home = vim.env.XDG_CONFIG_HOME
    config_home_moved = true
  end
  local dir = tempdir "config"
  vim.env.XDG_CONFIG_HOME = dir
  return dir
end

---Remove every directory this module created.
function M.cleanup()
  if previous_path then
    vim.env.PATH = previous_path
    previous_path = nil
  end
  if data_home_moved then
    vim.env.XDG_DATA_HOME = previous_data_home
    previous_data_home, data_home_moved = nil, false
  end
  if config_home_moved then
    vim.env.XDG_CONFIG_HOME = previous_config_home
    previous_config_home, config_home_moved = nil, false
  end
  for _, dir in ipairs(created) do
    vim.fn.delete(dir, "rf")
  end
  created = {}
end

return M
