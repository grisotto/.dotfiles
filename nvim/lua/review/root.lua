---Where a file's project begins.
---
---Nothing is detected here. The editor already has a root detector — the
---astrocore rooter, which asks the language servers of the file first and
---falls back to project markers — and it is the one that knows, in a monorepo,
---that the module a file belongs to is narrower than the repository it is in.
---A second detector of our own would be a second answer to the same question,
---and the reviewer would have no say in which one they get.
local M = {}

---The buffer named `path`, if the editor already has one. Compared by name and
---not by `bufnr()`, which matches by pattern and would hand back the buffer of
---a different file whose name merely contains this one.
---@param path string absolute path
---@return integer|nil bufnr
local function buffer_of(path)
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(bufnr) == path then return bufnr end
  end
end

---Ask the rooter about a file.
---
---The rooter answers about buffers: a buffer is what carries the name it reads
---and the language servers it asks. So a file the panel is listing but the
---editor has not opened is given one — listed, because the rooter refuses to
---answer about a buffer that is not, and dropped again right after.
---
---A buffer like that has no language server attached to it, and no server can
---be attached in time to answer: they attach when a file is loaded, and they
---answer later still. What comes back for it is what the detectors after the
---LSP say, which for this configuration is the root of the repository. The
---module of a file the reviewer has open is known; the module of one they have
---not is not, and no one in the editor knows it either.
---@param path string absolute path of the file
---@return string|nil root nil when there is no detector, or it has no answer
function M.project(path)
  local ok, rooter = pcall(require, "astrocore.rooter")
  if not ok then return nil end

  local existing = buffer_of(path)
  local bufnr = existing or vim.fn.bufadd(path)
  local listed = vim.bo[bufnr].buflisted
  vim.bo[bufnr].buflisted = true

  local answered, detected = pcall(rooter.detect, bufnr)

  if existing then
    vim.bo[bufnr].buflisted = listed
  else
    pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
  end
  if not answered then return nil end

  -- The detectors come in order of priority and each one answers with its
  -- roots, deepest first. The deepest of the first that answered is the
  -- narrowest project the file is in, which is the one it belongs to. Read
  -- defensively: the shape is the rooter's, and nothing here would notice it
  -- changing until a path came out wrong.
  local root = vim.tbl_get(detected, 1, "paths", 1)
  return type(root) == "string" and root or nil
end

return M
