#!/usr/bin/env bash
# For each dependent repo: clone, copy included files, push branch, create or update PR.
# Env: ORG, GH_TOKEN (not required if DRY_RUN=1), BRANCH, REPOS_LIST, FILES_LIST.
# Options: --dry-run (no clone/push/pr), --draft (create PR as draft).
# Usage: template-sync-push-pr.sh [--dry-run] [--draft]
set -euo pipefail

DRY_RUN="${DRY_RUN:-}"
DRAFT_PR="${DRAFT_PR:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --draft)   DRAFT_PR=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

ORG="${ORG:?ORG required}"
# GH_TOKEN required only when not dry-run
if [[ -z "${DRY_RUN}" ]]; then
  GH_TOKEN="${GH_TOKEN:?GH_TOKEN required}"
fi
BRANCH="${BRANCH:-chore/template-sync}"
REPOS_LIST="${REPOS_LIST:-}"
FILES_LIST="${FILES_LIST:-files_to_sync.txt}"

[[ -n "$REPOS_LIST" ]] || { echo "No dependent repos to sync."; exit 0; }
[[ -f "$FILES_LIST" ]] || { echo "Files list not found: $FILES_LIST" >&2; exit 1; }

for repo in $REPOS_LIST; do
  [[ -n "$repo" ]] || continue
  [[ "$repo" != "template-template" ]] || continue

  if [[ -n "${DRY_RUN}" ]]; then
    echo "--- [dry-run] Would sync to $ORG/$repo ---"
    echo "  Files:"
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      echo "    - $f"
    done < "$FILES_LIST"
    echo "  (no clone, push, or PR)"
    continue
  fi

  echo "--- Syncing to $ORG/$repo ---"
  rm -rf dest_repo
  git clone --depth 1 "https://x-access-token:${GH_TOKEN}@github.com/${ORG}/${repo}.git" dest_repo
  cd dest_repo
  git fetch origin "${BRANCH}" 2>/dev/null && git checkout "${BRANCH}" || git checkout -b "${BRANCH}"
  cd ..

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    mkdir -p "dest_repo/$(dirname "$f")"
    cp "$f" "dest_repo/$f" 2>/dev/null || true
  done < "$FILES_LIST"

  cd dest_repo
  git add -A
  if git diff --staged --quiet; then
    echo "  No changes for $repo"
    cd ..
    rm -rf dest_repo
    continue
  fi

  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git commit -m "chore(template): sync from $ORG/template-template"
  git push origin "${BRANCH}" --force

  DEFAULT_BASE=$(gh repo view "${ORG}/${repo}" --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "main")
  PR=$(gh pr list --repo "${ORG}/${repo}" --head "${BRANCH}" --json number -q '.[0].number' 2>/dev/null || true)
  if [[ -z "$PR" || "$PR" = "null" ]]; then
    if [[ -n "${DRAFT_PR}" ]]; then
      gh pr create --repo "${ORG}/${repo}" --base "${DEFAULT_BASE}" --head "${BRANCH}" \
        --title "chore(template): sync from template repository" \
        --body "Automated sync from $ORG/template-template. Merge when checks pass." \
        --draft
    else
      gh pr create --repo "${ORG}/${repo}" --base "${DEFAULT_BASE}" --head "${BRANCH}" \
        --title "chore(template): sync from template repository" \
        --body "Automated sync from $ORG/template-template. Merge when checks pass."
    fi
  else
    echo "  PR #$PR already open"
  fi

  cd ..
  rm -rf dest_repo
done

echo "Done."
