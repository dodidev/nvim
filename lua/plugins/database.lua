-- database.lua — vim-dadbod (SQL client)
-- Loaded only when a SQL file is opened or a DB command is run.

return {
  {
    "tpope/vim-dadbod",
    cmd = { "DB", "DBUI" },
    ft = { "sql", "mysql", "pgsql", "plsql", "sqlite" },
    dependencies = {
      {
        "kristijanhusak/vim-dadbod-ui",
        cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
        keys = {
          { "<leader>Du", "<cmd>DBUIToggle<cr>", desc = "DB: toggle UI" },
        },
        init = function()
          -- Store DBUI data outside the project tree
          vim.g.db_ui_use_nerd_fonts  = 1
          vim.g.db_ui_save_location   = vim.fn.stdpath("data") .. "/dadbod-ui"
          vim.g.db_ui_show_database_icon = 1
        end,
      },
      {
        -- Auto-completion for SQL buffers (only active in sql/mysql/plsql files)
        "kristijanhusak/vim-dadbod-completion",
        ft = { "sql", "mysql", "pgsql", "plsql", "sqlite" },
        config = function()
          -- vim-dadbod-completion works with both nvim-cmp (LazyVim ≤ v12)
          -- and blink.cmp (LazyVim v13+). blink.cmp auto-detects it; nvim-cmp needs wiring.
          local ok, cmp = pcall(require, "cmp")
          if not ok then return end -- blink.cmp path: no manual setup required
          cmp.setup.filetype({ "sql", "mysql", "pgsql", "plsql", "sqlite" }, {
            sources = cmp.config.sources(
              { { name = "vim-dadbod-completion" } },
              { { name = "buffer" } }
            ),
          })
        end,
      },
    },
  },
}
