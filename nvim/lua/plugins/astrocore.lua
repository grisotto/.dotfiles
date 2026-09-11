-- if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- AstroCore provides a central place to modify mappings, vim options, autocommands, and more!
-- Configuration documentation can be found with `:h astrocore`
-- NOTE: We highly recommend setting up the Lua Language Server (`:LspInstall lua_ls`)
--       as this provides autocomplete and documentation while editing

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    -- Configure core features of AstroNvim
    sessions = {
      -- Configure auto saving
      autosave = {
        last = true, -- auto save last session
        cwd = true, -- auto save session for each working directory
      },
      -- Patterns to ignore when saving sessions
      ignore = {
        dirs = {}, -- working directories to ignore sessions in
        filetypes = { "gitcommit", "gitrebase" }, -- filetypes to ignore sessions
        buftypes = {}, -- buffer types to ignore sessions
      },
    },
    autocmds = {
      -- sqls.nvim >= dfc304f configures itself through Neovim's native LSP
      -- API; AstroCommunity's legacy callback still calls require("sqls").
      sqls_attach = false,
      restore_session = {
        {
          event = "VimEnter",
          desc = "Restore previous directory session if neovim opened with no arguments",
          nested = true, -- trigger other autocommands as buffers open
          callback = function()
            -- Only load the session if nvim was started with no args
            if vim.fn.argc(-1) == 0 then
              -- try to load a directory session using the current working directory
              require("resession").load(vim.fn.getcwd(), { dir = "dirsession", silence_errors = true })
            end
          end,
        },
      },
    },
    features = {
      large_buf = { size = 1024 * 256, lines = 10000 }, -- set global limits for large files for disabling features like treesitter
      autopairs = true, -- enable autopairs at start
      cmp = true, -- enable completion at start
      diagnostics = { virtual_text = true, virtual_lines = false }, -- diagnostic settings on startup
      highlighturl = true, -- highlight URLs at start
      notifications = true, -- enable notifications at start
    },
    -- Diagnostics configuration (for vim.diagnostics.config({...})) when diagnostics are on
    diagnostics = {
      virtual_text = true,
      underline = true,
    },
    -- vim options can be configured here
    options = {
      opt = { -- vim.opt.<key>
        relativenumber = true, -- sets vim.opt.relativenumber
        number = true, -- sets vim.opt.number
        spell = false, -- sets vim.opt.spell
        signcolumn = "yes", -- sets vim.opt.signcolumn to yes
        wrap = false, -- sets vim.opt.wrap
        guifont = "Fira Code:h16", -- neovide font family & size
        -- O botão direito abre menu de contexto em todo o editor, e não só no
        -- painel de revisão (ADR-0008). É o padrão do Neovim hoje; está escrito
        -- aqui porque o painel depende dele para o menu dele existir.
        mousemodel = "popup_setpos",
      },
      g = { -- vim.g.<key>
        -- configure global vim variables (vim.g)
        -- NOTE: `mapleader` and `maplocalleader` must be set in the AstroNvim opts or before `lazy.setup`
        -- This can be found in the `lua/lazy_setup.lua` file
        loaded_perl_provider = 0,
        loaded_ruby_provider = 0,

        VM_leader = "gm", -- Visual Multi Leader (multiple cursors - user plugin)

        -- Conjure plugin overrides
        -- comment pattern for eval to comment command
        ["conjure#eval#comment_prefix"] = ";; ",
        -- Hightlight evaluated forms
        ["conjure#highlight#enabled"] = true,

        -- show HUD REPL log at startup
        ["conjure#log#hud#enabled"] = true,

        -- `,K` asks the connected REPL for documentation; bare `K` remains LSP hover.
        ["conjure#mapping#doc_word"] = "K",

        -- auto repl (babashka)
        ["conjure#client#clojure#nrepl#connection#auto_repl#enabled"] = false,
        ["conjure#client#clojure#nrepl#connection#auto_repl#hidden"] = true,
        ["conjure#client#clojure#nrepl#connection#auto_repl#cmd"] = nil,
        ["conjure#client#clojure#nrepl#eval#auto_require"] = false,

        -- Fast feedback through clojure.test. Project gates still run through
        -- `clojure -M:poly test` and `bb test:cljs`.
        ["conjure#client#clojure#nrepl#test#runner"] = "clojure",

        -- Troubleshoot: Minimise very long lines slow down:
        -- ["conjure#log#treesitter"] = false
        -- ["conjure#log##treesitter"] = false,
        -- ["conjure#log#disable_diagnostics"] = true
      },
    },
    -- Mappings can be configured through AstroCore as well.
    --
    -- O lado esquerdo segue a grafia do `:h keycodes` — `<Leader>`,
    -- `<LocalLeader>`, `<Tab>`, `<C-Up>`. Não é estilo. O AstroCore guarda os
    -- mapeamentos numa tabela indexada pela string, então `<leader>p` e
    -- `<Leader>p` entram como duas chaves diferentes. O `normalize_mappings` do
    -- AstroCore junta as duas no `setup()`, e junta percorrendo a tabela
    -- enquanto a altera: quando as duas grafias existem, qual sobrevive muda de
    -- uma partida para outra. Foi assim que `<Leader>p` ficou mudo — um `false`
    -- numa grafia e o mapeamento na outra. Escrever a mesma tecla em duas
    -- grafias é cara-ou-coroa, não estilo; o `:checkhealth astrocore` acusa.
    mappings = {
      -- first key is the mode
      n = {
        -- Área de transferência pelo registro `z`, para o `y`/`p` de todo dia
        -- seguirem no registro sem nome.
        --
        -- `<Leader>p` também é o prefixo do menu "Plugins" do AstroNvim (`pi`,
        -- `ps`, `pS`, `pu`, `pU`, `pa`, `pm`, `pM`), e esses continuam
        -- existindo: colar aqui só acontece depois do `timeoutlen` (500 ms),
        -- porque o Neovim precisa desistir de uma sequência mais longa. É de
        -- propósito, e não um bug a consertar — a tecla vale mais como colar do
        -- que como porta de um menu que se alcança pelo `:Lazy`.
        ["<Leader>y"] = { '"zy', desc = "Copy to clipboard" },
        ["<Leader>Y"] = { '"zyg_', desc = "Copy line to clipboard" },
        ["<Leader>yy"] = { '"zyy', desc = "Copy entire line to clipboard" },
        ["<Leader>p"] = { '"zp', desc = "Paste from clipboard" },
        ["<Leader>P"] = { '"zP', desc = "Paste before from clipboard" },
        -- second key is the lefthand side of the map
        -- Rótulo do menu do which-key para o Visual-Multi. O AstroCore nomeia
        -- menu com `desc`; uma tabela com `name` não chega a ser registrada e o
        -- grupo aparece sem nome.
        ["gm"] = { desc = "Multiple Cursors" },

        -- Toggle last open buffer
        ["<Leader><Tab>"] = { "<cmd>b#<cr>", desc = "Previous tab" },
        -- navigate buffer tabs
        ["]b"] = { function() require("astrocore.buffer").nav(vim.v.count1) end, desc = "Next buffer" },
        ["[b"] = { function() require("astrocore.buffer").nav(-vim.v.count1) end, desc = "Previous buffer" },

        -- mappings seen under group name "Buffer"
        ["<Leader>bd"] = {
          function()
            require("astroui.status.heirline").buffer_picker(
              function(bufnr) require("astrocore.buffer").close(bufnr) end
            )
          end,
          desc = "Close buffer from tabline",
        },

        -- tables with just a `desc` key will be registered with which-key if it's installed
        -- this is useful for naming menus
        -- ["<Leader>b"] = { desc = "Buffers" },

        -- setting a mapping to false will disable it
        -- ["<C-S>"] = false,
        -- Toggle between src and test (Clojure pack | other-nvim)
        ["<LocalLeader>ts"] = { "<cmd>Other<cr>", desc = "Switch src & test" },
        ["<LocalLeader>tS"] = { "<cmd>OtherVSplit<cr>", desc = "Switch src & test (Split)" },
      },
      v = {
        -- Visual mode clipboard mappings
        ["<Leader>y"] = { '"zy', desc = "Copy to clipboard in visual mode" },
        ["<Leader>p"] = { '"zp', desc = "Paste from clipboard in visual mode" },
        ["<Leader>P"] = { '"zP', desc = "Paste before in visual mode from clipboard" },
      },
    },
  },
}
