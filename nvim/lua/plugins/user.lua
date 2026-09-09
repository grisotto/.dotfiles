-- if true then return {} end -- WARN: REMOVE THIS LINE TO ACTIVATE THIS FILE

-- You can also add or configure plugins by creating files in this `plugins/` folder
-- PLEASE REMOVE THE EXAMPLES YOU HAVE NO INTEREST IN BEFORE ENABLING THIS FILE
-- Here are some examples:

---@type LazySpec
return {

  -- Share the current file and line with Discord.
  "andweeb/presence.nvim",
  {
    "ray-x/lsp_signature.nvim",
    event = "BufRead",
    config = function() require("lsp_signature").setup() end,
  },

  -- Customize the dashboard.
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = table.concat({
            "Rafael",
          }, "\n"),
        },
      },
    },
  },

  {
    "rgroli/other.nvim",
    ft = { "clojure", "angular", "python" },
    main = "other-nvim",
    opts = {
      mappings = { "clojure", "angular", "python" },
    },
  },
}
