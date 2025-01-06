require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set
local fn = vim.fn

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jj", "<ESC>")

-- Navigation
map('n', ']c', function()
  if vim.wo.diff then
    vim.cmd.normal({']c', bang = true})
  else
    require("gitsigns").nav_hunk('next')
  end
end, {desc = "Git mover para alteracao anterior"})

map('n', '[c', function()
  if vim.wo.diff then
    vim.cmd.normal({'[c', bang = true})
  else
    require("gitsigns").nav_hunk('prev')
  end
end, {desc = "Git mover para proxima alteracao"})

map('n', '<leader>cP', function() require("gitsigns").diffthis('~') end, { desc = "Git diff" })
map('n', '<leader>cs', require("gitsigns").stage_hunk)
map('n', '<leader>rh', require("gitsigns").reset_hunk, {desc = "Git revert line"})
-- map('v', '<leader>hs', function() require("gitsigns").stage_hunk {vim.fn.line('.'), vim.fn.line('v')} end)
map('v', '<leader>cr', function() require("gitsigns").reset_hunk {vim.fn.line('.'), vim.fn.line('v')} end)
-- map('n', '<leader>hS', require("gitsigns").stage_buffer)
map('n', '<leader>cr', require("gitsigns").undo_stage_hunk, {desc = "Revert changes"})
-- map('n', '<leader>hR', require("gitsigns").reset_buffer)
-- map('n', '<leader>hp', require("gitsigns").preview_hunk)

map('n', '<leader>w', "<C-w>v<C-w>l", {desc = "split horizontal"})
map('n', '<leader>v', "<C-w>s<C-w>l", {desc = "split vertical"})

map('n', '<leader>ls', ":!snyk test<CR>", {desc = "run snyk"})

-- Copy to clipboard
map('v', '<leader>y', '"zy', { noremap = true, silent = true, desc = "Copy to clipboard in visual mode" })
map('n', '<leader>Y', '"zyg_', { noremap = true, silent = true, desc = "Copy line to clipboard" })
map('n', '<leader>y', '"zy', { noremap = true, silent = true, desc = "Copy to clipboard" })
map('n', '<leader>yy', '"zyy', { noremap = true, silent = true, desc = "Copy entire line to clipboard" })

-- Paste from clipboard
map('n', '<leader>p', '"zp', { noremap = true, silent = true, desc = "Paste from clipboard" })
map('n', '<leader>P', '"zP', { noremap = true, silent = true, desc = "Paste before from clipboard" })
map('v', '<leader>p', '"zp', { noremap = true, silent = true, desc = "Paste from clipboard in visual mode" })
map('v', '<leader>P', '"zP', { noremap = true, silent = true, desc = "Paste before in visual mode from clipboard" })

map('n', '<leader>dd', [[:lua OpenChromeWithDebugProfile()<CR>]], { noremap = true, silent = true, desc = "Run Chrome with debug-profile" })


function OpenChromeWithDebugProfile()
  -- Obtém o diretório atual e o nome da pasta do projeto
  local project_dir = fn.getcwd()
  local project_name = fn.fnamemodify(project_dir, ":t")
  local profile_dir = "/mnt/c/Users/RafaelGrisotto/nvim/" .. project_name .. "/Profile-debug"

  -- Verifica se o diretório existe, e se não, cria
  if fn.isdirectory(profile_dir) == 0 then
    fn.mkdir(profile_dir, "p")
  end

  -- Comando para abrir o Chrome com o perfil específico
  local chrome_command = [["/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" --remote-debugging-port=9222 --no-first-run --disable-sync --no-default-browser-check --user-data-dir="]] .. profile_dir .. [[" --profile-directory="deeebug-profile" http://localhost:4202]]

  -- Executa o comando diretamente
  vim.fn.jobstart(chrome_command)
end
-- """ MOVING AROUND
-- nnoremap <C-h> <C-w>h
-- nnoremap <C-j> <C-w>j
-- nnoremap <C-k> <C-w>k
-- nnoremap <C-l> <C-w>l


vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local bufnr = args.buf

    -- A small helper for setting buffer-local keymaps
    local function buf_map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, {
        buffer = bufnr,
        silent = true,
        noremap = true,
        desc = desc,
      })
    end

    -- 1) Map `K` to show hover documentation for ALL LSPs
    buf_map("n", "K", vim.lsp.buf.hover, "LSP Hover Documentation")
    buf_map("n", "<leader>rS", "<cmd>LspRestart<CR>",          "LSP Restart")

    if client and client.name == "pyright" then
      -- Example: better-named shortcuts using <leader>p*
      buf_map("n", "<leader>pO", "<cmd>PyrightOrganizeImports<CR>", "py Organize Imports")
    end
  end,
})

