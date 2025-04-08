-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local opts = { noremap = true, silent = true }
-- Auto fix
vim.api.nvim_set_keymap("n", "<leader>af", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
vim.api.nvim_set_keymap("v", "<leader>af", "<cmd>lua vim.lsp.buf.range_code_action()<CR>", opts)

-- Terminal
vim.api.nvim_set_keymap("n", "<leader>tt", ":split | terminal<CR>", { desc = "Open terminal in split" })
vim.api.nvim_set_keymap("n", "<leader>tv", ":vsplit | terminal<CR>", { desc = "Open terminal in vsplit" })
