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
  {"tpope/vim-dispatch",
    ft = { "clojure" }, -- etc
    lazy = true,},
  {"clojure-vim/vim-jack-in", 
    ft = { "clojure" }, -- etc
    lazy = true,},
  {"radenling/vim-dispatch-neovim",
    ft = { "clojure" }, -- etc
    lazy = true,},

  -- {
  -- 	"nvim-treesitter/nvim-treesitter",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"vim", "lua", "vimdoc",
  --      "html", "css"
  -- 		},
  -- 	},
  -- },
}
