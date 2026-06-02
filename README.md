# LazyVim IDE Config

Performance-first LazyVim setup for Neovim 0.13+ with `fzf-lua`, strict project-scoped LSP, Flutter/Rust/web support, transparent `tokyonight`, and a small custom plugin surface.

## Highlights

- **Fast startup bias**: `vim.loader.enable()`, lazy-loaded custom plugins, reduced `shada`, large-file Treesitter guard, and conservative language-server settings.
- **Project-scoped LSP**: servers autostart only when the detected project root matches the current window's working directory.
- **Coding intelligence**: LazyVim LSP + blink.cmp, Copilot suggestions, per-language formatter setup through `conform.nvim`, and lightweight linting through `nvim-lint`.
- **Manual web stack support**: Astro, React, Vue, TypeScript, Tailwind, HTML/CSS, Python, Rust, Flutter, C, and C++ are configured without importing the heavier LazyVim language extras.
- **Picker workflow**: `fzf-lua` replaces Telescope for files, grep, diagnostics, and workspace symbols.

## LSP Root Workflow

The config stays strict by default to avoid noisy background servers in nested projects and monorepos.

- `<leader>ls` — start LSP for the current buffer's detected project without changing the current working directory
- `<leader>lS` — change the current **window-local** directory to the current buffer's detected project root, then start LSP
- `:LspManualStart` — command version of `<leader>ls`
- `:LspAdoptRoot` — command version of `<leader>lS`

This makes nested apps easier to work on without giving up the default strict-root behavior.

## Coding Intelligence Shortcuts

- `<leader>fd` — document diagnostics
- `<leader>fD` — workspace diagnostics
- `<leader>fs` — document symbols
- `<leader>fS` — live workspace symbols
- `gr` / `gI` — references / implementations
- `<leader>cf` — format buffer or selection
- `<leader>cd` — line diagnostics

Copilot suggestions use:

- `<M-l>` accept
- `<M-[>` previous suggestion
- `<M-]>` next suggestion
- `<C-]>` dismiss

## Formatter / Linter Coverage

Configured formatter defaults currently cover:

| Filetype | Formatter |
| --- | --- |
| Lua | `stylua` |
| Python | `ruff_format` or `black` |
| C / C++ | `clang_format` |
| C# | `csharpier` |
| Rust | `rustfmt` |
| Dart | `dart_format` |
| Astro / Vue / React / TypeScript / HTML / CSS | `prettierd` or `prettier` |
| SQL / PostgreSQL / MySQL / SQLite | `sqlfluff` |
| Shell | `shfmt` |
| JSON / YAML / Markdown / TOML | `fixjson`, `yamlfmt`, `mdformat`, `taplo`, or `prettier`/`prettierd` fallback |

Configured linting currently focuses on lightweight, editor-friendly cases:

| Filetype | Linter |
| --- | --- |
| Python | `ruff` |
| Astro / Vue / React / TypeScript | `eslint_d` when installed and an ESLint config exists |
| SQL / PostgreSQL / MySQL / SQLite | `sqlfluff` when a dialect can be detected |
| Shell | `shellcheck` |
| Lua | `selene` (only when a Selene config is present) |
| Markdown | `markdownlint-cli2` |

## First Run

1. `:Lazy sync`
2. `:MasonInstall asm-lsp vtsls vue-language-server astro-language-server tailwindcss-language-server html-lsp css-lsp csharp-language-server`
3. `:Copilot auth`

Optional external tools for the formatter/linter workflow:

- `stylua`, `shfmt`, `ruff`, `black`, `clang-format`, `rustfmt`, `csharpier`, `shellcheck`, `taplo`, `mdformat`, `yamlfmt`, `markdownlint-cli2`, `eslint_d`, `sqlfluff`, `prettierd` or `prettier`
- Optional PostgreSQL LSP: install `postgrestools` and add `postgrestools.jsonc` to projects where you want deep Postgres-aware completion/diagnostics.

## SQL Dialects

SQLFluff is used for SQL linting and formatting. Project config is preferred:

```ini
[sqlfluff]
dialect = postgres
templater = raw
```

Use `dialect = mysql` or `dialect = sqlite` for those projects. Without a config, the editor infers dialect from filetype or filename suffixes such as `.pg.sql`, `.postgres.sql`, `.mysql.sql`, and `.sqlite.sql`.

## Security Audit

Run package vulnerability checks from any project root:

- `scripts/security-audit.sh full` — scan every supported package area.
- `scripts/security-audit.sh changed` — scan package areas changed since the last recorded scan commit.
- `scripts/security-audit.sh changed --no-cache` — ignore the recorded commit and scan all detected package areas.

The script records state in `.security-audit-cache/state`. It supports common Node, Rust, Python, Dart/Flutter, Go, PHP, Ruby, and .NET manifests, and also uses `osv-scanner` when available. It does not install tools automatically; missing audit tools are reported as skipped checks.

Audit installed LazyVim/lazy.nvim plugins separately:

- `scripts/lazy-security-audit.sh full` — scan installed plugins that contain supported package manifests.
- `scripts/lazy-security-audit.sh changed` — scan only plugins whose `lazy-lock.json` commit or installed plugin HEAD changed since the last recorded scan.
- `LAZY_SECURITY_AUDIT_ROOT=/path/to/lazy scripts/lazy-security-audit.sh full` — override the lazy plugin install directory.

The Lazy plugin audit records state in `.security-audit-cache/lazy-state` and fingerprints installed plugin commits in `.security-audit-cache/lazy-previous`.

Static network-risk scan for installed plugins:

- `scripts/lazy-network-audit.sh full` — scan installed plugin source for URLs and network-capable APIs.
- `scripts/lazy-network-audit.sh changed` — scan only plugins whose lockfile commit or installed plugin HEAD changed since the last network scan.
- `scripts/lazy-network-audit.sh full --include-urls` — include raw external URL inventory in addition to active network-capable mechanisms.
- `scripts/lazy-network-audit.sh full --include-spawn` — include generic process-spawn APIs such as `vim.system`, `jobstart`, and `uv.spawn`.
- `LAZY_NETWORK_AUDIT_ROOT=/path/to/lazy scripts/lazy-network-audit.sh full` — override the lazy plugin install directory.

This is not runtime traffic monitoring. By default it flags high-confidence source patterns such as `curl`/`wget`, HTTP fetch/request calls, socket HTTP/TCP modules, and package-manager install/update commands so you can review them manually. Raw URLs and generic process-spawn APIs are opt-in because plugin docs, metadata, and local tool wrappers contain many harmless matches.
