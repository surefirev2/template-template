#!/usr/bin/env bash
# Resolve template-sync config: repo list (literal + glob) and exclude_paths.
# Writes GITHUB_OUTPUT (repos_list, exclusions) and exclusions.txt in output dir.
# Usage: template-sync-resolve-config.sh [--config PATH] [--org ORG] [--out-dir DIR]
set -euo pipefail

CONFIG=".github/template-sync.yml"
ORG="${GITHUB_REPOSITORY_OWNER:-}"
OUT_DIR="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)  CONFIG="$2"; shift 2 ;;
    --org)     ORG="$2"; shift 2 ;;
    --out-dir) OUT_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$ORG" ]] || { echo "ORG required (--org or GITHUB_REPOSITORY_OWNER)" >&2; exit 1; }
[[ -f "$CONFIG" ]] || { echo "Config not found: $CONFIG" >&2; exit 1; }

# Parse repositories: literal names and glob patterns
REPOS_RAW=$(grep -A 100 '^repositories:' "$CONFIG" 2>/dev/null | grep -E '^\s*-\s*' | sed -E 's/^\s*-\s*"?([^"]+)"?.*/\1/' | tr '\n' ' ')
REPOS=""
for entry in $REPOS_RAW; do
  [[ -z "$entry" ]] && continue
  if echo "$entry" | grep -q '\*'; then
    re=$(echo "$entry" | sed 's/\*/.*/g')
    for name in $(gh repo list "$ORG" --limit 200 --json name -q '.[].name' 2>/dev/null || true); do
      echo "$name" | grep -qE "^${re}$" && REPOS="${REPOS} ${name}"
    done
  else
    REPOS="${REPOS} ${entry}"
  fi
done
REPOS=$(echo "$REPOS" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

# Parse exclude_paths
EXCLUSIONS=$(grep -A 200 '^exclude_paths:' "$CONFIG" 2>/dev/null | grep -E '^\s*-\s*' | sed -E 's/^\s*-\s*"?([^"]+)"?.*/\1/' | grep -v '^\s*$' || true)
mkdir -p "$OUT_DIR"
echo "$EXCLUSIONS" > "$OUT_DIR/exclusions.txt"

# GitHub Actions: write outputs
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "repos_list=$REPOS" >> "$GITHUB_OUTPUT"
  echo "exclusions<<EOF" >> "$GITHUB_OUTPUT"
  echo "$EXCLUSIONS" >> "$GITHUB_OUTPUT"
  echo "EOF" >> "$GITHUB_OUTPUT"
fi

echo "Resolved repos: ${REPOS:-none}"
