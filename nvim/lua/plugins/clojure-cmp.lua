return {
  "saghen/blink.cmp",
  optional = true,
  dependencies = {
    -- add the legacy cmp source as a dependency for `blink.cmp`
    "PaterJason/cmp-conjure",
  },
  specs = {
    -- install the blink, nvim-cmp compatibility layer
    { "saghen/blink.compat", version = "*", lazy = true, opts = {} },
  },
  opts = {
    sources = {
      -- enable the provider by default
      default = { "conjure" },
      -- configure the provider for your new source
      providers = {
        conjure = {
          name = "conjure",
          module = "blink.compat.source",
          score_offset = -1,
        },
      },
    },
  },
}
