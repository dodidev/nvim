return {
  {
    "CopilotC-Nvim/CopilotChat.nvim",
    branch = "canary",
    dependencies = {
      { "zbirenbaum/copilot.lua" },
      { "nvim-lua/plenary.nvim" },
    },
    cmd = {
      "CopilotChat",
      "CopilotChatOpen",
      "CopilotChatClose",
      "CopilotChatToggle",
      "CopilotChatStop",
      "CopilotChatReset",
      "CopilotChatExplain",
      "CopilotChatReview",
      "CopilotChatFix",
      "CopilotChatOptimize",
      "CopilotChatDocs",
      "CopilotChatTests",
      "CopilotChatFixDiagnostic",
      "CopilotChatCommit",
      "CopilotChatCommitStaged",
    },
    keys = {
      -- Open/Toggle Chat
      { "<leader>aa", "<cmd>CopilotChatToggle<cr>", desc = "Toggle Copilot Chat", mode = { "n", "v" } },
      { "<leader>ac", "<cmd>CopilotChat<cr>", desc = "Open Copilot Chat", mode = { "n", "v" } },
      { "<leader>ax", "<cmd>CopilotChatClose<cr>", desc = "Close Copilot Chat" },
      { "<leader>ar", "<cmd>CopilotChatReset<cr>", desc = "Reset Copilot Chat" },

      -- Quick Chat Actions
      {
        "<leader>aq",
        function()
          local input = vim.fn.input("Quick Chat: ")
          if input ~= "" then
            require("CopilotChat").ask(input, { selection = require("CopilotChat.select").buffer })
          end
        end,
        desc = "Quick Chat",
        mode = { "n", "v" },
      },

      -- Prompts
      { "<leader>ae", "<cmd>CopilotChatExplain<cr>", desc = "Explain Code", mode = { "n", "v" } },
      { "<leader>at", "<cmd>CopilotChatTests<cr>", desc = "Generate Tests", mode = { "n", "v" } },
      { "<leader>aT", "<cmd>CopilotChatReview<cr>", desc = "Review Code", mode = { "n", "v" } },
      { "<leader>aR", "<cmd>CopilotChatRefactor<cr>", desc = "Refactor Code", mode = { "n", "v" } },
      { "<leader>an", "<cmd>CopilotChatFixDiagnostic<cr>", desc = "Fix Diagnostic", mode = { "n", "v" } },
      { "<leader>ao", "<cmd>CopilotChatOptimize<cr>", desc = "Optimize Code", mode = { "n", "v" } },
      { "<leader>ad", "<cmd>CopilotChatDocs<cr>", desc = "Generate Docs", mode = { "n", "v" } },
      { "<leader>af", "<cmd>CopilotChatFix<cr>", desc = "Fix Code", mode = { "n", "v" } },

      -- Git
      { "<leader>am", "<cmd>CopilotChatCommit<cr>", desc = "Generate Commit Message" },
      { "<leader>aM", "<cmd>CopilotChatCommitStaged<cr>", desc = "Generate Commit Message (Staged)" },

      -- Inline Chat
      {
        "<leader>ai",
        function()
          local input = vim.fn.input("Inline Chat: ")
          if input ~= "" then
            require("CopilotChat").ask(input, {
              selection = require("CopilotChat.select").visual,
            })
          end
        end,
        desc = "Inline Chat",
        mode = "v",
      },
    },
    opts = {
      debug = false,
      model = "claude-4.5",
      temperature = 0.1,
      question_header = "## User ",
      answer_header = "## Copilot ",
      error_header = "## Error ",
      separator = " ", -- Separator to use in chat
      show_folds = true,
      show_help = true,
      auto_follow_cursor = true,
      auto_insert_mode = false, -- Don't automatically enter insert mode
      clear_chat_on_new_prompt = false,
      highlight_selection = true,
      context = nil,
      history_path = vim.fn.stdpath("data") .. "/copilotchat_history",
      callback = nil,

      -- Window options
      window = {
        layout = "vertical", -- 'vertical', 'horizontal', 'float'
        width = 0.4, -- fractional width of parent
        height = 0.6, -- fractional height of parent

        -- Options for floating window
        relative = "editor",
        border = "rounded",
        row = nil,
        col = nil,
        title = "Copilot Chat",
        footer = nil,
        zindex = 1,
      },

      -- Mappings inside chat window
      mappings = {
        complete = {
          detail = "Use @<Tab> or /<Tab> for options.",
          insert = "<Tab>",
        },
        close = {
          normal = "q",
          insert = "<C-c>",
        },
        reset = {
          normal = "<C-l>",
          insert = "<C-l>",
        },
        submit_prompt = {
          normal = "<CR>",
          insert = "<C-s>",
        },
        accept_diff = {
          normal = "<C-y>",
          insert = "<C-y>",
        },
        yank_diff = {
          normal = "gy",
          register = '"',
        },
        show_diff = {
          normal = "gd",
        },
        show_system_prompt = {
          normal = "gp",
        },
        show_user_selection = {
          normal = "gs",
        },
      },
    },
    config = function(_, opts)
      local chat = require("CopilotChat")
      local select = require("CopilotChat.select")

      -- Setup CopilotChat
      chat.setup(opts)

      -- Custom prompts
      require("CopilotChat.integrations.cmp").setup()

      -- Setup completion for chat
      vim.api.nvim_create_autocmd("BufEnter", {
        pattern = "copilot-*",
        callback = function()
          -- Disable path completion in chat
          local cmp = require("cmp")
          cmp.setup.buffer({ enabled = true })
        end,
      })
    end,
  },
}
