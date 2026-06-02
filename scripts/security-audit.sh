#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/security-audit.sh [full|changed] [--no-cache]

Modes:
  full       Scan every supported package manifest/lockfile below the repo root.
  changed    Scan only package areas changed since the last recorded full/changed scan.

The script records scan state in .security-audit-cache/state.
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

cache_dir=".security-audit-cache"
state_file="$cache_dir/state"

current_commit="nogit"
if have git && git rev-parse HEAD >/dev/null 2>&1; then
  current_commit="$(git rev-parse HEAD)"
fi

previous_commit=""
if [[ -f "$state_file" ]]; then
  previous_commit="$(sed -n 's/^commit=//p' "$state_file" | head -n 1)"
fi

exclude_find=(
  -path "./.git" -o
  -path "./node_modules" -o
  -path "./vendor" -o
  -path "./target" -o
  -path "./build" -o
  -path "./dist" -o
  -path "./.dart_tool" -o
  -path "./.venv" -o
  -path "./venv" -o
  -path "./.security-audit-cache"
)

find_files() {
  find . \( "${exclude_find[@]}" \) -prune -o -type f \( "$@" \) -print | sed 's#^\./##' | sort -u
}

all_package_files() {
  find_files \
    -name package-lock.json -o -name package.json -o -name pnpm-lock.yaml -o -name yarn.lock -o -name bun.lockb -o \
    -name Cargo.lock -o -name Cargo.toml -o \
    -name requirements.txt -o -name 'requirements-*.txt' -o -name pyproject.toml -o -name poetry.lock -o -name uv.lock -o -name Pipfile.lock -o \
    -name pubspec.yaml -o -name pubspec.lock -o \
    -name go.mod -o -name go.sum -o \
    -name composer.lock -o -name Gemfile.lock -o \
    -name packages.lock.json -o -name '*.csproj'
}

changed_package_files() {
  if [[ "$mode" == "full" || "$no_cache" == 1 || -z "$previous_commit" || "$previous_commit" == "nogit" || "$current_commit" == "nogit" ]]; then
    all_package_files
    return
  fi

  if ! git cat-file -e "$previous_commit^{commit}" >/dev/null 2>&1; then
    all_package_files
    return
  fi

  git diff --name-only "$previous_commit" "$current_commit" -- \
    'package-lock.json' 'package.json' 'pnpm-lock.yaml' 'yarn.lock' 'bun.lockb' \
    'Cargo.lock' 'Cargo.toml' \
    'requirements*.txt' 'pyproject.toml' 'poetry.lock' 'uv.lock' 'Pipfile.lock' \
    'pubspec.yaml' 'pubspec.lock' \
    'go.mod' 'go.sum' \
    'composer.lock' 'Gemfile.lock' \
    'packages.lock.json' '*.csproj' | sort -u
}

declare -A dirs=()
while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  dirs["$(dirname "$file")"]=1
done < <(changed_package_files)

if [[ ${#dirs[@]} -eq 0 ]]; then
  if [[ "$mode" == "full" ]]; then
    echo "security-audit: no supported package manifests or lockfiles found."
  else
    echo "security-audit: no package manifest or lockfile changes since ${previous_commit:-<none>}."
  fi
  exit 0
fi

failures=0
skips=0

run_check() {
  local dir="$1"
  shift
  echo
  echo "==> [$dir] $*"
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
  echo "==> [$dir] skipped: $msg"
}

has_file() {
  local dir="$1"
  local name="$2"
  [[ -f "$dir/$name" ]]
}

run_osv_if_available() {
  local dir="$1"
  if have osv-scanner; then
    run_check "$dir" osv-scanner --lockfile=. || true
  fi
}

for dir in "${!dirs[@]}"; do
  [[ "$dir" == "." ]] || [[ -d "$dir" ]] || continue

  run_osv_if_available "$dir"

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

mkdir -p "$cache_dir"
{
  echo "commit=$current_commit"
  echo "scanned_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "mode=$mode"
} > "$state_file"

echo
echo "security-audit: completed with $failures failing check(s), $skips skipped check(s)."
if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
