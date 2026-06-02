-- Keymaps are automatically loaded on the VeryLazy event.
-- LazyVim defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
local map = vim.keymap.set
local ide_root = require("config.root")

-- ── Window navigation ──────────────────────────────────────────────────────────
map("n", "<C-h>", "<C-w>h", { desc = "Window: left", silent = true })
map("n", "<C-j>", "<C-w>j", { desc = "Window: down", silent = true })
map("n", "<C-k>", "<C-w>k", { desc = "Window: up", silent = true })
map("n", "<C-l>", "<C-w>l", { desc = "Window: right", silent = true })

-- ── Window resize ──────────────────────────────────────────────────────────────
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Window: taller" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Window: shorter" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Window: narrower" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Window: wider" })

-- ── Visual mode ────────────────────────────────────────────────────────────────
map("v", "<", "<gv", { desc = "Indent left (keep selection)" })
map("v", ">", ">gv", { desc = "Indent right (keep selection)" })
map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move selection down", silent = true })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move selection up", silent = true })

-- ── Centred navigation ─────────────────────────────────────────────────────────
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down (centred)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up (centred)" })
map("n", "n", "nzzzv", { desc = "Next match (centred)" })
map("n", "N", "Nzzzv", { desc = "Prev match (centred)" })

-- ── Misc ───────────────────────────────────────────────────────────────────────
map({ "n", "i" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })

-- ── LSP manual start (sub-project override) ────────────────────────────────────
-- Sets vim.g.lsp_manual_start = true so strict_root_dir() in lsp.lua allows any root.
map("n", "<leader>ls", function()
  local ok, err = ide_root.start_current_buffer_lsp(3000)
  if ok then
    vim.notify("LSP: started for current buffer project", vim.log.levels.INFO)
  else
    vim.notify("LSP: manual start failed\n" .. err, vim.log.levels.ERROR)
  end
end, { desc = "LSP: start current project" })

map("n", "<leader>lS", function()
  local root, err = ide_root.adopt_root_and_start(3000)
  if root then
    vim.notify("LSP: adopted window root " .. root, vim.log.levels.INFO)
  elseif err ~= "no-root" then
    vim.notify("LSP: adopt root failed\n" .. err, vim.log.levels.ERROR)
  end
end, { desc = "LSP: adopt project root" })
