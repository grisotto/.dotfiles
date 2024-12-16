-- load defaults i.e lua_lsp
require("nvchad.configs.lspconfig").defaults()

local ok = require("utils.check_requires").check({
  "lspconfig",
  "cmp_nvim_lsp",
  "null-ls",
})
if not ok then
  return
end

local lspconfig = require "lspconfig"

-- EXAMPLE
local servers = { "html", "cssls", "ts_ls", "angularls", "terraformls" }
local nvlsp = require "nvchad.configs.lspconfig"
local null_ls = require("null-ls")


-- lsps with default config
for _, lsp in ipairs(servers) do
  lspconfig[lsp].setup {
    on_attach = nvlsp.on_attach,
    on_init = nvlsp.on_init,
    capabilities = nvlsp.capabilities,
  }
end

-- Additional config for ts_ls (TypeScript) to disable its formatting (optional, since prettier is commonly used)
lspconfig.ts_ls.setup {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
}

-- Angular specific setup
lspconfig.angularls.setup {
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
  cmd = { "ngserver", "--stdio", "--tsProbeLocations", "/usr/local/lib/node_modules", "--ngProbeLocations", "/usr/local/lib/node_modules" },
  filetypes = { "typescript", "html", "typescriptreact", "typescript.tsx" },
  root_dir = lspconfig.util.root_pattern("angular.json", ".git")
}


lspconfig.terraformls.setup({
  on_attach = nvlsp.on_attach,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
  filetypes = { "terraform", "hcl", "tf", "tfvars" },
  settings = {
    terraform = {
      experimentalFeatures = {
        validateOnSave = true, -- Enable validation on save
      },
    },
  },
  root_dir = lspconfig.util.root_pattern(".terraform", ".git")
})

require'lspconfig'.pyright.setup{}


-- Snyk diagnostic integration
-- null_ls.register({
--   sources = {
--     null_ls.builtins.diagnostics.snyk.with({
--       command = "snyk",
--       args = { "test", "--json-file-output", "-" }, -- Modify args based on how you want snyk to run
--       method = null_ls.methods.DIAGNOSTICS_ON_SAVE,
--       filetypes = { "javascript", "typescript", "terraform" }, -- Adjust based on the files you want to lint with snyk
--     }),
--   },
--   on_attach = on_attach,
-- })

-- configuring single server, example: typescript
-- lspconfig.ts_ls.setup {
--   on_attach = nvlsp.on_attach,
--   on_init = nvlsp.on_init,
--   capabilities = nvlsp.capabilities,
-- }
