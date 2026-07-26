-- Options are automatically loaded before lazy.nvim startup.
-- LazyVim defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
local opt = vim.opt

-- ── Performance ────────────────────────────────────────────────────────────────
-- Limit shada history to reduce startup I/O
opt.shada = "!,'50,<30,s10,h"

-- Faster CursorHold trigger (drives LSP hover, diagnostics)
opt.updatetime = 200

-- Shorter key-sequence timeout (affects which-key popup)
opt.timeoutlen = 300

-- No swap/backup files — use undofile + git instead
opt.swapfile = false
opt.backup = false
opt.writebackup = false

-- Persistent undo stored outside the project
opt.undofile = true
opt.undolevels = 1000
opt.undodir = vim.fn.stdpath("data") .. "/undo"

-- Limit syntax scan width (prevents freezes on minified/generated files)
opt.synmaxcol = 200

-- Cap completion popup height to avoid covering too much of the screen
opt.pumheight = 10

-- ── Editor ─────────────────────────────────────────────────────────────────────
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.splitright = true
opt.splitbelow = true
-- Keep the screen position stable when opening/closing splits (0.9+)
opt.splitkeep = "screen"
-- Global statusline: one bar at the bottom instead of one per split (0.7+)
opt.laststatus = 3

-- ── Indentation ────────────────────────────────────────────────────────────────
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

-- ── Search ─────────────────────────────────────────────────────────────────────
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = false
opt.incsearch = true

-- ── Clipboard / completion ─────────────────────────────────────────────────────
opt.clipboard = "unnamedplus"
opt.completeopt = "menu,menuone,noselect"

-- ── Appearance ─────────────────────────────────────────────────────────────────
opt.termguicolors = true
opt.cmdheight = 1
opt.shortmess:append("sIc")
-- Smooth scrolling when the terminal supports it (0.10+)
opt.smoothscroll = true

-- Folds: use Neovim 0.10+ built-in treesitter fold expressions, disabled by default.
-- Enable per-buffer with:  vim.opt_local.foldmethod = "expr"
--                          vim.opt_local.foldexpr   = "v:lua.vim.treesitter.foldexpr()"
opt.foldenable = false
opt.foldlevel = 99 -- open all folds when folding is toggled on

-- ── LSP floating windows ───────────────────────────────────────────────────────
-- Global handler overrides — thin rounded borders on every LSP popup.
vim.lsp.handlers["textDocument/hover"] = function(err, result, ctx, config)
  return vim.lsp.handlers.hover(
    err,
    result,
    ctx,
    vim.tbl_extend("force", { border = "rounded", max_width = 80 }, config or {})
  )
end
vim.lsp.handlers["textDocument/signatureHelp"] = function(err, result, ctx, config)
  return vim.lsp.handlers.signature_help(
    err,
    result,
    ctx,
    vim.tbl_extend("force", { border = "rounded", max_width = 80, focusable = false }, config or {})
  )
end

-- -----------------------------------------------------------------------------
-- OSC52 clipboard integration (for tmux, iTerm2, etc.)
-- -----------------------------------------------------------------------------

local osc52 = require("vim.ui.clipboard.osc52")

vim.g.clipboard = {
  name = "OSC52-Clipboard",
  copy = {
    ["+"] = osc52.copy("+"),
    ["*"] = osc52.copy("+"), -- Intentionally using '+' here to prevent dual execution
  },
  paste = {
    ["+"] = function()
      return {}
    end,
    ["*"] = function()
      return {}
    end,
  },
}
