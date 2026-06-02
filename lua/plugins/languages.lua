-- languages.lua — Flutter, Rust, Assembly language support
-- Python / C / C++ are handled via lsp.lua + mason auto-install.

local ide_root = require("config.root")

local function is_real_path(path)
  return type(path) == "string" and path ~= "" and not path:match("^__FLUTTER_DEV_LOG__$")
end

local function resolve_flutter_root(source)
  local markers = { "pubspec.yaml", ".git" }

  local function try_path(path)
    if not is_real_path(path) then
      return nil
    end
    return ide_root.detect_root(path, markers)
  end

  local root = try_path(source)
  if root then
    return root
  end

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      root = try_path(vim.api.nvim_buf_get_name(buf))
      if root then
        return root
      end
    end
  end

  return try_path(vim.uv.cwd() or "")
end

--- Read .vscode/settings.json from the current Flutter project. Returns parsed table or {} on missing/error.
local function read_jsonc_file(path)
  if not vim.uv.fs_stat(path) then
    return nil
  end

  local f = io.open(path, "r")
  if not f then
    return nil
  end

  local raw = f:read("*a")
  f:close()

  -- VS Code launch/settings files are JSONC, so strip comments before decoding.
  local stripped = raw
    :gsub("/%*.-%*/", "")
    :gsub('"(\\.|[^"\\])*"', function(s)
      return s:gsub("//", "__SLASH_SLASH__")
    end)
    :gsub("//[^\n\r]*", "")
    :gsub("__SLASH_SLASH__", "//")

  local ok, data = pcall(vim.fn.json_decode, stripped)
  return (ok and type(data) == "table") and data or nil
end

local function project_root()
  return resolve_flutter_root(vim.api.nvim_buf_get_name(0)) or (vim.uv.cwd() or "")
end

--- Read .vscode/settings.json from the current Flutter project. Returns parsed table or {} on missing/error.
local function read_vscode_settings(root)
  root = root or project_root()
  local path = root .. "/.vscode/settings.json"
  return read_jsonc_file(path) or {}
end

local function extract_flutter_flavor(args)
  if type(args) ~= "table" then
    return nil
  end
  for i, arg in ipairs(args) do
    if arg == "--flavor" and type(args[i + 1]) == "string" then
      return args[i + 1]
    end
    local inline = type(arg) == "string" and arg:match("^%-%-flavor=(.+)$")
    if inline then
      return inline
    end
  end
  return nil
end

local function normalize_flutter_target(root, target)
  if type(target) ~= "string" or target == "" then
    return nil
  end
  target = target:gsub("^${workspaceFolder}/", ""):gsub("^%./", "")
  if target:sub(1, #root + 1) == root .. "/" then
    target = target:sub(#root + 2)
  end
  return target
end

local function flutter_entrypoint(root, flavor, target)
  target = normalize_flutter_target(root, target)
  if target and vim.uv.fs_stat(root .. "/" .. target) then
    return target
  end
  if type(flavor) == "string" and vim.uv.fs_stat(root .. "/lib/main_" .. flavor .. ".dart") then
    return "lib/main_" .. flavor .. ".dart"
  end
  return "lib/main.dart"
end

--- Extract flavors from VSCode launch.json (or fallback to settings.json configurations)
local function get_flutter_flavors()
  local root = project_root()
  local flavors = {}
  local seen = {}

  -- Try to load from .vscode/launch.json first (standard VSCode format)
  local config_data = read_jsonc_file(root .. "/.vscode/launch.json")

  -- Fallback to settings.json if launch.json not found
  if not config_data then
    config_data = read_vscode_settings(root)
  end

  -- Extract flavors from configurations array
  if type(config_data["configurations"]) == "table" then
    for _, config in ipairs(config_data["configurations"]) do
      if type(config.args) == "table" then
        for i, arg in ipairs(config.args) do
          if arg == "--flavor" and i < #config.args then
            local flavor = config.args[i + 1]
            if type(flavor) == "string" and not seen[flavor] then
              table.insert(flavors, flavor)
              seen[flavor] = true
            end
          end
        end
      end
    end
  end

  return flavors
end

local function get_default_flutter_config()
  local root = project_root()
  local launch = read_jsonc_file(root .. "/.vscode/launch.json") or {}
  local settings = read_vscode_settings(root)
  local configs = type(launch.configurations) == "table" and launch.configurations or {}
  local chosen = nil

  for _, config in ipairs(configs) do
    if extract_flutter_flavor(config.args) and (config.default == true or config.name == "default") then
      chosen = config
      break
    end
  end

  if not chosen then
    for _, config in ipairs(configs) do
      if extract_flutter_flavor(config.args) then
        chosen = config
        break
      end
    end
  end

  local flavor = chosen and extract_flutter_flavor(chosen.args) or nil
  local target = chosen and (chosen.program or chosen.target) or nil

  if not flavor then
    flavor = type(settings["dart.flutterFlavor"]) == "string" and settings["dart.flutterFlavor"] or nil
  end

  if not flavor then
    local flavors = get_flutter_flavors()
    flavor = flavors[1]
  end

  if not flavor then
    local mains = vim.fn.glob(root .. "/lib/main_*.dart", false, true)
    table.sort(mains)
    if #mains > 0 then
      flavor = vim.fn.fnamemodify(mains[1], ":t"):match("^main_(.+)%.dart$")
    end
  end

  local entrypoint = flutter_entrypoint(root, flavor, target)
  local config = {
    name = flavor and ("auto: " .. flavor) or "auto: default",
    target = entrypoint,
    cwd = root,
  }

  if flavor then
    config.flavor = flavor
  end

  return config
end

local function run_flutter_with_flavor_picker()
  local flavors = get_flutter_flavors()
  if #flavors == 0 then
    vim.notify("No Flutter flavors detected; running default project config.", vim.log.levels.INFO)
    vim.cmd("FlutterRun")
    return
  end

  vim.ui.select(flavors, { prompt = "Select Flutter flavor: " }, function(flavor)
    if flavor then
      vim.cmd("FlutterRun --flavor " .. vim.fn.escape(flavor, " "))
    end
  end)
end

local function append_flutter_log(lines)
  if type(lines) == "string" then
    lines = { lines }
  end
  if type(lines) ~= "table" or #lines == 0 then
    return
  end

  local ok_log, flutter_log = pcall(require, "flutter-tools.log")
  if ok_log and type(flutter_log.log) == "function" then
    for _, line in ipairs(lines) do
      pcall(flutter_log.log, line)
    end
    return
  end
end

local function setup_dap_cleanup()
  local ok_dap, dap = pcall(require, "dap")
  local ok_dapui, dapui = pcall(require, "dapui")
  if not ok_dap then
    return
  end

  local function clear_dap_buffers()
    if ok_dapui then
      pcall(dapui.close, {})
    end
    pcall(function()
      require("dap.repl").close()
    end)

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
        local ft = vim.bo[buf].filetype
        if ft:match("^dapui_") or ft == "dap-repl" then
          pcall(vim.api.nvim_buf_set_lines, buf, 0, -1, false, {})
        end
      end
    end
  end

  dap.listeners.after.event_terminated["flutter_clear_ui"] = clear_dap_buffers
  dap.listeners.after.event_exited["flutter_clear_ui"] = clear_dap_buffers

  dap.listeners.after["event_dart.debuggerUris"]["flutter_log_devtools"] = function(_, body)
    if body and body.vmServiceUri then
      append_flutter_log("VM service: " .. body.vmServiceUri)
    end

    vim.defer_fn(function()
      local ok_devtools, devtools = pcall(require, "flutter-tools.dev_tools")
      if not ok_devtools then
        return
      end
      local ok_url, url = pcall(devtools.get_url)
      if ok_url and url then
        append_flutter_log("DevTools: " .. url)
      end
    end, 1500)
  end
end

-- Flutter build_runner can be slow and verbose. This function runs it with real-time log streaming to a dedicated buffer, plus notifications on start/finish.
local function run_build_runner()
  -- 1. Check if a process is already running using a global variable
  if _G.build_runner_job then
    vim.notify("Build Runner is already running!", vim.log.levels.WARN)
    return
  end

  -- 2. Check if log buffer exists, reuse or create
  local log_buf = nil
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf):match("Build Runner Logs") then
      log_buf = buf
      break
    end
  end

  if not log_buf then
    log_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(log_buf, "Build Runner Logs")
  else
    -- Clear old logs if reusing buffer
    vim.api.nvim_buf_set_lines(log_buf, 0, -1, false, { "--- New Build Session ---" })
  end

  local notification_handle = vim.notify("Build Runner: Running...", "info", {
    title = "Flutter Tools",
    timeout = 5000,
  })

  -- 3. Start Process
  _G.build_runner_job = vim.system({ "fvm", "dart", "run", "build_runner", "build", "--delete-conflicting-outputs" }, {
    stdout = function(_, data)
      if data then
        vim.schedule(function()
          local lines = vim.split(data:gsub("\r", ""), "\n")
          vim.api.nvim_buf_set_lines(log_buf, -1, -1, false, lines)
        end)
      end
    end,
    stderr = function(_, data)
      if data then
        vim.schedule(function()
          local lines = vim.split(data:gsub("\r", ""), "\n")
          vim.api.nvim_buf_set_lines(log_buf, -1, -1, false, lines)
        end)
      end
    end,
  }, function(obj)
    vim.schedule(function()
      _G.build_runner_job = nil -- Reset job status
      if obj.code == 0 then
        vim.notify("Build Runner: Completed Successfully!", "info", {
          replace = notification_handle,
          timeout = 3000,
        })
      else
        vim.notify("Build Runner: Failed (Code " .. obj.code .. ")", "error", {
          replace = notification_handle,
          timeout = 5000,
        })
      end
    end)
  end)

  -- 4. Keymap to view logs
  vim.keymap.set("n", "<leader>Flb", function()
    vim.cmd("vsplit")
    vim.api.nvim_set_current_buf(log_buf)
    vim.cmd("normal! G") -- Auto jump to bottom
  end, { desc = "View Build Runner Logs" })
end

return {
  -- ── Flutter ────────────────────────────────────────────────────────────────
  {
    "akinsho/flutter-tools.nvim",
    ft = { "dart" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = function()
      -- Resolve the flutter binary through FVM. No public flutter/dart on PATH;
      -- all versions are managed exclusively via FVM.
      --
      -- Resolution order:
      --   1. Project-local  → <cwd>/.fvm/flutter_sdk/bin/flutter  (symlink from `fvm use`)
      --   2. Global default → <cache>/default/bin/flutter          (symlink from `fvm global`)
      --   3. Newest cached  → lexicographically last X.Y.Z version in <cache>
      --
      -- Override the cache root by setting $FVM_CACHE_PATH in your shell profile.
      local function fvm_flutter()
        local cwd = vim.uv.cwd() or ""

        -- 1. Project-local version
        local local_bin = cwd .. "/.fvm/flutter_sdk/bin/flutter"
        if vim.uv.fs_stat(local_bin) then
          return local_bin
        end

        -- FVM stores versions in $FVM_CACHE_PATH or ~/.local/share/fvm/versions/versions
        local cache = vim.env.FVM_CACHE_PATH or (vim.fn.expand("$HOME") .. "/.local/share/fvm/versions/versions")

        -- 2. Global default symlink (set via `fvm global <version>`)
        local default_bin = cache .. "/default/bin/flutter"
        if vim.uv.fs_stat(default_bin) then
          return default_bin
        end

        -- 3. Pick the lexicographically newest installed version (X.Y.Z sorts correctly)
        local hits = vim.fn.glob(cache .. "/*/bin/flutter", false, true)
        if #hits > 0 then
          table.sort(hits)
          return hits[#hits]
        end

        vim.notify("flutter-tools: no FVM-managed flutter found.\nRun: fvm install <version>", vim.log.levels.WARN)
        return nil
      end

      -- FVM cache root used for analysis exclusions (computed once here)
      local fvm_cache = vim.env.FVM_CACHE_PATH or (vim.fn.expand("$HOME") .. "/.local/share/fvm/versions/versions")

      -- Merge VSCode dart settings (if .vscode/settings.json exists in cwd)
      local vscode = read_vscode_settings(project_root())

      -- Allow .vscode/settings.json to override the flutter SDK path
      local flutter_bin = fvm_flutter()
      if type(vscode["dart.flutterSdkPath"]) == "string" then
        local vscode_flutter = vscode["dart.flutterSdkPath"] .. "/bin/flutter"
        if vim.uv.fs_stat(vscode_flutter) then
          flutter_bin = vscode_flutter
        end
      end

      -- Base analysis exclusions, extended with any from VSCode settings
      local excluded = {
        fvm_cache,
        vim.fn.expand("$HOME/.pub-cache"),
        "macos",
        "windows",
        "linux",
        "android",
        "ios",
        "build",
        ".dart_tool",
      }
      if type(vscode["dart.analysisExcludedFolders"]) == "table" then
        vim.list_extend(excluded, vscode["dart.analysisExcludedFolders"])
      end

      -- Dart LSP settings: start from VSCode values, apply our defaults where absent
      ---@type table<string, any>
      local dart_settings = {
        analysisExcludedFolders = excluded,
        lineLength = vscode["dart.lineLength"],
        enableSdkFormatter = vscode["dart.enableSdkFormatter"],
        completeFunctionCalls = vscode["dart.completeFunctionCalls"],
      }

      return {
        flutter_path = flutter_bin,
        fvm = false,
        ui = {
          border = "rounded",
          notification_style = "native",
          width = 0.75,
          height = 0.8,
        },
        decorations = {
          statusline = { app_version = false, device = true },
        },
        lsp = {
          root_dir = ide_root.strict_root_dir({ "pubspec.yaml", ".git" }),
          -- Provide handlers directly to avoid flutter-tools using vim.lsp.with() (deprecated in 0.11+)
          handlers = {
            ["textDocument/hover"] = vim.lsp.handlers["textDocument/hover"],
            ["textDocument/signatureHelp"] = vim.lsp.handlers["textDocument/signatureHelp"],
          },
          on_attach = function(_, bufnr)
            local o = { buffer = bufnr, silent = true }
            vim.keymap.set(
              "n",
              "<leader>Fd",
              "<cmd>FlutterDevices<cr>",
              vim.tbl_extend("force", o, { desc = "Flutter: devices" })
            )
            vim.keymap.set(
              "n",
              "<leader>FR",
              "<cmd>FlutterReload<cr>",
              vim.tbl_extend("force", o, { desc = "Flutter: hot reload" })
            )
            vim.keymap.set(
              "n",
              "<leader>Fq",
              "<cmd>FlutterQuit<cr>",
              vim.tbl_extend("force", o, { desc = "Flutter: quit" })
            )
            vim.keymap.set(
              "n",
              "<leader>FD",
              "<cmd>FlutterDetach<cr>",
              vim.tbl_extend("force", o, { desc = "Flutter: detach" })
            )
            vim.keymap.set(
              "n",
              "<leader>Flc",
              "<cmd>FlutterLogClear<cr>",
              vim.tbl_extend("force", o, { desc = "Flutter: clear log" })
            )
            vim.keymap.set(
              "n",
              "<leader>Flo",
              "<cmd>FlutterOpenDevTools<cr>",
              vim.tbl_extend("force", o, { desc = "Flutter: open DevTools" })
            )
            vim.keymap.set(
              "n",
              "<leader>Fly",
              "<cmd>FlutterCopyProfilerUrl<cr>",
              vim.tbl_extend("force", o, { desc = "Flutter: copy DevTools URL" })
            )
            vim.keymap.set(
              "n",
              "<leader>Fwi",
              "<cmd>FlutterInspectWidget<cr>",
              vim.tbl_extend("force", o, { desc = "Flutter: inspect widget" })
            )
            vim.keymap.set("n", "<leader>Fbr", run_build_runner, { desc = "Run Flutter Build Runner" })

            -- <leader>Fc: Clean build artifacts (flutter clean)
            vim.keymap.set("n", "<leader>Fc", function()
              vim.ui.input({ prompt = "Flutter clean (y/N)? " }, function(input)
                if input and input:lower() == "y" then
                  vim.cmd("FlutterClean")
                end
              end)
            end, vim.tbl_extend("force", o, { desc = "Flutter: clean project" }))

            -- <leader>Frs: Restart the current Flutter app (hot restart)
            vim.keymap.set("n", "<leader>Frs", function()
              vim.ui.input({ prompt = "Flutter hot restart (y/N)? " }, function(input)
                if input and input:lower() == "y" then
                  vim.cmd("FlutterRestart")
                end
              end)
            end, vim.tbl_extend("force", o, { desc = "Flutter: hot restart app" }))

            -- <leader>Flt: Toggle Flutter log visibility (floating window)
            vim.keymap.set("n", "<leader>Flt", function()
              if vim.fn.exists(":FlutterLogToggle") == 2 then
                vim.cmd("FlutterLogToggle")
                return
              end

              -- Fallback for older setups: flutter-tools stores the log buffer
              -- as __FLUTTER_DEV_LOG__ with filetype "log".
              local log_buf = nil
              for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_loaded(buf) then
                  local name = vim.api.nvim_buf_get_name(buf)
                  if name:match("__FLUTTER_DEV_LOG__$") or vim.bo[buf].filetype == "log" then
                    log_buf = buf
                    break
                  end
                end
              end

              if not log_buf then
                vim.notify("Flutter log not available. Run :FlutterRun first.", vim.log.levels.WARN)
                return
              end

              local log_win = nil
              for _, win in ipairs(vim.api.nvim_list_wins()) do
                if vim.api.nvim_win_get_buf(win) == log_buf then
                  log_win = win
                  break
                end
              end

              if log_win then
                vim.api.nvim_win_close(log_win, false)
              else
                local width = math.floor(vim.o.columns * 0.75)
                local height = math.floor(vim.o.lines * 0.8)
                local row = math.floor((vim.o.lines - height) / 2)
                local col = math.floor((vim.o.columns - width) / 2)

                vim.api.nvim_open_win(log_buf, true, {
                  relative = "editor",
                  row = row,
                  col = col,
                  width = width,
                  height = height,
                  border = "rounded",
                  title = " Flutter Log ",
                  title_pos = "center",
                })
              end
            end, vim.tbl_extend("force", o, { desc = "Flutter: toggle log popup" }))

            -- ── DAP / debug keymaps (only wired if nvim-dap is loaded) ──────────
            vim.keymap.set("n", "<leader>Fdb", function()
              require("dap").continue()
            end, vim.tbl_extend("force", o, { desc = "Flutter: debug default" }))

            vim.keymap.set("n", "<leader>Fds", function()
              require("dap").terminate()
            end, vim.tbl_extend("force", o, { desc = "Flutter: stop debugger" }))
            vim.keymap.set("n", "<leader>Fdo", function()
              require("dap").step_over()
            end, vim.tbl_extend("force", o, { desc = "Flutter: step over" }))
            vim.keymap.set("n", "<leader>Fdi", function()
              require("dap").step_into()
            end, vim.tbl_extend("force", o, { desc = "Flutter: step into" }))
            vim.keymap.set("n", "<leader>FdO", function()
              require("dap").step_out()
            end, vim.tbl_extend("force", o, { desc = "Flutter: step out" }))
            vim.keymap.set("n", "<leader>Fdc", function()
              require("dap").continue()
            end, vim.tbl_extend("force", o, { desc = "Flutter: continue" }))
            vim.keymap.set("n", "<leader>Fdt", function()
              require("dap").toggle_breakpoint()
            end, vim.tbl_extend("force", o, { desc = "Flutter: toggle breakpoint" }))
            vim.keymap.set("n", "<leader>FdB", function()
              vim.ui.input({ prompt = "Breakpoint condition: " }, function(cond)
                if cond then
                  require("dap").set_breakpoint(cond)
                end
              end)
            end, vim.tbl_extend("force", o, { desc = "Flutter: conditional breakpoint" }))
            vim.keymap.set("n", "<leader>Fdu", function()
              require("dapui").toggle()
            end, vim.tbl_extend("force", o, { desc = "Flutter: toggle DAP UI" }))

            -- <leader>Frr: Run the auto-selected flavor; <leader>Frp keeps manual override.
            vim.keymap.set("n", "<leader>Frr", function()
              vim.cmd("FlutterRun")
            end, vim.tbl_extend("force", o, { desc = "Flutter: run default" }))
            vim.keymap.set("n", "<leader>Frp", run_flutter_with_flavor_picker, vim.tbl_extend("force", o, {
              desc = "Flutter: run flavor picker",
            }))
          end,
          settings = {
            dart = dart_settings,
          },
        },
        project = { get_default_flutter_config() },
        dev_tools = {
          autostart = false,
          auto_open_browser = false,
        },
        debugger = {
          enabled = true,
          run_via_dap = true, -- <leader>Frr / FlutterRun launches through DAP
          exception_breakpoints = {}, -- silence noisy exception stops by default
          register_configurations = function(paths)
            local ok, dap = pcall(require, "dap")
            if not ok then
              return
            end
            local config = get_default_flutter_config()
            dap.configurations.dart = {
              {
                type = "dart",
                request = "launch",
                name = "Flutter: " .. (config.flavor or "default") .. " (debug)",
                dartSdkPath = paths.dart_sdk,
                flutterSdkPath = paths.flutter_sdk,
                program = config.target,
                flutterMode = "debug",
                toolArgs = { "--track-widget-creation" },
              },
              {
                type = "dart",
                request = "attach",
                name = "Flutter: attach",
                dartSdkPath = paths.dart_sdk,
                flutterSdkPath = paths.flutter_sdk,
                program = config.target,
              },
            }
          end,
        },
      }
    end,
    config = function(_, opts)
      require("flutter-tools").setup(opts)
      setup_dap_cleanup()
    end,
  },

  -- ── Rust ───────────────────────────────────────────────────────────────────
  -- rustaceanvim does NOT use nvim-lspconfig; it manages rust-analyzer directly.
  -- Root-dir logic must be injected via vim.g.rustaceanvim (set in `init`).
  {
    "mrcjkb/rustaceanvim",
    version = "^5",
    ft = { "rust" },
    init = function()
      vim.g.rustaceanvim = {
        tools = {
          -- Disable automatic hover actions popup (open on demand with K)
          hover_actions = { auto_focus = false },
          float_win_config = { auto_focus = false },
        },
        server = {
          root_dir = ide_root.strict_root_dir({ "Cargo.toml" }),

          on_attach = function(_, bufnr)
            local o = { buffer = bufnr, silent = true }
            vim.keymap.set(
              "n",
              "<leader>rr",
              "<cmd>RustLsp runnables<cr>",
              vim.tbl_extend("force", o, { desc = "Rust: runnables" })
            )
            vim.keymap.set(
              "n",
              "<leader>re",
              "<cmd>RustLsp expandMacro<cr>",
              vim.tbl_extend("force", o, { desc = "Rust: expand macro" })
            )
            vim.keymap.set(
              "n",
              "<leader>rc",
              "<cmd>RustLsp openCargo<cr>",
              vim.tbl_extend("force", o, { desc = "Rust: open Cargo" })
            )
            vim.keymap.set(
              "n",
              "<leader>rd",
              "<cmd>RustLsp debuggables<cr>",
              vim.tbl_extend("force", o, { desc = "Rust: debuggables" })
            )
          end,

          default_settings = {
            ["rust-analyzer"] = {
              cargo = {
                allFeatures = false,
                loadOutDirsFromCheck = false, -- skip out-dirs scan (expensive)
              },
              checkOnSave = {
                command = "clippy",
                extraArgs = { "--no-deps" }, -- only check current crate
              },
              procMacro = {
                enable = false, -- proc-macro expansion is CPU-intensive
              },
              diagnostics = {
                enable = true,
                experimental = { enable = false },
              },
              inlayHints = { enable = false }, -- disabled globally for speed
            },
          },
        },
      }
    end,
  },

  -- ── Assembly: treesitter parser ────────────────────────────────────────────
  -- asm-lsp server config lives in lsp.lua.
  -- This spec ensures the treesitter parser is installed.
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      vim.list_extend(opts.ensure_installed or {}, { "asm" })
    end,
  },
}
