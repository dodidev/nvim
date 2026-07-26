return {
  "ojroques/nvim-osc52",
  config = function()
    local osc52 = require("osc52")

    -- Manual trigger mapping
    vim.keymap.set("n", "<leader>yc", function()
      osc52.copy_operator()
    end, { expr = true })

    vim.keymap.set("v", "<leader>yc", function()
      osc52.copy_visual()
    end)
  end,
}
