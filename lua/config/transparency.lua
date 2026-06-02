-- Transparency: removes background colours from all relevant highlight groups
-- so the terminal's own background (solid or blurred) shows through.
--
-- Called automatically after every ColorScheme event.
-- Also require()'d from ui.lua right after the colorscheme loads.

local M = {}

-- Every group whose background should be cleared.
-- NOTE: Pmenu* are intentionally excluded — the cmdline completion popup (`:`)
-- uses native Pmenu and cannot have a border, so it must keep a visible
-- background to be distinguishable from the transparent editor background.
local GROUPS = {
  -- Core editor
  "Normal",
  "NormalNC",
  "NormalFloat",
  "FloatBorder",
  "FloatTitle",
  -- Gutter / decorations
  "SignColumn",
  "LineNr",
  "CursorLineNr",
  "FoldColumn",
  "EndOfBuffer",
  -- Status / tab lines
  "StatusLine",
  "StatusLineNC",
  "TabLine",
  "TabLineFill",
  "TabLineSel",
  -- Completion popup
  -- (Pmenu* intentionally omitted — kept solid so the wildmenu popup is visible)
  -- fzf-lua
  "FzfLuaNormal",
  "FzfLuaBorder",
  "FzfLuaTitle",
  -- Telescope (kept in case it's loaded via some other path)
  "TelescopeNormal",
  "TelescopeBorder",
  "TelescopePromptBorder",
  "TelescopeResultsBorder",
  "TelescopePreviewBorder",
  -- Neo-tree
  "NeoTreeNormal",
  "NeoTreeNormalNC",
  "NeoTreeFloatNormal",
  "NeoTreeFloatBorder",
  -- which-key
  "WhichKeyFloat",
  "WhichKeyBorder",
  "WhichKeyNormal",
  -- lazy.nvim / Mason UIs
  "LazyNormal",
  "MasonNormal",
  -- Notify / Noice (groups kept harmless — silently skipped if plugins absent)
  "NotifyBackground",
  -- Diagnostic floats
  "DiagnosticFloatingError",
  "DiagnosticFloatingWarn",
  "DiagnosticFloatingInfo",
  "DiagnosticFloatingHint",
}

function M.apply()
  for _, group in ipairs(GROUPS) do
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
    if not ok then
      goto continue
    end

    -- Strip GUI background; preserve fg, bold, italic, etc.
    hl.bg = nil
    hl.link = nil -- prevent an inherited link from re-applying a background

    -- Strip cterm background (Neovim 0.9+ returns it nested inside hl.cterm)
    if type(hl.cterm) == "table" then
      (hl.cterm --[[@as table<string, any>]]).bg = nil
    end

    vim.api.nvim_set_hl(0, group, hl --[[@as vim.api.keyset.highlight]])
    ::continue::
  end
end

-- Self-contained autocmd so this module works even if required on its own
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("transparency_module", { clear = true }),
  callback = M.apply,
})

return M
