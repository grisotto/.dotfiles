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

---Leave `path` conflicted by merging a branch that changed it differently.
---@param path string
function Repo:conflict(path)
  local ours = self:branch()
  self:commit_file(path, "base\n", "base for " .. path)
  self:git { "checkout", "-b", "conflicting-" .. vim.fn.fnamemodify(path, ":t:r") }
  self:commit_file(path, "entrando\n", "their side of " .. path)
  self:git { "checkout", ours }
  self:commit_file(path, "atual\n", "our side of " .. path)
  local merge = self:try_git { "merge", "--no-gpg-sign", "conflicting-" .. vim.fn.fnamemodify(path, ":t:r") }
  assert(merge.code ~= 0, "expected the merge of " .. path .. " to conflict")
end

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
  for _, dir in ipairs(created) do
    vim.fn.delete(dir, "rf")
  end
  created = {}
end

return M
