-- ui.lua — colorscheme + fzf-lua overrides + which-key border
-- Telescope is disabled by the fzf extra imported in lazy.lua.

return {
  -- ── which-key: rounded popup border ────────────────────────────────────────
  -- LazyVim includes which-key; we only override the window style.
  {
    "folke/which-key.nvim",
    opts = {
      win = { border = "rounded" },
    },
  },

  -- ── noice.nvim: disabled — use native bottom-left cmdline ──────────────────
  -- LazyVim pulls noice in by default; disabling it restores the native ":" bar.
  { "folke/noice.nvim",   enabled = false },
  { "rcarriga/nvim-notify", enabled = false }, -- noice pulls this in; disable too

  -- ── Colorscheme: tokyonight with built-in transparency ─────────────────────
  -- LazyVim already includes tokyonight; we override opts to add transparency.
  {
    "folke/tokyonight.nvim",
    opts = {
      transparent = true, -- native transparent background
      styles = {
        sidebars = "transparent",
        floats   = "transparent",
      },
      -- Suppress tokyonight's own Normal/NormalFloat background assignments
      on_highlights = function(hl, c)
        hl.Normal      = { bg = "NONE" }
        hl.NormalFloat = { bg = "NONE" }
        hl.FloatBorder = { fg = c.border_highlight, bg = "NONE" }
        hl.NormalNC    = { bg = "NONE" }
        hl.SignColumn  = { bg = "NONE" }
        -- Pmenu: keep a solid background so the cmdline wildmenu popup (`:` completion)
        -- is visible against the transparent terminal background.
        -- blink.cmp draws its own bordered window on top of these, so insert-mode
        -- completion gets a proper border via coding.lua.
        hl.Pmenu      = { bg = c.bg_dark,   fg = c.fg }
        hl.PmenuSel   = { bg = c.bg_visual, fg = c.fg, bold = true }
        hl.PmenuSbar  = { bg = c.bg_dark }
        hl.PmenuThumb = { bg = c.blue5 }
      end,
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight-night")
      -- Belt-and-suspenders: apply our own transparency pass after colorscheme loads
      require("config.transparency").apply()
    end,
  },

  -- ── fzf-lua: override LazyVim extra's defaults ─────────────────────────────
  -- The extra (imported in lazy.lua) handles disabling Telescope.
  -- Here we tune window appearance and keymaps.
  {
    "ibhagwan/fzf-lua",
    opts = {
      -- LazyVim's fzf extra lazy-registers vim.ui.select on first use. Keep setup
      -- from registering it early, otherwise fzf-lua emits a duplicate warning.
      ui_select = false,
      winopts = {
        height = 0.85,
        width  = 0.82,
        border = "rounded",
        -- Transparency is applied via config.transparency; these hl groups are cleared there.
        hl = {
          normal  = "FzfLuaNormal",
          border  = "FzfLuaBorder",
          title   = "FzfLuaTitle",
          preview = { border = "FzfLuaBorder" },
        },
        preview = {
          border     = "rounded",
          scrollbar  = false, -- minor CPU saving on large previews
          wrap       = "nowrap",
        },
      },
      fzf_opts = {
        ["--layout"] = "reverse",
        ["--info"]   = "inline",
      },
      previewers = {
        bat = { theme = "base16" },
      },
    },
    keys = {
      { "<leader>ff", "<cmd>FzfLua files<cr>",               desc = "Find files"              },
      { "<leader>fg", "<cmd>FzfLua live_grep<cr>",           desc = "Live grep"               },
      { "<leader>fb", "<cmd>FzfLua buffers<cr>",             desc = "Buffers"                 },
      { "<leader>fh", "<cmd>FzfLua help_tags<cr>",           desc = "Help tags"               },
      { "<leader>fr", "<cmd>FzfLua oldfiles<cr>",            desc = "Recent files"            },
      { "<leader>fc", "<cmd>FzfLua commands<cr>",            desc = "Commands"                },
      { "<leader>fd", "<cmd>FzfLua diagnostics_document<cr>",desc = "Document diagnostics"    },
      { "<leader>fD", "<cmd>FzfLua diagnostics_workspace<cr>", desc = "Workspace diagnostics" },
      { "<leader>fs", "<cmd>FzfLua lsp_document_symbols<cr>",desc = "Document symbols"        },
      { "<leader>fS", "<cmd>FzfLua lsp_live_workspace_symbols<cr>", desc = "Workspace symbols" },
      { "<leader>/",  "<cmd>FzfLua grep_curbuf<cr>",         desc = "Grep current buffer"     },
      { "gr",         "<cmd>FzfLua lsp_references<cr>",      desc = "LSP references"          },
      { "gI",         "<cmd>FzfLua lsp_implementations<cr>", desc = "LSP implementations"     },
    },
  },
}
