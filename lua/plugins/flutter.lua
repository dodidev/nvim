return {
  {
    "nvim-flutter/flutter-tools.nvim",
    lazy = true,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "stevearc/dressing.nvim", -- optional for vim.ui.select
    },
    keys = {
      -- Flutter Run & Device Management
      { "<leader>Fc", "<cmd>FlutterRun<cr>", desc = "Flutter Run" },
      { "<leader>Fq", "<cmd>FlutterQuit<cr>", desc = "Flutter Quit" },
      { "<leader>Fd", "<cmd>FlutterDevices<cr>", desc = "Flutter Devices" },
      { "<leader>Fe", "<cmd>FlutterEmulators<cr>", desc = "Flutter Emulators" },

      -- Hot Reload & Restart
      { "<leader>Fr", "<cmd>FlutterReload<cr>", desc = "Flutter Hot Reload" },
      { "<leader>FR", "<cmd>FlutterRestart<cr>", desc = "Flutter Hot Restart" },

      -- DevTools & Logs
      { "<leader>Flt", "<cmd>FlutterLogToggle<cr>", desc = "Flutter Toggle Log" },
      { "<leader>Flc", "<cmd>FlutterLogClear<cr>", desc = "Flutter Clear Logs" },
      { "<leader>Ft", "<cmd>FlutterDevTools<cr>", desc = "Flutter DevTools" },

      -- Outline & Profiler
      { "<leader>Fo", "<cmd>FlutterOutlineToggle<cr>", desc = "Flutter Outline Toggle" },
      { "<leader>Fp", "<cmd>FlutterCopyProfilerUrl<cr>", desc = "Flutter Copy Profiler URL" },

      -- Dart Build Runner
      {
        "<leader>Fb",
        function()
          vim.cmd("split | terminal fvm dart run build_runner build --delete-conflicting-outputs")
        end,
        desc = "Dart Build Runner (build)",
      },
      {
        "<leader>Fw",
        function()
          vim.cmd("split | terminal fvm dart run build_runner watch --delete-conflicting-outputs")
        end,
        desc = "Dart Build Runner (watch)",
      },
      {
        "<leader>FW",
        function()
          vim.cmd("split | terminal fvm dart run build_runner clean")
        end,
        desc = "Dart Build Runner (clean)",
      },
    },
    config = function()
      local flutterConfig = require("flutter-tools")

      flutterConfig.setup({
        ui = {
          border = "rounded",
          notification_style = "native",
        },
        decorations = {
          statusline = {
            app_version = true,
            device = true,
            project_config = true,
          },
        },
        debugger = {
          enabled = true,
          run_via_dap = false,
          exception_breakpoints = {},
          register_configurations = function(paths)
            ---@diagnostic disable-next-line: deprecated
            require("dap.ext.vscode").load_launchjs(nil, { dart = { "dart", "flutter" } })
          end,
        },
        root_patterns = { ".git", "pubspec.yaml" },
        fvm = true, -- flutter-tools will automatically use fvm for Flutter commands
        widget_guides = {
          enabled = false,
        },
        closing_tags = {
          highlight = "Comment",
          prefix = "//",
          enabled = true,
        },
        dev_log = {
          enabled = true,
          notify_errors = false,
          open_cmd = "tabedit",
        },
        dev_tools = {
          autostart = false,
          auto_open_browser = false,
        },
        outline = {
          open_cmd = "30vnew",
          auto_open = false,
        },
        lsp = {
          color = {
            enabled = false,
            background = false,
            background_color = nil,
            foreground = false,
            virtual_text = true,
            virtual_text_str = "■",
          },
          settings = {
            showTodos = true,
            completeFunctionCalls = true,
            renameFilesWithClasses = "prompt",
            enableSnippets = true,
            updateImportsOnRename = true,
          },
        },
      })
    end,
  },
}
