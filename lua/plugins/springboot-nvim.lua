return {
  "elmcgill/springboot-nvim",
  dependencies = {
    "neovim/nvim-lspconfig",
    "mfussenegger/nvim-jdtls",
  },
  lazy = true,
  ft = { "java" },
  cond = function()
    -- Chek for required files
    local has_build_gradle = vim.fn.glob("build.gradle") ~= ""
    local has_settings_gradle = vim.fn.glob("settings.gradle") ~= ""
    local has_java_scr = vim.fn.isdirectory("src/main/java") == 1

    -- Ensure all required files exist
    if has_build_gradle and has_settings_gradle and has_java_scr then
      -- Double-check that build.gradle contains the spring-boot plugin
      for line in io.lines("build.gradle") do
        if line:find("id 'org.springframework.boot'") then
          return true
        end
      end
    end

    return false
  end,
  config = function()
    local springboot_nvim = require("springboot-nvim")
    vim.keymap.set("n", "<leader>Jr", springboot_nvim.boot_run, { desc = "Spring Boot Run Project" })
    vim.keymap.set("n", "<leader>Jc", springboot_nvim.generate_class, { desc = "Java Create Class" })
    vim.keymap.set("n", "<leader>Ji", springboot_nvim.generate_interface, { desc = "Java Create Interface" })
    vim.keymap.set("n", "<leader>Je", springboot_nvim.generate_enum, { desc = "Java Create Enum" })
    springboot_nvim.setup({})
  end,
}
