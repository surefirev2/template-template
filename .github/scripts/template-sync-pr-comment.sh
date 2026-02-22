#!/usr/bin/env bash
# Upsert a sticky comment on a PR with template sync preview (target repos, file list, and diff of synced files).
# Env: GH_TOKEN (or gh auth), REPOS (space-separated), COUNT (file count), FILES_LIST (path to file),
#      DIFF_FILE (optional path to diff of synced files, e.g. from git diff base head -- $(cat FILES_LIST)).
# Usage: template-sync-pr-comment.sh <pr_number> [--repo OWNER/REPO]
set -euo pipefail

PR_NUMBER=""
REPO="${GITHUB_REPOSITORY:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="$2"; shift 2 ;;
    *)      PR_NUMBER="$1"; shift ;;
  esac
done

[[ -n "$PR_NUMBER" ]] || { echo "PR number required" >&2; exit 1; }
[[ -n "$REPO" ]] || { echo "GITHUB_REPOSITORY or --repo required" >&2; exit 1; }

REPOS="${REPOS:-none}"
COUNT="${COUNT:-0}"
FILES_LIST="${FILES_LIST:-files_to_sync.txt}"
DIFF_FILE="${DIFF_FILE:-}"
# GitHub issue comment body limit is 65536 characters; leave headroom for markdown
MAX_DIFF_CHARS=60000
MARKER="<!-- template-sync-preview -->"

BODY_FILE=$(mktemp)
trap 'rm -f "$BODY_FILE"' EXIT

{
  echo "## Template sync preview"
  echo ""
  echo "If this PR is merged, the next sync will affect:"
  echo ""
  echo "**Target repositories:** \`${REPOS}\`"
  echo ""
  echo "**Files to sync:** $COUNT"
  if [[ -f "$FILES_LIST" && -s "$FILES_LIST" ]]; then
    echo ""
    echo "<details><summary>File list</summary>"
    echo ""
    echo '```'
    cat "$FILES_LIST"
    echo '```'
    echo ""
    echo "</details>"
  fi
  if [[ -n "$DIFF_FILE" && -f "$DIFF_FILE" && -s "$DIFF_FILE" ]]; then
    echo ""
    echo "<details><summary>Diff of synced files (base → PR head)</summary>"
    echo ""
    echo '```diff'
    if [[ $(wc -c < "$DIFF_FILE") -gt $MAX_DIFF_CHARS ]]; then
      head -c "$MAX_DIFF_CHARS" "$DIFF_FILE"
      echo ""
      echo "... (truncated)"
    else
      cat "$DIFF_FILE"
    fi
    echo '```'
    echo ""
    echo "</details>"
  fi
  echo ""
  echo "*Actual sync runs only on push to \`main\`.*"
  echo ""
  echo "$MARKER"
} > "$BODY_FILE"

COMMENT_ID=$(gh api "repos/${REPO}/issues/${PR_NUMBER}/comments" \
  --jq ".[] | select(.user.login == \"github-actions[bot]\" and (.body | contains(\"$MARKER\"))) | .id" 2>/dev/null | head -1)

if [[ -n "$COMMENT_ID" ]]; then
  jq -n --rawfile b "$BODY_FILE" '{body: $b}' | gh api -X PATCH "repos/${REPO}/issues/comments/${COMMENT_ID}" --input -
  echo "Updated existing template sync preview comment."
else
  gh pr comment "$PR_NUMBER" --repo "$REPO" --body-file "$BODY_FILE"
  echo "Posted new template sync preview comment."
fi
