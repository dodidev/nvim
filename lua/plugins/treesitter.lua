-- treesitter.lua — minimal parser set + large-file safety guard

return {
  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      -- Only parsers relevant to the actual language stack.
      -- Add more via vim.list_extend in individual language plugin files.
      ensure_installed = {
        -- Config & data
        "lua", "luadoc",
        "json", "yaml", "toml",
        "sql",
        "html", "css", "scss",
        -- Systems / embedded
        "c", "cpp", "asm",
        -- High-level languages
        "python",
        "rust",
        "dart",
        "c_sharp",
        -- Web / scripting
        "javascript", "typescript", "tsx",
        "astro", "vue",
        "bash",
        -- Documentation
        "markdown", "markdown_inline",
        -- Neovim internals
        "vim", "vimdoc", "query", "regex",
      },

      highlight = {
        enable = true,
        -- Disable treesitter highlight for files larger than 100 KB to prevent lag.
        disable = function(_, buf)
          local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
          return ok and stats and stats.size > 100 * 1024
        end,
        -- Don't run legacy regex highlighting on top of treesitter
        additional_vim_regex_highlighting = false,
      },

      indent = { enable = true },

      -- Incremental selection disabled: rarely used and wastes memory
      incremental_selection = { enable = false },
    },

  },
}
