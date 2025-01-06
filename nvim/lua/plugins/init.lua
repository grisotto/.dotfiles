return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "vim", "lua", "vimdoc",
        -- web dev 
        "html",
        "css",
        "javascript",
        "typescript",
        "python",
        "clojure",
      },
    },
  },
  { "mfussenegger/nvim-dap" },

  {
    "jose-elias-alvarez/null-ls.nvim",
    config = function()
      require("null-ls").setup()
    end,
  },
  {
    "rmagatti/auto-session",
    lazy = false,
    enabled = true,
    config = function()
      require("auto-session").setup()
    end,
  },
  {
    "Olical/conjure",
    ft = { "clojure" }, -- etc
    lazy = true,
    init = function()
      -- Set configuration options here
      -- Uncomment this to get verbose logging to help diagnose internal Conjure issues
      -- This is VERY helpful when reporting an issue with the project
      -- vim.g["conjure#debug"] = true
    end,

    -- Optional cmp-conjure integration
    dependencies = { "PaterJason/cmp-conjure" },
  },
  {
    "PaterJason/cmp-conjure",
    lazy = true,
    config = function()
      local cmp = require("cmp")
      local config = cmp.get_config()
      table.insert(config.sources, { name = "conjure" })
      return cmp.setup(config)
    end,
  },
  {
    "tpope/vim-dispatch",
    lazy = false, -- Load this plugin eagerly (if you want it always loaded)
  },
  {
    "clojure-vim/vim-jack-in",
    lazy = false, -- Load this plugin eagerly or set a condition/event for lazy loading
  },
  {
    "radenling/vim-dispatch-neovim",
    lazy = true, -- Lazy load (useful for Neovim-only plugins)
  },
 {
    "tpope/vim-surround",
    event = "VeryLazy", -- Load it lazily, usually when entering a buffer
    config = function()
      -- No configuration is required for vim-surround as it works out of the box
      -- But you can define any custom settings here if needed
    end,
  },
  {
    "guns/vim-sexp",
    ft = { "clojure" },
    lazy = true,
  },
  {
    "tpope/vim-sexp-mappings-for-regular-people",
    ft = { "clojure" },
    lazy = true,
    dependencies = { "guns/vim-sexp" },
  },
  {
    "HiPhish/rainbow-delimiters.nvim",
    ft = { "clojure" },
    lazy = true,
  },
  {
    "tommcdo/vim-exchange",
    lazy = false,

  },
  {
    "karb94/neoscroll.nvim",
    opts = { easing_function = "quadratic", mappings = {'<C-u>', '<C-d>', '<C-b>', '<C-f>'} },
  },
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    lazy = false,
  },
{
    'dense-analysis/ale',
    ft = { "clojure" },
    config = function()
        -- Configuration goes here.
        local g = vim.g

        g.ale_linters = {
            clojure = {'clj-kondo'}
        }
    end
}
}
