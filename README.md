# 💤 LazyVim

A starter template for [LazyVim](https://github.com/LazyVim/LazyVim).
Refer to the [documentation](https://lazyvim.github.io/installation) to get started.

## 🔒 Security Features

This configuration includes advanced security auditing tools to detect obfuscated and malicious code in Neovim plugins:

- **Base64 Detection**: Automatically detects and decodes base64 encoded strings
- **Obfuscation Detection**: Identifies code obfuscation techniques (XOR, string.char, hex encoding)
- **Threat Detection**: Catches multi-stage payloads, time-delayed execution, and more
- **Dual Implementation**: Both Lua module and shell script for comprehensive scanning

### Quick Start

```bash
# Scan plugins directory
./scripts/nvim_security_check.sh lua/plugins

# Run Lua-based audit
lua -e "print(require('scripts.security_audit').format_results(require('scripts.security_audit').audit_directory('lua/plugins')))"

# Run test suite
lua tests/security_test_cases.lua
```

### Documentation

- [Obfuscation Detection Guide](docs/OBFUSCATION_DETECTION.md)
- [Usage Examples](docs/USAGE_EXAMPLES.md)

See the documentation for detailed information on detection capabilities, configuration, and integration options.
