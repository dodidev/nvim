-- Security Configuration for Neovim
-- Whitelist and sensitivity settings for obfuscation detection

local M = {}

-- Obfuscation detection whitelist
-- Add file patterns or plugin names that use legitimate obfuscation/encoding
M.whitelist = {
  -- Examples of patterns to whitelist:
  -- "lazy%-lock%.json",  -- Lock files often contain hashes
  -- "compiled/.*",       -- Compiled code might be minified
  -- "vendor/.*",         -- Third-party vendor code
  -- ".*%.min%.lua",      -- Minified files
}

-- Sensitivity levels: "low", "medium", "high"
M.sensitivity = "medium"

-- Minimum base64 string length to trigger detection
M.min_base64_length = {
  low = 100,
  medium = 50,
  high = 30,
}

-- Obfuscation score threshold for reporting
M.obfuscation_threshold = {
  low = 10,
  medium = 5,
  high = 3,
}

-- Maximum length of decoded content to analyze (performance)
M.max_decode_length = 10000

-- Trusted plugins (won't be scanned)
M.trusted_plugins = {
  -- Add trusted plugin names here
  -- "lazy.nvim",
  -- "plenary.nvim",
}

-- Custom patterns to ignore
M.ignore_patterns = {
  -- Regular expressions of content to ignore
  -- "-- whitelist: .*",  -- Comments with whitelist marker
}

-- Report settings
M.report = {
  show_decoded_preview = true,
  max_preview_length = 200,
  show_line_numbers = true,
  color_output = true,
}

-- Export settings as a table compatible with security_audit.lua
function M.get_audit_config()
  local sensitivity = M.sensitivity or "medium"

  return {
    min_base64_length = M.min_base64_length[sensitivity] or 50,
    max_decode_length = M.max_decode_length,
    obfuscation_threshold = M.obfuscation_threshold[sensitivity] or 5,
    whitelist = M.whitelist,
  }
end

-- Check if a file should be whitelisted
function M.is_whitelisted(filepath)
  -- Check against whitelist patterns
  for _, pattern in ipairs(M.whitelist) do
    if filepath:match(pattern) then
      return true
    end
  end

  -- Check against trusted plugins
  for _, plugin in ipairs(M.trusted_plugins) do
    if filepath:match(plugin) then
      return true
    end
  end

  return false
end

-- Check if content should be ignored based on patterns
function M.should_ignore_content(content)
  for _, pattern in ipairs(M.ignore_patterns) do
    if content:match(pattern) then
      return true
    end
  end
  return false
end

return M
