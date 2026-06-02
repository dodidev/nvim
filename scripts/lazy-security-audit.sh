#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/lazy-security-audit.sh [full|changed] [--no-cache]

Modes:
  full       Scan every installed lazy.nvim plugin that contains a supported package manifest.
  changed    Scan only installed plugins whose lazy-lock.json commit or plugin HEAD changed since the last scan.

The script records scan state in .security-audit-cache/lazy-state.
It never installs tools. Missing tools are reported as skipped checks.
EOF
}

mode="${1:-changed}"
no_cache=0
if [[ "${2:-}" == "--no-cache" || "${1:-}" == "--no-cache" ]]; then
  no_cache=1
  [[ "$mode" == "--no-cache" ]] && mode="changed"
fi

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

lazy_root="${LAZY_SECURITY_AUDIT_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy}"
lockfile="${LAZY_SECURITY_AUDIT_LOCK:-$root/lazy-lock.json}"
cache_dir=".security-audit-cache"
state_file="$cache_dir/lazy-state"
current_fingerprint_file="$cache_dir/lazy-current"
previous_fingerprint_file="$cache_dir/lazy-previous"

if [[ ! -d "$lazy_root" ]]; then
  echo "lazy-security-audit: lazy plugin directory not found: $lazy_root" >&2
  exit 1
fi

manifest_names=(
  package-lock.json package.json pnpm-lock.yaml yarn.lock bun.lockb
  Cargo.lock Cargo.toml
  requirements.txt pyproject.toml poetry.lock uv.lock Pipfile.lock
  pubspec.yaml pubspec.lock
  go.mod go.sum
  composer.lock Gemfile.lock
  packages.lock.json
)

plugin_has_manifest() {
  local dir="$1"
  find "$dir" \
    -path "$dir/.git" -prune -o \
    -path "$dir/node_modules" -prune -o \
    -path "$dir/vendor" -prune -o \
    -path "$dir/target" -prune -o \
    -path "$dir/build" -prune -o \
    -path "$dir/dist" -prune -o \
    -type f \( \
      -name package-lock.json -o -name package.json -o -name pnpm-lock.yaml -o -name yarn.lock -o -name bun.lockb -o \
      -name Cargo.lock -o -name Cargo.toml -o \
      -name requirements.txt -o -name 'requirements-*.txt' -o -name pyproject.toml -o -name poetry.lock -o -name uv.lock -o -name Pipfile.lock -o \
      -name pubspec.yaml -o -name pubspec.lock -o \
      -name go.mod -o -name go.sum -o \
      -name composer.lock -o -name Gemfile.lock -o \
      -name packages.lock.json -o -name '*.csproj' \
    \) -print -quit | grep -q .
}

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
    local name
    name="$(basename "$dir")"
    local lock_commit head
    lock_commit="$(lock_commit_for "$name")"
    head="$(plugin_head "$dir")"
    printf '%s\t%s\t%s\n' "$name" "${lock_commit:-none}" "${head:-none}" >> "$output"
  done
  sort -o "$output" "$output"
}

mkdir -p "$cache_dir"
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
  echo "lazy-security-audit: no lazy plugin changes since last recorded scan."
  rm -f "$current_fingerprint_file"
  exit 0
fi

failures=0
skips=0
scanned=0

run_check() {
  local dir="$1"
  shift
  echo
  echo "==> [$(basename "$dir")] $*"
  if (cd "$dir" && "$@"); then
    return 0
  fi
  failures=$((failures + 1))
  return 1
}

skip_check() {
  local dir="$1"
  local msg="$2"
  skips=$((skips + 1))
  echo
  echo "==> [$(basename "$dir")] skipped: $msg"
}

has_file() {
  local dir="$1"
  local name="$2"
  [[ -f "$dir/$name" ]]
}

for name in "${!plugins[@]}"; do
  dir="$lazy_root/$name"
  [[ -d "$dir" ]] || continue
  if ! plugin_has_manifest "$dir"; then
    continue
  fi

  scanned=$((scanned + 1))

  if have osv-scanner; then
    run_check "$dir" osv-scanner --lockfile=. || true
  fi

  if has_file "$dir" package-lock.json; then
    if have npm; then
      run_check "$dir" npm audit --audit-level=moderate || true
    else
      skip_check "$dir" "npm not found for package-lock.json"
    fi
  elif has_file "$dir" pnpm-lock.yaml; then
    if have pnpm; then
      run_check "$dir" pnpm audit --audit-level moderate || true
    else
      skip_check "$dir" "pnpm not found for pnpm-lock.yaml"
    fi
  elif has_file "$dir" yarn.lock; then
    if have yarn; then
      run_check "$dir" yarn npm audit --severity moderate || run_check "$dir" yarn audit || true
    else
      skip_check "$dir" "yarn not found for yarn.lock"
    fi
  elif has_file "$dir" bun.lockb; then
    if have bun; then
      run_check "$dir" bun audit || true
    else
      skip_check "$dir" "bun not found for bun.lockb"
    fi
  fi

  if has_file "$dir" Cargo.lock || has_file "$dir" Cargo.toml; then
    if have cargo-audit; then
      run_check "$dir" cargo audit || true
    else
      skip_check "$dir" "cargo-audit not found for Cargo project"
    fi
  fi

  if has_file "$dir" requirements.txt || compgen -G "$dir/requirements-*.txt" >/dev/null || has_file "$dir" pyproject.toml || has_file "$dir" poetry.lock || has_file "$dir" uv.lock || has_file "$dir" Pipfile.lock; then
    if have pip-audit; then
      if has_file "$dir" requirements.txt; then
        run_check "$dir" pip-audit -r requirements.txt || true
      else
        run_check "$dir" pip-audit || true
      fi
    else
      skip_check "$dir" "pip-audit not found for Python project"
    fi
  fi

  if has_file "$dir" pubspec.yaml || has_file "$dir" pubspec.lock; then
    if have dart; then
      run_check "$dir" dart pub outdated || true
    elif have flutter; then
      run_check "$dir" flutter pub outdated || true
    else
      skip_check "$dir" "dart/flutter not found for Dart/Flutter project"
    fi
  fi

  if has_file "$dir" go.sum || has_file "$dir" go.mod; then
    if have govulncheck; then
      run_check "$dir" govulncheck ./... || true
    else
      skip_check "$dir" "govulncheck not found for Go project"
    fi
  fi

  if has_file "$dir" composer.lock; then
    if have composer; then
      run_check "$dir" composer audit || true
    else
      skip_check "$dir" "composer not found for composer.lock"
    fi
  fi

  if has_file "$dir" Gemfile.lock; then
    if have bundle-audit; then
      run_check "$dir" bundle-audit check --update || true
    else
      skip_check "$dir" "bundle-audit not found for Gemfile.lock"
    fi
  fi

  if has_file "$dir" packages.lock.json || compgen -G "$dir/*.csproj" >/dev/null; then
    if have dotnet; then
      run_check "$dir" dotnet list package --vulnerable --include-transitive || true
    else
      skip_check "$dir" "dotnet not found for .NET project"
    fi
  fi
done

mv "$current_fingerprint_file" "$previous_fingerprint_file"
{
  echo "scanned_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "mode=$mode"
  echo "lazy_root=$lazy_root"
  echo "lockfile=$lockfile"
} > "$state_file"

if [[ "$scanned" -eq 0 ]]; then
  echo "lazy-security-audit: selected lazy plugins have no supported package manifests."
else
  echo
  echo "lazy-security-audit: scanned $scanned plugin(s), $failures failing check(s), $skips skipped check(s)."
fi

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
