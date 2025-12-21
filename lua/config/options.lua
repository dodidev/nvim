-- Enable project-specific configs
-- vim.g.lazyvim_local_config = true

-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local opt = vim.opt

-- Enable project-specific configs
vim.g.lazyvim_local_config = true

-- Better editor settings
opt.relativenumber = true -- Show relative line numbers
opt.scrolloff = 8 -- Keep 8 lines above/below cursor
opt.sidescrolloff = 8 -- Keep 8 columns left/right of cursor
opt.wrap = false -- Disable line wrap
opt.swapfile = false -- Disable swapfile
opt.backup = false -- Disable backup
opt.undofile = true -- Enable persistent undo
opt.undodir = vim.fn.stdpath("data") .. "/undo" -- Set undo directory

-- Search settings
opt.ignorecase = true -- Ignore case when searching
opt.smartcase = true -- Override ignorecase if search contains capitals
opt.hlsearch = true -- Highlight search results

-- Better splitting
opt.splitbelow = true -- Put new windows below current
opt.splitright = true -- Put new windows right of current

-- Better completion
opt.completeopt = { "menu", "menuone", "noselect" }
opt.pumheight = 10 -- Maximum number of items in popup menu

-- Better performance
opt.updatetime = 250 -- Faster completion (4000ms default)
opt.timeoutlen = 300 -- Time to wait for mapped sequence

-- Better formatting
opt.formatoptions = "jcroqlnt" -- tcqj
opt.shiftwidth = 2 -- Size of an indent
opt.tabstop = 2 -- Number of spaces tabs count for
opt.expandtab = true -- Use spaces instead of tabs

-- UI improvements
opt.cursorline = true -- Enable highlighting of the current line
opt.signcolumn = "yes" -- Always show the signcolumn
opt.showmode = false -- Don't show mode since we have a statusline
