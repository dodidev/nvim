return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = vim.tbl_deep_extend("force", opts.formatters_by_ft or {}, {
        bash = { "shfmt" },
        c = { "clang_format" },
        cpp = { "clang_format" },
        cs = { "csharpier" },
        astro = { "prettierd", "prettier", stop_after_first = true },
        css = { "prettierd", "prettier", stop_after_first = true },
        dart = { "dart_format" },
        html = { "prettierd", "prettier", stop_after_first = true },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true },
        json = { "fixjson", "prettierd", "prettier", stop_after_first = true },
        lua = { "stylua" },
        markdown = { "mdformat", "prettierd", "prettier", stop_after_first = true },
        -- Ruff and Black use 88 columns by default. 120 keeps ordinary Python
        -- expressions on one line without disabling consistent formatting.
        python = { "ruff_format", "black", stop_after_first = true },
        rust = { "rustfmt" },
        scss = { "prettierd", "prettier", stop_after_first = true },
        sh = { "shfmt" },
        sql = { "sqlfluff" },
        mysql = { "sqlfluff" },
        pgsql = { "sqlfluff" },
        sqlite = { "sqlfluff" },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "prettierd", "prettier", stop_after_first = true },
        toml = { "taplo" },
        vue = { "prettierd", "prettier", stop_after_first = true },
        yaml = { "yamlfmt", "prettierd", "prettier", stop_after_first = true },
        zsh = { "shfmt" },
      })

      local function sqlfluff_dialect(ctx)
        local filename = ctx and ctx.filename or vim.api.nvim_buf_get_name(0)
        local ft = vim.bo[ctx and ctx.buf or 0].filetype
        if
          vim.fs.find({ ".sqlfluff", "setup.cfg", "tox.ini", "pyproject.toml" }, { path = filename, upward = true })[1]
        then
          return nil
        end
        if
          ft == "pgsql"
          or filename:match("%.pg%.sql$")
          or filename:match("%.postgres%.sql$")
          or filename:match("%.postgresql%.sql$")
        then
          return "postgres"
        end
        if ft == "mysql" or filename:match("%.mysql%.sql$") then
          return "mysql"
        end
        if ft == "sqlite" or filename:match("%.sqlite3?%.sql$") then
          return "sqlite"
        end
        return nil
      end

      opts.formatters = vim.tbl_deep_extend("force", opts.formatters or {}, {
        ruff_format = {
          args = { "format", "--line-length", "120", "--stdin-filename", "$FILENAME", "-" },
          stdin = true,
        },
        black = {
          args = { "--line-length", "120", "-" },
          stdin = true,
        },
        sqlfluff = {
          args = function(_, ctx)
            local args = { "format", "--disable-progress-bar", "-" }
            local dialect = sqlfluff_dialect(ctx)
            if dialect then
              vim.list_extend(args, { "--dialect", dialect })
            end
            return args
          end,
          stdin = true,
        },
      })
    end,
  },

  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      opts.events = { "BufReadPost", "BufWritePost", "InsertLeave" }
      opts.linters_by_ft = vim.tbl_deep_extend("force", opts.linters_by_ft or {}, {
        astro = { "eslint_d" },
        bash = { "shellcheck" },
        javascript = { "eslint_d" },
        javascriptreact = { "eslint_d" },
        lua = { "selene" },
        markdown = { "markdownlint-cli2" },
        mysql = { "sqlfluff" },
        pgsql = { "sqlfluff" },
        python = { "ruff" },
        sh = { "shellcheck" },
        sql = { "sqlfluff" },
        sqlite = { "sqlfluff" },
        typescript = { "eslint_d" },
        typescriptreact = { "eslint_d" },
        vue = { "eslint_d" },
        zsh = { "shellcheck" },
      })

      local function has_eslint_config(ctx)
        return vim.fs.find({
          "eslint.config.js",
          "eslint.config.mjs",
          "eslint.config.cjs",
          ".eslintrc",
          ".eslintrc.js",
          ".eslintrc.cjs",
          ".eslintrc.json",
          ".eslintrc.yaml",
          ".eslintrc.yml",
        }, { path = ctx.filename, upward = true })[1] ~= nil
      end

      local function sqlfluff_dialect(ctx)
        local ft = vim.bo[ctx.bufnr].filetype
        if
          vim.fs.find({ ".sqlfluff", "setup.cfg", "tox.ini", "pyproject.toml" }, { path = ctx.filename, upward = true })[1]
        then
          return nil
        end
        if
          ft == "pgsql"
          or ctx.filename:match("%.pg%.sql$")
          or ctx.filename:match("%.postgres%.sql$")
          or ctx.filename:match("%.postgresql%.sql$")
        then
          return "postgres"
        end
        if ft == "mysql" or ctx.filename:match("%.mysql%.sql$") then
          return "mysql"
        end
        if ft == "sqlite" or ctx.filename:match("%.sqlite3?%.sql$") then
          return "sqlite"
        end
        return nil
      end

      opts.linters = vim.tbl_deep_extend("force", opts.linters or {}, {
        eslint_d = {
          condition = function(ctx)
            return vim.fn.executable("eslint_d") == 1 and has_eslint_config(ctx)
          end,
        },
        markdownlint = {
          condition = function()
            return vim.fn.executable("markdownlint") == 1
          end,
        },
        ["markdownlint-cli2"] = {
          condition = function()
            return vim.fn.executable("markdownlint-cli2") == 1
          end,
        },
        ruff = {
          condition = function()
            return vim.fn.executable("ruff") == 1
          end,
        },
        selene = {
          condition = function(ctx)
            return vim.fn.executable("selene") == 1
              and vim.fs.find({ "selene.toml", "selene.yml", "selene.yaml" }, { path = ctx.filename, upward = true })[1]
          end,
        },
        shellcheck = {
          condition = function()
            return vim.fn.executable("shellcheck") == 1
          end,
        },
        sqlfluff = {
          condition = function(ctx)
            return vim.fn.executable("sqlfluff") == 1
              and (
                sqlfluff_dialect(ctx) ~= nil
                or vim.fs.find(
                    { ".sqlfluff", "setup.cfg", "tox.ini", "pyproject.toml" },
                    { path = ctx.filename, upward = true }
                  )[1]
                  ~= nil
              )
          end,
          args = function(ctx)
            local args = { "lint", "--format=json", "-" }
            local dialect = sqlfluff_dialect(ctx)
            if dialect then
              vim.list_extend(args, { "--dialect", dialect })
            end
            return args
          end,
        },
      })
    end,
  },
}
