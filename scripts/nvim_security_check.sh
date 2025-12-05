#!/bin/bash

# Neovim Security Check Script
# Shell-based encoding and obfuscation detection

NVIM_DIR="${1:-.}"
REPORT_FILE="${2:-security_report.txt}"

echo "========================================="
echo "Neovim Security Check - Shell Edition"
echo "========================================="
echo ""
echo "Scanning directory: $NVIM_DIR"
echo "Report file: $REPORT_FILE"
echo ""

# Initialize report
cat > "$REPORT_FILE" << EOF
NEOVIM SECURITY CHECK REPORT
Generated: $(date)
Directory: $NVIM_DIR
================================================================================

EOF

# Counter for findings
TOTAL_FINDINGS=0
CRITICAL_FINDINGS=0
HIGH_FINDINGS=0

# Function to add finding to report
add_finding() {
  local severity=$1
  local file=$2
  local line=$3
  local message=$4
  local context=$5

  echo "" >> "$REPORT_FILE"
  echo "[$severity] $message" >> "$REPORT_FILE"
  echo "  File: $file" >> "$REPORT_FILE"
  echo "  Line: $line" >> "$REPORT_FILE"
  if [ -n "$context" ]; then
    echo "  Context: $context" >> "$REPORT_FILE"
  fi
  
  TOTAL_FINDINGS=$((TOTAL_FINDINGS + 1))
  
  case $severity in
    CRITICAL)
      CRITICAL_FINDINGS=$((CRITICAL_FINDINGS + 1))
      ;;
    HIGH)
      HIGH_FINDINGS=$((HIGH_FINDINGS + 1))
      ;;
  esac
}

# Check 1: Base64 encoded strings
echo "[*] Checking for base64 encoded strings..."
while IFS= read -r file; do
  if [ -f "$file" ]; then
    # Look for long base64 strings (50+ chars)
    grep -nE '[A-Za-z0-9+/]{50,}={0,2}' "$file" 2>/dev/null | while IFS=: read -r line_num match; do
      # Try to decode and check for suspicious content
      decoded=$(echo "$match" | grep -oE '[A-Za-z0-9+/]{50,}={0,2}' | head -1 | base64 -d 2>/dev/null || echo "")
      
      if [ -n "$decoded" ]; then
        # Check for dangerous patterns in decoded content
        if echo "$decoded" | grep -qE '(curl|wget|bash|sh |io\.popen|os\.execute|system)'; then
          add_finding "CRITICAL" "$file" "$line_num" "Base64 encoded malicious content detected" "$decoded"
        elif echo "$decoded" | grep -qE '(http://|https://|function|local |require)'; then
          add_finding "HIGH" "$file" "$line_num" "Base64 encoded suspicious content" "$(echo "$decoded" | head -c 100)"
        fi
      fi
    done
  fi
done < <(find "$NVIM_DIR" -type f -name "*.lua")

# Check 2: Encoding functions
echo "[*] Checking for encoding/decoding functions..."
while IFS= read -r file; do
  if [ -f "$file" ]; then
    grep -nE '(base64encode|base64decode|vim\.fn\.base64)' "$file" 2>/dev/null | while IFS=: read -r line_num match; do
      add_finding "MEDIUM" "$file" "$line_num" "Base64 encoding function usage" "$match"
    done
  fi
done < <(find "$NVIM_DIR" -type f -name "*.lua")

# Check 3: XOR operations (obfuscation indicator)
echo "[*] Checking for XOR operations..."
while IFS= read -r file; do
  if [ -f "$file" ]; then
    grep -nE '(bit\.bxor|bit32\.bxor)' "$file" 2>/dev/null | while IFS=: read -r line_num match; do
      add_finding "MEDIUM" "$file" "$line_num" "XOR operation detected (possible obfuscation)" "$match"
    done
  fi
done < <(find "$NVIM_DIR" -type f -name "*.lua")

# Check 4: Excessive string.char usage (obfuscation)
echo "[*] Checking for string obfuscation..."
while IFS= read -r file; do
  if [ -f "$file" ]; then
    char_count=$(grep -o 'string\.char' "$file" 2>/dev/null | wc -l)
    if [ "$char_count" -gt 5 ]; then
      add_finding "MEDIUM" "$file" "multiple" "Excessive string.char usage ($char_count instances)" ""
    fi
  fi
done < <(find "$NVIM_DIR" -type f -name "*.lua")

# Check 5: Dynamic code loading
echo "[*] Checking for dynamic code loading..."
while IFS= read -r file; do
  if [ -f "$file" ]; then
    grep -nE '(loadstring|load\()' "$file" 2>/dev/null | while IFS=: read -r line_num match; do
      add_finding "HIGH" "$file" "$line_num" "Dynamic code loading detected" "$match"
    done
  fi
done < <(find "$NVIM_DIR" -type f -name "*.lua")

# Check 6: Environment manipulation
echo "[*] Checking for environment manipulation..."
while IFS= read -r file; do
  if [ -f "$file" ]; then
    grep -nE '(getfenv|setfenv)' "$file" 2>/dev/null | while IFS=: read -r line_num match; do
      add_finding "MEDIUM" "$file" "$line_num" "Environment manipulation detected" "$match"
    done
  fi
done < <(find "$NVIM_DIR" -type f -name "*.lua")

# Check 7: Hex-encoded values (excessive)
echo "[*] Checking for hex encoding patterns..."
while IFS= read -r file; do
  if [ -f "$file" ]; then
    hex_count=$(grep -o '0x[0-9a-fA-F]\+' "$file" 2>/dev/null | wc -l)
    if [ "$hex_count" -gt 15 ]; then
      add_finding "MEDIUM" "$file" "multiple" "Excessive hex-encoded values ($hex_count instances)" ""
    fi
  fi
done < <(find "$NVIM_DIR" -type f -name "*.lua")

# Check 8: Process spawning with dynamic arguments
echo "[*] Checking for dynamic process spawning..."
while IFS= read -r file; do
  if [ -f "$file" ]; then
    grep -nE '(vim\.loop\.spawn|vim\.uv\.spawn|vim\.fn\.jobstart)' "$file" 2>/dev/null | while IFS=: read -r line_num match; do
      # Check if there's string concatenation nearby (within 2 lines)
      context=$(sed -n "$((line_num-1)),$((line_num+1))p" "$file" 2>/dev/null)
      if echo "$context" | grep -qE '\.\.'; then
        add_finding "HIGH" "$file" "$line_num" "Dynamic process spawning with constructed arguments" "$match"
      fi
    done
  fi
done < <(find "$NVIM_DIR" -type f -name "*.lua")

# Check 9: Suspicious network operations
echo "[*] Checking for network operations..."
while IFS= read -r file; do
  if [ -f "$file" ]; then
    grep -nE '(curl|wget|http://|https://)' "$file" 2>/dev/null | while IFS=: read -r line_num match; do
      # Check if combined with code execution
      context=$(sed -n "$((line_num-2)),$((line_num+2))p" "$file" 2>/dev/null)
      if echo "$context" | grep -qE '(loadstring|io\.popen|os\.execute)'; then
        add_finding "CRITICAL" "$file" "$line_num" "Network operation with code execution" "$match"
      fi
    done
  fi
done < <(find "$NVIM_DIR" -type f -name "*.lua")

# Check 10: Package manipulation
echo "[*] Checking for package manipulation..."
while IFS= read -r file; do
  if [ -f "$file" ]; then
    grep -nE 'package\.(loaded|preload)' "$file" 2>/dev/null | while IFS=: read -r line_num match; do
      add_finding "MEDIUM" "$file" "$line_num" "Package manipulation detected" "$match"
    done
  fi
done < <(find "$NVIM_DIR" -type f -name "*.lua")

# Add summary to report
# Count findings from the report file itself
CRITICAL_COUNT=$(grep "^\[CRITICAL\]" "$REPORT_FILE" 2>/dev/null | wc -l)
HIGH_COUNT=$(grep "^\[HIGH\]" "$REPORT_FILE" 2>/dev/null | wc -l)
MEDIUM_COUNT=$(grep "^\[MEDIUM\]" "$REPORT_FILE" 2>/dev/null | wc -l)
LOW_COUNT=$(grep "^\[LOW\]" "$REPORT_FILE" 2>/dev/null | wc -l)
TOTAL_COUNT=$((CRITICAL_COUNT + HIGH_COUNT + MEDIUM_COUNT + LOW_COUNT))

cat >> "$REPORT_FILE" << EOF

================================================================================
SUMMARY
================================================================================
Total Findings: $TOTAL_COUNT
  CRITICAL: $CRITICAL_COUNT
  HIGH: $HIGH_COUNT
  MEDIUM: $MEDIUM_COUNT
  LOW: $LOW_COUNT

EOF

if [ "$TOTAL_COUNT" -eq 0 ]; then
  echo "" >> "$REPORT_FILE"
  echo "✅ No security issues detected!" >> "$REPORT_FILE"
  echo ""
  echo "✅ No security issues detected!"
else
  echo ""
  echo "⚠️  Found $TOTAL_COUNT potential security issues"
  echo "    CRITICAL: $CRITICAL_COUNT"
  echo "    HIGH: $HIGH_COUNT"
  echo ""
  echo "See $REPORT_FILE for details"
fi

echo ""
echo "Security check complete!"

exit 0
