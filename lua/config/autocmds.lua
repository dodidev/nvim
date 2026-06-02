-- Autocmds are automatically loaded on the VeryLazy event.
-- LazyVim defaults: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
local function augroup(name)
  return vim.api.nvim_create_augroup("user_" .. name, { clear = true })
end

vim.filetype.add({
  extension = {
    pgsql = "pgsql",
    psql = "pgsql",
    mysql = "mysql",
    sqlite = "sqlite",
  },
  pattern = {
    [".*%.pg%.sql"] = "pgsql",
    [".*%.postgres%.sql"] = "pgsql",
    [".*%.postgresql%.sql"] = "pgsql",
    [".*%.mysql%.sql"] = "mysql",
    [".*%.sqlite%.sql"] = "sqlite",
    [".*%.sqlite3%.sql"] = "sqlite",
  },
})

-- Briefly highlight the yanked region
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("yank_highlight"),
  callback = function()
    vim.highlight.on_yank({ higroup = "IncSearch", timeout = 150 })
  end,
})

-- Strip trailing whitespace on every save (cursor-position-safe)
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup("trim_whitespace"),
  callback = function()
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd([[silent! %s/\s\+$//e]])
    pcall(vim.api.nvim_win_set_cursor, 0, pos)
  end,
})

-- Restore last cursor position when reopening a file
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("restore_cursor"),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(0) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close utility windows with just `q`
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("close_with_q"),
  pattern = { "help", "lspinfo", "man", "notify", "qf", "startuptime", "checkhealth", "query" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true })
  end,
})

-- Clean terminal buffers: no numbers, no sign column, enter insert mode
vim.api.nvim_create_autocmd("TermOpen", {
  group = augroup("terminal"),
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.cmd("startinsert")
  end,
})

-- Re-apply transparency after any colorscheme reload
vim.api.nvim_create_autocmd("ColorScheme", {
  group = augroup("reapply_transparency"),
  callback = function()
    local ok, t = pcall(require, "config.transparency")
    if ok then
      t.apply()
    end
  end,
})

local function open_messages_buffer()
  local output = vim.api.nvim_exec2("messages", { output = true }).output or ""
  local lines = vim.split(output, "\n", { plain = true })
  if #lines == 1 and lines[1] == "" then
    lines = { "No messages yet." }
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "Messages")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "messages"
  vim.cmd("botright split")
  vim.api.nvim_win_set_buf(0, buf)
  vim.opt_local.wrap = true
  vim.opt_local.linebreak = true
  vim.opt_local.list = false
end

vim.api.nvim_create_user_command("MessagesFull", open_messages_buffer, {
  desc = "Show full message history in a wrapped scratch buffer",
})

-- vim.api.nvim_create_user_command("MessagesTest", function()
--   vim.api.nvim_echo({ { "Messages test warning", "WarningMsg" } }, true, {})
-- end, {
--   desc = "Emit a test warning for the message viewer",
-- })
