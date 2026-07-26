local function project_python()
  local file = vim.api.nvim_buf_get_name(0)
  local root = vim.fs.root(file, {
    "pyproject.toml",
    "uv.lock",
    "poetry.lock",
    "Pipfile",
    "manage.py",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    ".git",
  })

  local venv = root and root .. "/.venv/bin/python"
  if venv and vim.uv.fs_stat(venv) then
    return venv
  end

  local active_venv = vim.env.VIRTUAL_ENV or vim.env.CONDA_PREFIX
  if active_venv then
    local python = active_venv .. "/bin/python"
    if vim.uv.fs_stat(python) then
      return python
    end
  end

  return vim.fn.exepath("python3") ~= "" and vim.fn.exepath("python3") or "python"
end

return {
  {
    "jay-babu/mason-nvim-dap.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      if not vim.tbl_contains(opts.ensure_installed, "python") then
        table.insert(opts.ensure_installed, "python")
      end

      opts.handlers = opts.handlers or {}
      opts.handlers.python = function(config)
        config.configurations = {
          {
            type = "python",
            request = "launch",
            name = "Python: Launch current file",
            program = "${file}",
            cwd = "${workspaceFolder}",
            console = "integratedTerminal",
            pythonPath = project_python,
          },
        }
        require("mason-nvim-dap").default_setup(config)
      end
    end,
  },
}
