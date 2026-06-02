#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/lazy-network-audit.sh [full|changed] [--no-cache] [--include-urls] [--include-spawn]

Modes:
  full       Statically scan every installed lazy.nvim plugin.
  changed    Scan only plugins whose lazy-lock.json commit or installed plugin HEAD changed since the last network scan.

This is a static source scan of plugin code/config files. It does not monitor runtime network traffic.
By default it reports high-confidence network mechanisms, not every raw URL or generic process spawn.
Use --include-urls for raw URL inventory and --include-spawn for generic command-spawn review.
The script records scan state in .security-audit-cache/lazy-network-state.
EOF
}

mode="${1:-changed}"
no_cache=0
include_urls=0
include_spawn=0

args=()
for arg in "$@"; do
  case "$arg" in
    --no-cache) no_cache=1 ;;
    --include-urls) include_urls=1 ;;
    --include-spawn) include_spawn=1 ;;
    *) args+=("$arg") ;;
  esac
done

mode="${args[0]:-changed}"

case "$mode" in
  full|changed) ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

have() {
  command -v "$1" >/dev/null 2>&1
}

repo_root() {
  if have git && git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
  else
    pwd
  fi
}

root="$(repo_root)"
cd "$root"

lazy_root="${LAZY_NETWORK_AUDIT_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy}"
lockfile="${LAZY_NETWORK_AUDIT_LOCK:-$root/lazy-lock.json}"
cache_dir=".security-audit-cache"
state_file="$cache_dir/lazy-network-state"
current_fingerprint_file="$cache_dir/lazy-network-current"
previous_fingerprint_file="$cache_dir/lazy-network-previous"
lock_dir="$cache_dir/lazy-network.lock"

if [[ ! -d "$lazy_root" ]]; then
  echo "lazy-network-audit: lazy plugin directory not found: $lazy_root" >&2
  exit 1
fi

plugin_head() {
  local dir="$1"
  if [[ -d "$dir/.git" ]] && have git; then
    git -C "$dir" rev-parse HEAD 2>/dev/null || true
  fi
}

lock_commit_for() {
  local name="$1"
  if [[ -f "$lockfile" ]]; then
    sed -n "s/^  \"$name\": .*\"commit\": \"\\([^\"]*\\)\".*/\\1/p" "$lockfile" | head -n 1
  fi
}

write_current_fingerprint() {
  local output="$1"
  : > "$output"
  for dir in "$lazy_root"/*; do
    [[ -d "$dir" ]] || continue
    local name lock_commit head
    name="$(basename "$dir")"
    lock_commit="$(lock_commit_for "$name")"
    head="$(plugin_head "$dir")"
    printf '%s\t%s\t%s\n' "$name" "${lock_commit:-none}" "${head:-none}" >> "$output"
  done
  sort -o "$output" "$output"
}

mkdir -p "$cache_dir"
if ! mkdir "$lock_dir" 2>/dev/null; then
  echo "lazy-network-audit: another network audit is already running." >&2
  exit 1
fi
trap 'rm -rf "$lock_dir"' EXIT

write_current_fingerprint "$current_fingerprint_file"

declare -A plugins=()
if [[ "$mode" == "full" || "$no_cache" == 1 || ! -f "$state_file" || ! -f "$previous_fingerprint_file" ]]; then
  while IFS=$'\t' read -r name _ _; do
    plugins["$name"]=1
  done < "$current_fingerprint_file"
else
  while IFS=$'\t' read -r name _ _; do
    plugins["$name"]=1
  done < <(comm -13 "$previous_fingerprint_file" "$current_fingerprint_file")

  while IFS=$'\t' read -r name _ _; do
    if ! grep -q "^$name	" "$current_fingerprint_file"; then
      plugins["$name"]=1
    fi
  done < "$previous_fingerprint_file"
fi

if [[ ${#plugins[@]} -eq 0 ]]; then
  echo "lazy-network-audit: no lazy plugin changes since last recorded network scan."
  rm -f "$current_fingerprint_file"
  exit 0
fi

scan_plugin() {
  local name="$1"
  local dir="$lazy_root/$name"
  [[ -d "$dir" ]] || return 0

  local tmp
  tmp="$(mktemp)"

  rg -n \
    --glob '*.lua' --glob '*.vim' --glob '*.fnl' \
    --glob '*.js' --glob '*.jsx' --glob '*.ts' --glob '*.tsx' --glob '*.mjs' --glob '*.cjs' \
    --glob '*.json' --glob '*.toml' --glob '*.yaml' --glob '*.yml' \
    --glob '*.sh' --glob '*.py' --glob '*.rs' --glob '*.go' --glob '*.cs' \
    --glob '!**/.git/**' --glob '!**/node_modules/**' --glob '!**/target/**' --glob '!**/dist/**' --glob '!**/build/**' \
    --glob '!**/doc/**' --glob '!**/docs/**' --glob '!**/.github/**' --glob '!**/test/**' --glob '!**/tests/**' \
    --glob '!**/spec/**' --glob '!**/extra/**' --glob '!**/extras/**' --glob '!**/troubleshooting/**' --glob '!**/debug/**' \
    --glob '!README*' --glob '!CHANGELOG*' --glob '!LICENSE*' \
    --max-columns 300 --max-columns-preview \
    -e '\b(curl|wget|Invoke-WebRequest|iwr)\b' \
    -e '\b(fetch|request|get|post)\s*\([^)]*https?://' \
    -e '\b(plenary\.curl|nio\.curl|mason%-core%.fetch|mason-core\.fetch)\b' \
    -e '\b(socket\.http|socket\.tcp|luasocket|vim\.net|net\.request)\b' \
    "$dir" > "$tmp" || true

  if [[ "$include_spawn" == 1 ]]; then
    rg -n \
      --glob '*.lua' --glob '*.vim' --glob '*.fnl' \
      --glob '*.js' --glob '*.jsx' --glob '*.ts' --glob '*.tsx' --glob '*.mjs' --glob '*.cjs' \
      --glob '*.json' --glob '*.toml' --glob '*.yaml' --glob '*.yml' \
      --glob '*.sh' --glob '*.py' --glob '*.rs' --glob '*.go' --glob '*.cs' \
      --glob '!**/.git/**' --glob '!**/node_modules/**' --glob '!**/target/**' --glob '!**/dist/**' --glob '!**/build/**' \
      --glob '!**/doc/**' --glob '!**/docs/**' --glob '!**/.github/**' --glob '!**/test/**' --glob '!**/tests/**' \
      --glob '!**/spec/**' --glob '!**/extra/**' --glob '!**/extras/**' --glob '!**/troubleshooting/**' --glob '!**/debug/**' \
      --glob '!README*' --glob '!CHANGELOG*' --glob '!LICENSE*' \
      --max-columns 300 --max-columns-preview \
      -e '\b(vim\.system|vim\.fn\.system|jobstart|termopen)\b' \
      -e '\b(plenary\.job|Job:new|uv\.spawn|vim\.loop\.spawn|vim\.uv\.spawn)\b' \
      "$dir" >> "$tmp" || true
  fi

  if [[ "$include_urls" == 1 ]]; then
    rg -n \
      --glob '*.lua' --glob '*.vim' --glob '*.fnl' \
      --glob '*.js' --glob '*.jsx' --glob '*.ts' --glob '*.tsx' --glob '*.mjs' --glob '*.cjs' \
      --glob '*.json' --glob '*.toml' --glob '*.yaml' --glob '*.yml' \
      --glob '*.sh' --glob '*.py' --glob '*.rs' --glob '*.go' --glob '*.cs' \
      --glob '!**/.git/**' --glob '!**/node_modules/**' --glob '!**/target/**' --glob '!**/dist/**' --glob '!**/build/**' \
      --glob '!**/doc/**' --glob '!**/docs/**' --glob '!**/.github/**' --glob '!**/test/**' --glob '!**/tests/**' \
      --glob '!**/spec/**' --glob '!**/extra/**' --glob '!**/extras/**' --glob '!**/troubleshooting/**' --glob '!**/debug/**' \
      --glob '!README*' --glob '!CHANGELOG*' --glob '!LICENSE*' \
      --max-columns 300 --max-columns-preview \
      -e 'https?://[^"'\'' <>)`]+' \
      "$dir" >> "$tmp" || true
  fi

  if [[ -s "$tmp" ]]; then
    echo
    echo "==> [$name]"
    sed "s#^$dir/##" "$tmp"
  fi
  rm -f "$tmp"
}

matches=0
for name in "${!plugins[@]}"; do
  output="$(scan_plugin "$name")"
  if [[ -n "$output" ]]; then
    printf '%s\n' "$output"
    matches=$((matches + 1))
  fi
done

mv "$current_fingerprint_file" "$previous_fingerprint_file"
{
  echo "scanned_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "mode=$mode"
  echo "lazy_root=$lazy_root"
  echo "lockfile=$lockfile"
} > "$state_file"

echo
echo "lazy-network-audit: completed. $matches plugin(s) had static network-related matches."
