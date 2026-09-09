-- if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  -- import/override with your plugins folder
  { import = "astrocommunity.colorscheme.catppuccin" },
  { import = "astrocommunity.color.ccc-nvim" },
  { import = "astrocommunity.completion.blink-cmp-emoji" },
  { import = "astrocommunity.editing-support.rainbow-delimiters-nvim" },
  { import = "astrocommunity.editing-support.vim-visual-multi" },
  { import = "astrocommunity.motion.nvim-surround" },

  -- Packs (code-runner, treesitter, lsp & lint/format support)

  { import = "astrocommunity.pack.clojure" },
  { import = "astrocommunity.pack.json" },
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.pack.angular" },
  { import = "astrocommunity.pack.python" },
  { import = "astrocommunity.pack.markdown" },

  -- Search and replace across projects
  { import = "astrocommunity.search.grug-far-nvim" },
  -- ----------------------------------------------

  { import = "astrocommunity.pack.diff-keybindings" },
  { import = "astrocommunity.pack.docker" },
  { import = "astrocommunity.pack.spring-boot" },
  { import = "astrocommunity.pack.terraform" },
  { import = "astrocommunity.pack.helm" },
  { import = "astrocommunity.pack.sql" },
  -- ----------------------------------------------
  -- Recipes

  -- Neovide GUI configuration
  { import = "astrocommunity.recipes.neovide" },

  -- LSP Mappings for Snacks or Telescope
  { import = "astrocommunity.recipes.picker-lsp-mappings" },

  -- Source Control

  -- Diffview with neogit integration
  { import = "astrocommunity.git.diffview-nvim" },

  -- Manage GitHub Gists
  { import = "astrocommunity.git.gist-nvim" },

  -- Neogit interactive git client
  { import = "astrocommunity.git.neogit" },

  -- rich command prompt
  { import = "astrocommunity.utility.noice-nvim" },
}
