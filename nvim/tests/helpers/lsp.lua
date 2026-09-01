-- Language servers, as far as the root detector is concerned.
--
-- The detector answers with the root of the language server attached to the
-- file's buffer, and in a monorepo that is the whole difference between the
-- module and the repository. So a test that has modules needs servers: real
-- clients, attached to real buffers, over a server that answers nothing more
-- than the handshake.

local M = {}

---The clients started here, stopped by `M.cleanup`.
---@type integer[]
local clients = {}

---A server that speaks just enough to become a client attached to a buffer.
---@return fun(dispatchers: table): table
local function server()
  return function()
    local closing = false
    return {
      request = function(method, _, callback)
        -- Answering the handshake is what carries the client to the state
        -- where it is attached; the answer has to come later than the call,
        -- like a real server's would.
        if method == "initialize" then vim.schedule(function() callback(nil, { capabilities = {} }) end) end
        return true, 1
      end,
      notify = function() return true end,
      is_closing = function() return closing end,
      terminate = function() closing = true end,
    }
  end
end

---Open `path` and attach a language server rooted at `root` to it, the way the
---reviewer's editor holds the files of a module open under its server.
---@param path string absolute path of the file
---@param root string absolute path of the module the server is rooted at
function M.attach(path, root)
  vim.cmd.edit(vim.fn.fnameescape(path))
  local bufnr = vim.api.nvim_get_current_buf()

  local id = vim.lsp.start({ name = "fixture", cmd = server(), root_dir = root }, { bufnr = bufnr })
  assert(id, "could not start the fixture language server for " .. path)
  clients[#clients + 1] = id

  assert(
    vim.wait(2000, function() return #vim.lsp.get_clients { bufnr = bufnr } > 0 end),
    "the fixture language server did not attach to " .. path
  )
end

---Stop every server this module started.
function M.cleanup()
  for _, id in ipairs(clients) do
    local client = vim.lsp.get_client_by_id(id)
    if client then pcall(function() client:stop(true) end) end
  end
  clients = {}
end

return M
