-- LSP configuration with strict root-project autostart.
--
-- Rule: a language server only autostarts when the detected project root
-- exactly matches the current window's working directory (vim.fn.getcwd(0)).
-- This prevents sub-project servers (e.g. /android inside a Flutter tree)
-- from spinning up automatically.
--
-- Override: <leader>ls  /  :LspManualStart
-- Sets vim.g.lsp_manual_start = true for 3 s, allowing any root.
-- (The keymap itself lives in lua/config/keymaps.lua so it is always available.)

local ide_root = require("config.root")

local function mason_pkg_path(pkg, suffix)
  local path = vim.fn.stdpath("data") .. "/mason/packages/" .. pkg .. suffix
  if vim.uv.fs_stat(path) then
    return path
  end
  return nil
end

local function typescript_global_plugins()
  local plugins = {}
  local vue_plugin = mason_pkg_path("vue-language-server", "/node_modules/@vue/language-server")
  local astro_plugin = mason_pkg_path("astro-language-server", "/node_modules/@astrojs/ts-plugin")

  if vue_plugin then
    table.insert(plugins, {
      name = "@vue/typescript-plugin",
      location = vue_plugin,
      languages = { "vue" },
      configNamespace = "typescript",
      enableForWorkspaceTypeScriptVersions = true,
    })
  end

  if astro_plugin then
    table.insert(plugins, {
      name = "@astrojs/ts-plugin",
      location = astro_plugin,
      enableForWorkspaceTypeScriptVersions = true,
    })
  end

  return plugins
end

-- :LspManualStart — complement to the <leader>ls keymap in keymaps.lua
vim.api.nvim_create_user_command("LspManualStart", function()
  local ok, err = ide_root.start_current_buffer_lsp(3000)
  if ok then
    vim.notify("LSP: started for current buffer project", vim.log.levels.INFO)
  else
    vim.notify("LSP: manual start failed\n" .. err, vim.log.levels.ERROR)
  end
end, { desc = "Start LSP ignoring strict-root check" })

vim.api.nvim_create_user_command("LspAdoptRoot", function()
  local root, err = ide_root.adopt_root_and_start(3000)
  if root then
    vim.notify("LSP: adopted window root " .. root, vim.log.levels.INFO)
  elseif err ~= "no-root" then
    vim.notify("LSP: adopt root failed\n" .. err, vim.log.levels.ERROR)
  end
end, { desc = "Adopt the current buffer root in this window and start LSP" })

return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        virtual_text = {
          spacing = 4,
          source = "if_many",
          prefix = "icons",
        },
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        float = {
          border = "rounded",
          source = true,
          scope = "line",
        },
      },

      -- Global inlay hints off (expensive; toggle per-buffer with <leader>uh if needed)
      inlay_hints = { enabled = false },

      servers = {
        -- ── Lua ──────────────────────────────────────────────────────────────
        lua_ls = {
          root_dir = ide_root.strict_root_dir({ ".git", ".luarc.json", ".luarc.jsonc" }),
        },

        -- ── Web / TypeScript / Frameworks ───────────────────────────────────
        vtsls = {
          root_dir = ide_root.strict_root_dir({ "tsconfig.json", "jsconfig.json", "package.json", ".git" }),
          filetypes = {
            "javascript",
            "javascriptreact",
            "javascript.jsx",
            "typescript",
            "typescriptreact",
            "typescript.tsx",
            "vue",
          },
          settings = {
            complete_function_calls = true,
            vtsls = {
              autoUseWorkspaceTsdk = true,
              enableMoveToFileCodeAction = true,
              tsserver = {
                globalPlugins = typescript_global_plugins(),
              },
              experimental = {
                completion = { enableServerSideFuzzyMatch = true },
                maxInlayHintLength = 30,
              },
            },
            typescript = {
              updateImportsOnFileMove = { enabled = "always" },
              suggest = { completeFunctionCalls = true },
              inlayHints = {
                enumMemberValues = { enabled = true },
                functionLikeReturnTypes = { enabled = true },
                parameterNames = { enabled = "literals" },
                parameterTypes = { enabled = true },
                propertyDeclarationTypes = { enabled = true },
                variableTypes = { enabled = false },
              },
            },
          },
        },

        vue_ls = {
          root_dir = ide_root.strict_root_dir({
            "vue.config.js", "vite.config.js", "vite.config.ts", "package.json", ".git",
          }),
        },

        astro = {
          root_dir = ide_root.strict_root_dir({
            "astro.config.js", "astro.config.mjs", "astro.config.cjs", "astro.config.ts", "package.json", ".git",
          }),
        },

        tailwindcss = {
          root_dir = ide_root.strict_root_dir({
            "tailwind.config.js",
            "tailwind.config.cjs",
            "tailwind.config.mjs",
            "tailwind.config.ts",
            "postcss.config.js",
            "postcss.config.cjs",
            "postcss.config.mjs",
            "postcss.config.ts",
            "package.json",
            ".git",
          }),
          filetypes = {
            "astro",
            "css",
            "html",
            "javascript",
            "javascriptreact",
            "typescript",
            "typescriptreact",
            "vue",
          },
          settings = {
            tailwindCSS = {
              includeLanguages = {
                astro = "html",
                javascript = "javascript",
                javascriptreact = "javascript",
                typescript = "typescript",
                typescriptreact = "typescript",
                vue = "html",
              },
            },
          },
        },

        html = {
          root_dir = ide_root.strict_root_dir({ "package.json", ".git" }),
          filetypes = { "html" },
        },

        cssls = {
          root_dir = ide_root.strict_root_dir({ "package.json", ".git" }),
        },

        -- ── C# / .NET ───────────────────────────────────────────────────────
        csharp_ls = {
          root_dir = ide_root.strict_root_dir({ "*.sln", "*.csproj", ".git" }),
          init_options = {
            AutomaticWorkspaceInit = true,
          },
        },

        -- ── SQL ─────────────────────────────────────────────────────────────
        postgres_lsp = {
          root_dir = ide_root.strict_root_dir({ "postgrestools.jsonc", ".git" }),
          filetypes = { "sql", "pgsql" },
          single_file_support = false,
        },

        -- ── Python ───────────────────────────────────────────────────────────
        pyright = {
          root_dir = ide_root.strict_root_dir({
            "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git",
          }),
          settings = {
            python = {
              analysis = {
                indexing              = false,           -- no background indexing
                typeCheckingMode      = "basic",         -- balanced accuracy/speed
                autoImportCompletions = true,
                diagnosticMode        = "openFilesOnly", -- only analyse open files
              },
            },
          },
        },

        -- ── C / C++ ──────────────────────────────────────────────────────────
        clangd = {
          root_dir = ide_root.strict_root_dir({
            ".git", "compile_commands.json", "compile_flags.txt", "CMakeLists.txt", "Makefile",
          }),
          cmd = {
            "clangd",
            "--background-index=false", -- no persistent background indexing
            "--clang-tidy=false",        -- run tidy separately if needed
            "--header-insertion=never",
            "--completion-style=bundled",
            "--malloc-trim",             -- release memory when idle
            "--limit-results=20",
            "-j=1",                      -- single-thread mode
          },
        },

        -- ── Assembly (NASM / ARM) ─────────────────────────────────────────────
        asm_lsp = {
          root_dir = ide_root.strict_root_dir({ ".git", "Makefile", "CMakeLists.txt", "build.sh" }),
          filetypes = { "asm", "nasm", "asm68k", "masm", "vmasm" },
        },
      },
    },
  },
}
