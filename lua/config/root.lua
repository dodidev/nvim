local M = {}

M.project_markers = {
  ".luarc.json",
  ".luarc.jsonc",
  "package.json",
  "tsconfig.json",
  "jsconfig.json",
  "astro.config.js",
  "astro.config.mjs",
  "astro.config.cjs",
  "astro.config.ts",
  "vite.config.js",
  "vite.config.mjs",
  "vite.config.ts",
  "vue.config.js",
  "tailwind.config.js",
  "tailwind.config.cjs",
  "tailwind.config.mjs",
  "tailwind.config.ts",
  "postcss.config.js",
  "postcss.config.cjs",
  "postcss.config.mjs",
  "postcss.config.ts",
  "*.sln",
  "*.csproj",
  "omnisharp.json",
  "pyproject.toml",
  "setup.py",
  "setup.cfg",
  "requirements.txt",
  "compile_commands.json",
  "compile_flags.txt",
  "CMakeLists.txt",
  "Makefile",
  "build.sh",
  "Cargo.toml",
  "pubspec.yaml",
  ".sqlfluff",
  "postgrestools.jsonc",
  ".git",
}

local function normalize(path)
  return type(path) == "string" and path ~= "" and vim.fs.normalize(path) or nil
end

function M.current_cwd()
  return normalize(vim.fn.getcwd(0))
end

function M.detect_root(source, markers)
  return normalize(vim.fs.root(source, markers or M.project_markers))
end

function M.strict_root_dir(markers)
  return function(source)
    local root = M.detect_root(source, markers)
    if not root then
      return nil
    end
    if vim.g.lsp_manual_start then
      return root
    end
    return root == M.current_cwd() and root or nil
  end
end

function M.start_current_buffer_lsp(timeout_ms)
  vim.g.lsp_manual_start = true
  require("lspconfig")
  local ok, err = pcall(function()
    vim.cmd("LspStart")
  end)
  vim.defer_fn(function()
    vim.g.lsp_manual_start = false
  end, timeout_ms or 3000)
  return ok, err
end

function M.adopt_current_buffer_root(markers)
  local root = M.detect_root(0, markers)
  if not root then
    vim.notify("LSP: no project root detected for current buffer", vim.log.levels.WARN)
    return nil
  end
  vim.cmd("lcd " .. vim.fn.fnameescape(root))
  return root
end

function M.adopt_root_and_start(timeout_ms, markers)
  local root = M.adopt_current_buffer_root(markers)
  if not root then
    return nil, "no-root"
  end

  local ok, err = M.start_current_buffer_lsp(timeout_ms)
  if not ok then
    return nil, err
  end

  return root
end

return M
