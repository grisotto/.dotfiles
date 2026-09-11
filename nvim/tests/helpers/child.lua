-- A Neovim of its own, started as a child of the test editor and spoken to over
-- its stdin and stdout, for the events only the main loop fires.
--
-- The test editor never waits for a key: the specs run from inside `-c`, and
-- `nvim_feedkeys` executes what it is given without the editor getting back to
-- the loop. `CursorMoved` after a key moved the cursor and `WinResized` after a
-- key resized a window are fired there, waiting for the next key, so they never
-- come. A child started with `--embed --headless` is sitting in that loop, and
-- keys sent with `nvim_input` reach it the way the reviewer's do: there the
-- events fire on their own (E9 of `docs/research/rodar-o-neovim-como-agente.md`).
--
-- It starts from the same `tests/minimal_init.lua`, so the same helpers can be
-- required inside it (`M.require`) and read it the way they read this editor.

local M = {}

local this_file = debug.getinfo(1, "S").source:sub(2)
local config_root = vim.fn.fnamemodify(this_file, ":p:h:h:h")

---How long a key left incomplete is given to resolve before the child is taken
---as stuck: more than the default 'timeoutlen', which is how long the editor
---waits on a key that could still be the start of a longer mapping.
local BLOCKED_MS = 1500

---How long the child is given to read the keys `M.input` sent before it is
---asked whether they left it waiting for more. Neither call waits its turn:
---`nvim_input` returns before the keys are read, and `nvim_get_mode` is answered
---at once, ahead of the input already queued (`:help api-fast`). Asked right
---away, it could answer about the editor as it was before the keys arrived.
local READING_MS = 50

---The channel of the child that is running, or nil.
---@type integer|nil
local channel = nil

---What the child wrote to its stderr, which is where a failure to start — a
---plugin the minimal init did not find — is told.
---@type string[]
local stderr = {}

---Send a request to the child, telling what it wrote to stderr when the
---request fails because the child is gone.
---@param method string
---@param ... any
---@return any
local function request(method, ...)
  local chan = assert(channel, "no child editor is running (child.start)")
  local ok, result = pcall(vim.rpcrequest, chan, method, ...)
  if not ok then
    error(("%s to the child editor failed: %s\n%s"):format(method, result, table.concat(stderr, "\n")), 0)
  end
  return result
end

---Wait until the child is no longer waiting for the rest of a key. That is all
---`blocking` tells: not blocked does not mean the last key has taken effect
---(§3.3 of `docs/research/rodar-o-neovim-como-agente.md`). What a key did is
---read with a deferred request, and those are handled in order with the input
---(`:help api-fast`), so the read comes after the key.
---
---Almost everything asked of the child is deferred, and a deferred request
---sent while the editor waits for the rest of a key is never answered: the test
---would hang instead of failing. `nvim_get_mode` is answered even then, and
---`blocking` is what it says about that wait. A key that could still be the start
---of a longer mapping resolves after 'timeoutlen', so the child is given that
---long before it is taken as stuck.
local function wait_until_not_blocked()
  local deadline = vim.uv.hrtime() + BLOCKED_MS * 1e6
  local mode = request "nvim_get_mode"
  while mode.blocking and vim.uv.hrtime() < deadline do
    vim.wait(20)
    mode = request "nvim_get_mode"
  end
  if mode.blocking then
    error(
      ("the child editor is waiting for the rest of a key (mode %q); a literal `<` is sent as `<LT>`"):format(mode.mode),
      0
    )
  end
end

---Start the child editor. Stopped by `M.stop`, which goes in an `after_each`.
function M.start()
  assert(not channel, "a child editor is already running (child.stop)")
  stderr = {}
  channel = vim.fn.jobstart({
    vim.v.progpath,
    "--embed",
    "--headless",
    "--noplugin",
    -- The child is thrown away with the test: it has nothing to read from the
    -- reviewer's shada, and nothing to write there when it exits.
    "-i",
    "NONE",
    "-u",
    config_root .. "/tests/minimal_init.lua",
  }, {
    rpc = true,
    cwd = config_root,
    on_stderr = function(_, data) vim.list_extend(stderr, data) end,
  })
  assert(channel > 0, "could not start a child editor")

  -- The child inherits the environment of this editor, the data directory of
  -- the fixture included. The configuration directory does not reach it: the
  -- minimal init moves it off this repository in every editor it starts, the
  -- child too. Both are handed over, so that the child reads and writes where
  -- the test does.
  M.lua(
    [[
      local env = ...
      vim.env.XDG_DATA_HOME = env.XDG_DATA_HOME
      vim.env.XDG_CONFIG_HOME = env.XDG_CONFIG_HOME
    ]],
    { XDG_DATA_HOME = vim.env.XDG_DATA_HOME, XDG_CONFIG_HOME = vim.env.XDG_CONFIG_HOME }
  )
end

---Stop the child editor, if one is running.
function M.stop()
  if not channel then return end
  vim.fn.jobstop(channel)
  vim.fn.jobwait({ channel }, 1000)
  channel = nil
end

---Send keys to the child as the reviewer types them, through its input buffer.
---They are read in the main loop, which is what fires the events a key causes.
---
---Key notation is translated, so a literal `<` is `<LT>`: a bare one leaves the
---child waiting for the rest of a key (E10), and that is an error here.
---@param keys string
function M.input(keys)
  wait_until_not_blocked()
  local written = request("nvim_input", keys)
  assert(written == #keys, ("the child editor took %d of the %d bytes of %q"):format(written, #keys, keys))
  vim.wait(READING_MS)
  wait_until_not_blocked()
end

---Run Lua in the child and return what it returns.
---@param code string a chunk; its arguments are `...`
---@param ... any arguments, which cross the channel as msgpack
---@return any
function M.lua(code, ...)
  wait_until_not_blocked()
  local result = request("nvim_exec_lua", code, { ... })
  if result == vim.NIL then return nil end
  return result
end

---A module as seen from inside the child: calling one of its functions calls it
---there, with the same arguments, and returns what it returned.
---@param name string e.g. "tests.helpers.panel"
---@return table
function M.require(name)
  return setmetatable({}, {
    __index = function(_, fn)
      return function(...) return M.lua(("return require(%q)[%q](...)"):format(name, fn), ...) end
    end,
  })
end

---Wait for `condition` to hold, asking it again every turn of this editor's
---loop. The condition asks the child, and a request to another editor made from
---inside `vim.wait`'s callback has failed and has hung the editor (§2.3 of
---`docs/research/rodar-o-neovim-como-agente.md`; the cause was not investigated).
---@param condition fun(): boolean
---@param timeout integer ms
---@return boolean held whether it held before the time was up
function M.wait(condition, timeout)
  local deadline = vim.uv.hrtime() + timeout * 1e6
  while not condition() do
    if vim.uv.hrtime() >= deadline then return false end
    vim.wait(20)
  end
  return true
end

return M
