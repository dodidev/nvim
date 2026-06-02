# Neovim Config – Copilot Instructions

**Requires Neovim 0.13+.** All APIs target 0.13; no legacy fallbacks are used.

## Architecture

```
init.lua                      → disables built-in plugins early, calls vim.loader.enable(), bootstraps lazy.nvim
lua/config/lazy.lua           → lazy.nvim setup: imports LazyVim base, fzf extra (replaces Telescope), then lua/plugins/
lua/config/options.lua        → Neovim options + vim.diagnostic.config() (loaded before lazy.nvim startup)
lua/config/keymaps.lua        → custom keymaps including <leader>ls for manual LSP start
lua/config/autocmds.lua       → autocommands (VeryLazy event)
lua/config/transparency.lua   → clears bg from all highlight groups; auto-applied after ColorScheme
lua/plugins/lsp.lua           → strict root-only LSP + server configs (pyright, clangd, asm_lsp, lua_ls)
lua/plugins/coding.lua        → yanky.nvim + copilot.lua
lua/plugins/languages.lua     → flutter-tools, rustaceanvim, treesitter asm parser
lua/plugins/database.lua      → vim-dadbod (lazy-loaded on SQL files only)
lua/plugins/ui.lua            → tokyonight (transparent) + fzf-lua overrides
lua/plugins/treesitter.lua    → minimal parser set + large-file disable guard
```

LazyVim provides the base plugin set. All files in `lua/plugins/` extend or override it.

## Formatting

StyLua (`stylua.toml`): 2-space indent, 120-column width.

```sh
stylua lua/           # format all Lua
stylua <file>.lua     # format one file
```

`-- stylua: ignore` suppresses formatting on the next statement.

## Plugin Spec Conventions

- Every file in `lua/plugins/` returns a lazy.nvim spec table (auto-imported).
- **Override** a LazyVim plugin: same short name + `opts = { ... }` — lazy.nvim deep-merges tables.
- **Extend a list option**: `opts = function(_, opts) vim.list_extend(opts.key, {...}) end`.
- **Disable** a plugin: `{ "author/plugin", enabled = false }`.
- **Enable a LazyVim extra**: `{ import = "lazyvim.plugins.extras.lang.foo" }` in `lazy.lua` spec list.
- All custom plugins default to `lazy = true`. Use `lazy = false, priority = 1000` for colorschemes.
- Never add a custom `config` function when overriding a LazyVim plugin — use `opts` only, or the parent spec's `config` is silently replaced.

## Neovim 0.13+ API Usage

| Pattern | What to use |
|---|---|
| Find project root | `vim.fs.root(source, markers)` — accepts bufnr or filepath |
| Current directory | `vim.uv.cwd()` — `vim.loop` is removed in 0.13 |
| Lua bytecode cache | `vim.loader.enable()` — no guard needed, always present |
| File stat | `vim.uv.fs_stat(path)` |
| Treesitter folding | `vim.opt_local.foldmethod="expr"` + `vim.opt_local.foldexpr="v:lua.vim.treesitter.foldexpr()"` |
| Diagnostics config | `vim.diagnostic.config({...})` in `options.lua` |

## Flutter / FVM

No public `flutter` or `dart` on PATH — all Flutter versions are managed via **FVM** (`~/.local/share/fvm/versions/versions/`).

`flutter-tools.nvim` is configured with `fvm = false` and an explicit `flutter_path` resolved by `fvm_flutter()` inside `lua/plugins/languages.lua`. Resolution order:

1. `<cwd>/.fvm/flutter_sdk/bin/flutter` — project-local version (symlink from `fvm use`)
2. `<cache>/default/bin/flutter` — global default symlink (set via `fvm global <version>`)
3. Lexicographically newest `<cache>/*/bin/flutter` — fallback to latest cached version

Override the cache root by setting `$FVM_CACHE_PATH` in your shell profile (defaults to `~/.local/share/fvm/versions/versions`).

The entire FVM cache dir is added to `analysisExcludedFolders` so the Dart analyzer ignores SDK sources.



`lua/plugins/lsp.lua` wraps every server's `root_dir` with `strict_root_dir(markers)`:
- Uses `vim.fs.root(source, markers)` — handles both bufnr (0.11+ built-in LSP) and filepath (lspconfig) natively.
- Auto-start fires **only** when root == `vim.uv.cwd()` exactly. Sub-projects never auto-start.
- **Manual override**: `<leader>ls` / `:LspManualStart` sets `vim.g.lsp_manual_start = true` for 3 s.
- Same `strict_root()` pattern duplicated in `languages.lua` for flutter-tools and rustaceanvim.
- `rustaceanvim` bypasses lspconfig entirely; root logic injected via `vim.g.rustaceanvim` in its `init`.

## Transparency

`lua/config/transparency.lua` mutates highlight tables in-place: sets `hl.bg = nil` and `hl.cterm.bg = nil`, preserving all other attributes (fg, bold, italic, etc.). Applied:
1. In `ui.lua` immediately after the colorscheme loads.
2. On every `ColorScheme` event via the module's own autocmd.

`tokyonight` is also configured with `transparent = true` and an `on_highlights` hook.

## Performance Decisions

| Choice | Reason |
|---|---|
| `defaults.lazy = true` in lazy.nvim | All custom plugins idle until triggered |
| `shada = "!,'50,<30,s10,h"` | Smaller shada reduces startup I/O |
| `vim.loader.enable()` | Lua bytecode cache: ~30% faster module loading |
| Treesitter disabled for files > 100 KB | Prevents highlight freezes on large files |
| `clangd -j=1 --background-index=false` | Single-thread, no persistent index |
| pyright `diagnosticMode = "openFilesOnly"` | No background file scanning |
| rust-analyzer `procMacro.enable = false` | Skips expensive macro expansion |
| fzf-lua instead of Telescope | ~40% lower idle memory |
| `laststatus = 3` | One global statusline — fewer draws per keypress |
| `update_in_insert = false` (diagnostics) | No diagnostic recompute while typing |
| vim-dadbod on `ft = sql` only | Never loaded in non-DB sessions |

## lazy-lock.json

Records the exact commit of every installed plugin. Commit changes after intentional updates (`:Lazy update` inside Neovim).

## First-Run Checklist

1. `:Lazy sync` — install all plugins
2. `:MasonInstall asm-lsp` — ASM language server (not auto-installed)
3. `:Copilot auth` — authenticate the Copilot client

