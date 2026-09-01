---Painel de revisão de código com Git.
---
---A janela lateral que lista os arquivos em revisão, agrupados por estado, e
---que é o ponto de partida de toda ação de revisão. Este módulo é toda a API
---pública do plugin.
local M = {}

---Override the panel's options. Optional: the defaults apply without it.
---@param opts table|nil see `ReviewConfig`
---@return ReviewConfig
function M.setup(opts) return require("review.config").setup(opts) end

---Open the panel on the repository containing the current directory.
function M.open() require("review.panel").open() end

---Close the panel.
function M.close() require("review.panel").close() end

---Open the panel, or close it when it is already open.
function M.toggle() require("review.panel").toggle() end

---Re-read git and re-render every panel that is open. The panel is one per
---tabpage, but the repository it is listing is not.
function M.refresh() require("review.panel").refresh() end

return M
