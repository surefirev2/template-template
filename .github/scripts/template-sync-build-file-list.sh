#!/usr/bin/env bash
# Build list of template files to sync (tracked files minus exclude_paths).
# Writes files_to_sync.txt and appends count to GITHUB_OUTPUT.
# Usage: template-sync-build-file-list.sh --exclusions-file PATH [--output FILE]
set -euo pipefail

EXCLUSIONS_FILE=""
OUTPUT_FILE="files_to_sync.txt"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --exclusions-file) EXCLUSIONS_FILE="$2"; shift 2 ;;
    --output)           OUTPUT_FILE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$EXCLUSIONS_FILE" ]] || { echo "--exclusions-file required" >&2; exit 1; }

git ls-files > all_files.txt

if [[ -s "$EXCLUSIONS_FILE" ]]; then
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    sed -i "\|^${path}$|d" all_files.txt 2>/dev/null || true
    sed -i "\|^${path}/|d" all_files.txt 2>/dev/null || true
  done < "$EXCLUSIONS_FILE"
fi

sort -u all_files.txt -o "$OUTPUT_FILE"
COUNT=$(wc -l < "$OUTPUT_FILE")

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "count=$COUNT" >> "$GITHUB_OUTPUT"
fi

echo "Files to sync: $COUNT"
