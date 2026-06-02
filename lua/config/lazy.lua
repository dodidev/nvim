local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- LazyVim base layer
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- Replace Telescope with fzf-lua (lower memory, faster)
    { import = "lazyvim.plugins.extras.editor.fzf" },
    -- DAP core: nvim-dap + nvim-dap-ui + nvim-dap-virtual-text
    { import = "lazyvim.plugins.extras.dap.core" },
    -- Local plugin specs (every .lua file under lua/plugins/ is auto-imported)
    { import = "plugins" },
  },
  defaults = {
    -- All custom plugins lazy by default; critical ones set lazy = false explicitly
    lazy = true,
    version = false, -- always latest git commit
  },
  install = { colorscheme = { "tokyonight", "habamax" } },
  ui = { border = "rounded" }, -- rounded border on :Lazy and :Mason UI windows
  checker = { enabled = true, notify = false },
  change_detection = { notify = false },
  performance = {
    cache = { enabled = true },
    reset_packpath = true,
    rtp = {
      reset = true,
      disabled_plugins = {
        "gzip",
        "matchit",
        -- "matchparen",  -- uncomment to disable bracket highlighting
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
        "rplugin",
        "spellfile",
      },
    },
  },
})
