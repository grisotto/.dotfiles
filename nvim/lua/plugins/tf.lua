return -- Add this section for Terraform syntax highlighting
  {
    "hashivim/vim-terraform",
    ft = { "terraform", "hcl", "tf", "tfvars" }, -- File types to associate with this plugin
    config = function()
      vim.g.terraform_fmt_on_save = 1 -- Enable automatic formatting on save
    end,
  }

