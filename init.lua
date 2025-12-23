-- Set the Python provider BEFORE loading any other configs or plugins
vim.g.python3_host_prog = vim.fn.expand("~/.config/nvim/.venv/bin/python")

-- Enable project-specific configs
vim.g.lazyvim_local_config = true

-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
