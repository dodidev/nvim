-- coding.lua — lightweight editing assistance
-- Yanky (clipboard history) + Copilot (native Lua client)

return {
  -- ── Yanky: clipboard ring with minimal overhead ───────────────────────────
  {
    "gbprod/yanky.nvim",
    event = "VeryLazy",
    opts = {
      ring = {
        history_length = 20, -- keep small; enough for practical use
        storage = "memory", -- no disk I/O; use "sqlite" if persistence is needed
        sync_with_numbered_registers = false,
        cancel_event = "update",
      },
      highlight = {
        on_put = true,
        on_yank = true,
        timer = 150,
      },
      preserve_cursor_position = { enabled = true },
    },
    keys = {
      { "p", "<Plug>(YankyPutAfter)", mode = { "n", "x" }, desc = "Put after" },
      { "P", "<Plug>(YankyPutBefore)", mode = { "n", "x" }, desc = "Put before" },
      { "<c-p>", "<Plug>(YankyPreviousEntry)", desc = "Yanky: previous" },
      { "<c-n>", "<Plug>(YankyNextEntry)", desc = "Yanky: next" },
    },
  },

  -- ── Copilot: native Lua client (lightest option) ──────────────────────────
  -- Suggestion-only mode; panel disabled to avoid extra buffer overhead.
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    opts = {
      suggestion = {
        enabled = true,
        auto_trigger = true,
        debounce = 150, -- ms; avoids firing on every keystroke
        keymap = {
          accept = "<M-l>",
          accept_word = false, -- keep false; word-accept is rarely useful
          accept_line = false,
          next = "<M-]>",
          prev = "<M-[>",
          dismiss = "<C-]>",
        },
      },
      panel = { enabled = false }, -- panel adds a split buffer; not worth the overhead
      filetypes = {
        -- Disable for file types where Copilot adds no value
        help = false,
        gitcommit = false,
        gitrebase = false,
        TelescopePrompt = false,
        ["*"] = true,
      },
    },
  },

  -- Disable github/copilot.vim if it somehow gets pulled in (heavier VimScript version)
  { "github/copilot.vim", enabled = false },

  -- ── blink.cmp: bordered completion + documentation windows ───────────────
  -- LazyVim v13+ uses blink.cmp as the default completion engine.
  -- We only add borders; LazyVim's own blink config handles sources/keymap.
  {
    "saghen/blink.cmp",
    opts = {
      snippets = {
        preset = "luasnip",
      },
      completion = {
        menu = { border = "rounded" },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 150,
          window = { border = "rounded", scrollbar = false },
        },
      },
      signature = {
        enabled = true,
        trigger = { show_on_accept = true },
        window = {
          border = "rounded",
          show_documentation = true,
        },
      },
    },
  },
}
