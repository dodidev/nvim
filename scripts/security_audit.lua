-- Security Audit Module for Neovim Plugin Security
-- Detects obfuscation, encoding, and advanced threat patterns in Lua code

local M = {}

-- Configuration
M.config = {
  min_base64_length = 50,
  max_decode_length = 10000,
  obfuscation_threshold = 5,
  whitelist = {},
}

-- Pattern definitions
M.patterns = {
  base64 = {
    -- Base64 encoded strings (with padding variations)
    "([A-Za-z0-9+/]+=*)",
    -- Long base64 strings (more specific)
    "([A-Za-z0-9+/]{50,}=*)",
  },
  encoding_functions = {
    "vim%.fn%.base64encode",
    "vim%.fn%.base64decode",
    "string%.char%s*%(",
    "string%.byte%s*%(",
    "vim%.base64",
  },
  obfuscation = {
    "string%.char%s*%([%d,%s]+%)", -- Multiple string.char calls with numbers
    "loadstring%s*%(",
    "load%s*%(",
    "getfenv%s*%(",
    "setfenv%s*%(",
    "debug%.getinfo",
    "debug%.setfenv",
    "debug%.getfenv",
  },
  encryption = {
    "xor",
    "bit%.bxor",
    "bit32%.bxor",
    "0x[0-9a-fA-F]+",
    "%%[0-9a-fA-F][0-9a-fA-F]", -- URL encoding
  },
  dangerous_patterns = {
    "io%.popen",
    "os%.execute",
    "vim%.fn%.system",
    "vim%.system",
    "require%s*%([^%)]*%.%.",
    "curl",
    "wget",
    "http://",
    "https://",
  },
  advanced_threats = {
    "vim%.loop%.spawn",
    "vim%.uv%.spawn",
    "vim%.fn%.jobstart",
    "vim%.fn%.termopen",
    "setmetatable.*__index",
    "rawget",
    "rawset",
    "_G%[",
    "package%.loaded",
    "package%.preload",
  },
}

-- Base64 decode helper
function M.decode_base64(str)
  -- Simple Lua-based base64 decoder
  local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  local b64lookup = {}
  for i = 1, #b64chars do
    b64lookup[b64chars:sub(i, i)] = i - 1
  end

  local result = {}
  local padding = 0

  -- Count padding
  for i = #str, #str - 1, -1 do
    if str:sub(i, i) == "=" then
      padding = padding + 1
    else
      break
    end
  end

  -- Decode
  for i = 1, #str - padding, 4 do
    local a = b64lookup[str:sub(i, i)] or 0
    local b = b64lookup[str:sub(i + 1, i + 1)] or 0
    local c = b64lookup[str:sub(i + 2, i + 2)] or 0
    local d = b64lookup[str:sub(i + 3, i + 3)] or 0

    local n = a * 262144 + b * 4096 + c * 64 + d

    table.insert(result, string.char(math.floor(n / 65536)))
    if i + 2 <= #str - padding then
      table.insert(result, string.char(math.floor((n % 65536) / 256)))
    end
    if i + 3 <= #str - padding then
      table.insert(result, string.char(n % 256))
    end
  end

  return table.concat(result)
end

-- Check if a string is valid base64
function M.is_valid_base64(str)
  if #str < M.config.min_base64_length then
    return false
  end
  -- Must be multiple of 4 (with or without padding)
  if #str % 4 ~= 0 then
    return false
  end
  -- Check for valid base64 characters
  return str:match("^[A-Za-z0-9+/]+=*$") ~= nil
end

-- Decode and analyze content
function M.decode_and_analyze(encoded_str, context)
  local results = {
    encoded = encoded_str,
    decoded = nil,
    is_suspicious = false,
    suspicious_reasons = {},
    score = 0,
  }

  -- Try to decode
  local success, decoded = pcall(M.decode_base64, encoded_str)
  if not success or not decoded then
    return results
  end

  results.decoded = decoded

  -- Limit analysis length
  local analysis_str = decoded:sub(1, M.config.max_decode_length)

  -- Check for dangerous patterns in decoded content
  for _, pattern in ipairs(M.patterns.dangerous_patterns) do
    if analysis_str:match(pattern) then
      table.insert(results.suspicious_reasons, "Contains dangerous pattern: " .. pattern)
      results.score = results.score + 10
      results.is_suspicious = true
    end
  end

  -- Check for shell commands
  if analysis_str:match("bash") or analysis_str:match("sh%s") or analysis_str:match("cmd%.exe") then
    table.insert(results.suspicious_reasons, "Contains shell command references")
    results.score = results.score + 15
    results.is_suspicious = true
  end

  -- Check for network operations
  if analysis_str:match("http") or analysis_str:match("socket") or analysis_str:match("tcp") then
    table.insert(results.suspicious_reasons, "Contains network operation references")
    results.score = results.score + 8
    results.is_suspicious = true
  end

  -- Check for file operations
  if analysis_str:match("io%.") or analysis_str:match("file:") then
    table.insert(results.suspicious_reasons, "Contains file operation references")
    results.score = results.score + 5
    results.is_suspicious = true
  end

  -- Check if it looks like code vs data
  local code_indicators = 0
  if analysis_str:match("function") then
    code_indicators = code_indicators + 1
  end
  if analysis_str:match("local%s") then
    code_indicators = code_indicators + 1
  end
  if analysis_str:match("return%s") then
    code_indicators = code_indicators + 1
  end
  if analysis_str:match("if%s") or analysis_str:match("then") then
    code_indicators = code_indicators + 1
  end

  if code_indicators >= 2 then
    table.insert(results.suspicious_reasons, "Decoded content appears to be code")
    results.score = results.score + 10
    results.is_suspicious = true
  end

  return results
end

-- Detect base64 obfuscation
function M.detect_base64_obfuscation(content, filepath)
  local findings = {}

  -- Look for encoding function calls
  for _, pattern in ipairs(M.patterns.encoding_functions) do
    for match in content:gmatch(pattern) do
      table.insert(findings, {
        type = "encoding_function",
        pattern = pattern,
        match = match,
        severity = "MEDIUM",
        message = "Base64 encoding function detected",
        line = M.find_line_number(content, match),
      })
    end
  end

  -- Look for long base64 strings (more flexible pattern to catch padding)
  for potential_b64 in content:gmatch("[A-Za-z0-9+/=]+") do
    if #potential_b64 >= M.config.min_base64_length and M.is_valid_base64(potential_b64) then
      local analysis = M.decode_and_analyze(potential_b64, filepath)

      local severity = "LOW"
      if analysis.is_suspicious then
        severity = analysis.score > 20 and "HIGH" or "MEDIUM"
      end

      table.insert(findings, {
        type = "base64_encoded",
        encoded = potential_b64:sub(1, 100) .. (#potential_b64 > 100 and "..." or ""),
        decoded_preview = analysis.decoded and analysis.decoded:sub(1, 200) or nil,
        severity = severity,
        score = analysis.score,
        reasons = analysis.suspicious_reasons,
        message = "Base64 encoded string found" .. (analysis.is_suspicious and " - SUSPICIOUS CONTENT" or ""),
        line = M.find_line_number(content, potential_b64:sub(1, 50)),
      })
    end
  end

  return findings
end

-- Detect encryption and encoding patterns
function M.detect_encryption_patterns(content, filepath)
  local findings = {}

  -- Check for XOR operations
  for match in content:gmatch("bit%.bxor%s*%([^)]+%)") do
    table.insert(findings, {
      type = "xor_encoding",
      match = match,
      severity = "MEDIUM",
      message = "XOR encoding/obfuscation detected",
      line = M.find_line_number(content, match),
    })
  end

  for match in content:gmatch("bit32%.bxor%s*%([^)]+%)") do
    table.insert(findings, {
      type = "xor_encoding",
      match = match,
      severity = "MEDIUM",
      message = "XOR encoding/obfuscation detected (bit32)",
      line = M.find_line_number(content, match),
    })
  end

  -- Check for hex-encoded strings (multiple consecutive hex values)
  local hex_count = 0
  for _ in content:gmatch("0x[0-9a-fA-F]+") do
    hex_count = hex_count + 1
  end
  if hex_count > 10 then
    table.insert(findings, {
      type = "hex_encoding",
      count = hex_count,
      severity = "MEDIUM",
      message = "Multiple hex-encoded values detected (" .. hex_count .. " instances)",
      line = 0,
    })
  end

  -- Check for URL encoding
  local url_encoded_count = 0
  for _ in content:gmatch("%%[0-9a-fA-F][0-9a-fA-F]") do
    url_encoded_count = url_encoded_count + 1
  end
  if url_encoded_count >= 5 then
    table.insert(findings, {
      type = "url_encoding",
      count = url_encoded_count,
      severity = "LOW",
      message = "URL-encoded patterns detected (" .. url_encoded_count .. " instances)",
      line = 0,
    })
  end

  return findings
end

-- Detect code obfuscation techniques
function M.detect_code_obfuscation(content, filepath)
  local findings = {}
  local obfuscation_score = 0

  -- Count string.char usage
  local char_count = 0
  for match in content:gmatch("string%.char%s*%([%d,%s]+%)") do
    char_count = char_count + 1
    if char_count <= 3 then -- Only report first few instances
      table.insert(findings, {
        type = "string_char_obfuscation",
        match = match:sub(1, 100),
        severity = "MEDIUM",
        message = "String obfuscation via string.char detected",
        line = M.find_line_number(content, match:sub(1, 50)),
      })
    end
  end
  if char_count > 0 then
    obfuscation_score = obfuscation_score + math.min(char_count, 10)
  end

  -- Check for loadstring/load usage
  for _, pattern in ipairs({ "loadstring%s*%([^)]+%)", "load%s*%([^)]+%)" }) do
    for match in content:gmatch(pattern) do
      obfuscation_score = obfuscation_score + 5
      table.insert(findings, {
        type = "dynamic_code_loading",
        match = match:sub(1, 100),
        severity = "HIGH",
        message = "Dynamic code loading detected (loadstring/load)",
        line = M.find_line_number(content, match:sub(1, 50)),
      })
    end
  end

  -- Check for environment manipulation
  for _, pattern in ipairs({ "getfenv", "setfenv" }) do
    if content:match(pattern) then
      obfuscation_score = obfuscation_score + 3
      table.insert(findings, {
        type = "environment_manipulation",
        pattern = pattern,
        severity = "MEDIUM",
        message = "Environment manipulation detected (" .. pattern .. ")",
        line = M.find_line_number(content, pattern),
      })
    end
  end

  -- Check for dynamic function construction
  if content:match("_G%[") then
    obfuscation_score = obfuscation_score + 3
    table.insert(findings, {
      type = "dynamic_function_access",
      severity = "MEDIUM",
      message = "Dynamic global table access detected (_G[])",
      line = M.find_line_number(content, "_G%["),
    })
  end

  -- Check for excessive table manipulation (potential table-based code execution)
  local rawget_count = select(2, content:gsub("rawget", ""))
  local rawset_count = select(2, content:gsub("rawset", ""))
  if rawget_count + rawset_count >= 2 then
    obfuscation_score = obfuscation_score + 2
    table.insert(findings, {
      type = "table_manipulation",
      count = rawget_count + rawset_count,
      severity = "LOW",
      message = "Raw table manipulation detected (" .. (rawget_count + rawset_count) .. " instances)",
      line = 0,
    })
  end

  -- Add overall obfuscation score
  if obfuscation_score >= M.config.obfuscation_threshold then
    table.insert(findings, {
      type = "obfuscation_score",
      score = obfuscation_score,
      severity = obfuscation_score > 15 and "HIGH" or "MEDIUM",
      message = "High obfuscation score: " .. obfuscation_score,
      line = 0,
    })
  end

  return findings
end

-- Detect advanced threats
function M.detect_advanced_threats(content, filepath)
  local findings = {}

  -- Multi-stage payload indicators
  if content:match("require.*http") or content:match("curl.*loadstring") then
    table.insert(findings, {
      type = "multi_stage_payload",
      severity = "CRITICAL",
      message = "Potential multi-stage payload delivery detected",
      line = 0,
    })
  end

  -- Time-delayed execution
  for _, pattern in ipairs({ "vim%.defer_fn", "vim%.loop%.new_timer", "os%.time" }) do
    if content:match(pattern) and (content:match("loadstring") or content:match("io%.popen")) then
      table.insert(findings, {
        type = "time_delayed_execution",
        pattern = pattern,
        severity = "HIGH",
        message = "Potential time-delayed malicious execution",
        line = M.find_line_number(content, pattern),
      })
    end
  end

  -- Anti-debugging techniques
  if content:match("debug%.getinfo") or content:match("debug%.traceback") then
    table.insert(findings, {
      type = "anti_debugging",
      severity = "MEDIUM",
      message = "Potential anti-debugging technique detected",
      line = M.find_line_number(content, "debug%."),
    })
  end

  -- Environment fingerprinting
  local fingerprint_count = 0
  for _, pattern in ipairs({ "vim%.fn%.hostname", "vim%.loop%.os_uname", "os%.getenv", "vim%.env" }) do
    if content:match(pattern) then
      fingerprint_count = fingerprint_count + 1
    end
  end
  if fingerprint_count >= 2 then
    table.insert(findings, {
      type = "environment_fingerprinting",
      count = fingerprint_count,
      severity = "MEDIUM",
      message = "Environment fingerprinting detected (" .. fingerprint_count .. " indicators)",
      line = 0,
    })
  end

  -- Process spawning with dynamic content
  for _, pattern in ipairs(M.patterns.advanced_threats) do
    if content:match(pattern) and content:match("%.%.") then -- String concatenation nearby
      table.insert(findings, {
        type = "dynamic_process_spawn",
        pattern = pattern,
        severity = "HIGH",
        message = "Dynamic process spawning with constructed arguments",
        line = M.find_line_number(content, pattern),
      })
    end
  end

  -- Package/module manipulation
  if content:match("package%.loaded") or content:match("package%.preload") then
    table.insert(findings, {
      type = "package_manipulation",
      severity = "MEDIUM",
      message = "Package/module manipulation detected",
      line = M.find_line_number(content, "package%."),
    })
  end

  return findings
end

-- Helper function to find line number of a match
function M.find_line_number(content, search_str)
  local line = 1
  local pos = 1
  local search_pos = content:find(search_str, 1, true)

  if not search_pos then
    return 0
  end

  while pos < search_pos do
    local newline_pos = content:find("\n", pos, true)
    if not newline_pos or newline_pos > search_pos then
      break
    end
    line = line + 1
    pos = newline_pos + 1
  end

  return line
end

-- Main audit function
function M.audit_file(filepath)
  local file = io.open(filepath, "r")
  if not file then
    return { error = "Cannot open file: " .. filepath }
  end

  local content = file:read("*all")
  file:close()

  -- Skip if file is in whitelist
  for _, pattern in ipairs(M.config.whitelist) do
    if filepath:match(pattern) then
      return { skipped = true, reason = "whitelisted" }
    end
  end

  local results = {
    filepath = filepath,
    findings = {},
    summary = {
      total = 0,
      critical = 0,
      high = 0,
      medium = 0,
      low = 0,
    },
  }

  -- Run all detection functions
  local base64_findings = M.detect_base64_obfuscation(content, filepath)
  local encryption_findings = M.detect_encryption_patterns(content, filepath)
  local obfuscation_findings = M.detect_code_obfuscation(content, filepath)
  local advanced_findings = M.detect_advanced_threats(content, filepath)

  -- Combine all findings
  for _, finding in ipairs(base64_findings) do
    table.insert(results.findings, finding)
  end
  for _, finding in ipairs(encryption_findings) do
    table.insert(results.findings, finding)
  end
  for _, finding in ipairs(obfuscation_findings) do
    table.insert(results.findings, finding)
  end
  for _, finding in ipairs(advanced_findings) do
    table.insert(results.findings, finding)
  end

  -- Update summary
  results.summary.total = #results.findings
  for _, finding in ipairs(results.findings) do
    local severity = finding.severity:lower()
    if severity == "critical" then
      results.summary.critical = results.summary.critical + 1
    elseif severity == "high" then
      results.summary.high = results.summary.high + 1
    elseif severity == "medium" then
      results.summary.medium = results.summary.medium + 1
    elseif severity == "low" then
      results.summary.low = results.summary.low + 1
    end
  end

  return results
end

-- Audit directory recursively
function M.audit_directory(dirpath, options)
  options = options or {}
  local results = {}

  local function scan_dir(path)
    local handle = io.popen('find "' .. path .. '" -name "*.lua" -type f')
    if not handle then
      return
    end

    for file in handle:lines() do
      local audit_result = M.audit_file(file)
      if not audit_result.skipped and not audit_result.error then
        if #audit_result.findings > 0 then
          table.insert(results, audit_result)
        end
      end
    end
    handle:close()
  end

  scan_dir(dirpath)
  return results
end

-- Format results for display
function M.format_results(results)
  local output = {}

  table.insert(output, "=" .. string.rep("=", 78))
  table.insert(output, "NEOVIM SECURITY AUDIT - OBFUSCATION DETECTION")
  table.insert(output, "=" .. string.rep("=", 78))
  table.insert(output, "")

  if type(results) == "table" and results.filepath then
    results = { results }
  end

  for _, result in ipairs(results) do
    if #result.findings > 0 then
      table.insert(output, "File: " .. result.filepath)
      table.insert(output, string.rep("-", 79))

      for _, finding in ipairs(result.findings) do
        local severity_icon = "🔴"
        if finding.severity == "MEDIUM" then
          severity_icon = "🟡"
        elseif finding.severity == "LOW" then
          severity_icon = "🟢"
        elseif finding.severity == "CRITICAL" then
          severity_icon = "💀"
        end

        table.insert(output, "")
        table.insert(output, severity_icon .. " [" .. finding.severity .. "] " .. finding.type)
        table.insert(output, "  Message: " .. finding.message)
        if finding.line and finding.line > 0 then
          table.insert(output, "  Line: " .. finding.line)
        end
        if finding.match then
          table.insert(output, "  Match: " .. finding.match:sub(1, 100))
        end
        if finding.encoded then
          table.insert(output, "  Encoded: " .. finding.encoded)
        end
        if finding.decoded_preview then
          table.insert(output, "  Decoded: " .. finding.decoded_preview:sub(1, 200))
        end
        if finding.reasons then
          for _, reason in ipairs(finding.reasons) do
            table.insert(output, "  Reason: " .. reason)
          end
        end
        if finding.score then
          table.insert(output, "  Risk Score: " .. finding.score)
        end
      end

      table.insert(output, "")
      table.insert(output, "Summary: " .. result.summary.total .. " findings")
      table.insert(output, "  CRITICAL: " .. result.summary.critical)
      table.insert(output, "  HIGH: " .. result.summary.high)
      table.insert(output, "  MEDIUM: " .. result.summary.medium)
      table.insert(output, "  LOW: " .. result.summary.low)
      table.insert(output, "")
      table.insert(output, string.rep("=", 79))
      table.insert(output, "")
    end
  end

  return table.concat(output, "\n")
end

-- Load configuration from file
function M.load_config(config_path)
  local success, config = pcall(dofile, config_path)
  if success and config then
    M.config = vim.tbl_deep_extend("force", M.config, config)
  end
end

return M
