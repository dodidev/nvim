return {
  "folke/snacks.nvim",
  opts = {
    explorer = {
      respect_gitignore = true,
      include = { ".rest" },
    },
    picker = {
      sources = {
        explorer = {
          include = { ".rest" },
        },
      },
    },
  },
}
