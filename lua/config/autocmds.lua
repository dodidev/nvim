-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set:  https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds. lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Detect sway file config
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = {
    "**/sway/config",
    "**/sway/config.d/*",
  },
  callback = function()
    vim.bo.filetype = "swayconfig"
  end,
})

-- Detect zsh configuration files
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = {
    "**/.zshrc",
    "**/.zshenv",
    "**/.zprofile",
    "**/.zlogin",
    "**/.zlogout",
    "**/zshrc",
    "**/zshenv",
    "**/zprofile",
    "**/zlogin",
    "**/zlogout",
    "**/zshrc/*",
  },
  callback = function()
    vim.bo.filetype = "zsh"
  end,
})

-- Detect bash configuration files
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = {
    "**/.bashrc",
    "**/.bash_profile",
    "**/.bash_login",
    "**/.bash_logout",
    "**/.bash_aliases",
    "**/.bash_functions",
    "**/bashrc",
    "**/bash_profile",
    "**/bash_login",
    "**/bash_logout",
    "**/bash_aliases",
    "**/bash_functions",
    "**/bashrc/*",
    "**/.profile",
  },
  callback = function()
    vim.bo.filetype = "bash"
  end,
})
