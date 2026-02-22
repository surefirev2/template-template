# Template sync: push-based flow that opens PRs

## Implementation

Template sync is implemented as a **push-based flow that opens PRs** (Option B):

- **Trigger:** Push to `main` (and optionally `pull_request` for dry-run) in the template repo.
- **Workflow:** [.github/workflows/sync.yaml](../.github/workflows/sync.yaml) runs in the template repo. It reads [.github/template-sync.yml](../.github/template-sync.yml) for:
  - **Repos:** `repositories` lists exact repo names and/or glob patterns (e.g. `template-1-*`); patterns are resolved via `gh repo list`.
  - **Files:** `exclude_paths` lists paths to exclude from sync (blacklist); all other tracked files are synced.
- **Behavior:** For each dependent repo, the workflow clones the repo, copies the included files from the template into branch `chore/template-sync`, pushes the branch, and creates a pull request (or updates the existing PR if one is already open for that branch). There is **no direct push to the default branch** of dependents.
- **Result:** Each dependent gets a PR; required status checks (e.g. pre-commit) run on the PR. Merge is manual or can be automated later. **No automerge workflow** is provided for these template-sync PRs.

## Config

- **.github/template-sync.yml:**
  - `repositories`: list of downstream repo names and/or glob patterns (e.g. `template-1-*`, `template-cursor`). Patterns are resolved against the org; exact names are used as-is.
  - `exclude_paths`: paths in the template repo that are not synced to dependents (blacklist).

## Permissions

The GitHub App token used by the workflow must have on each dependent repo at least:

- `contents: write` (create branch, push commits).
- `pull_requests: write` (create and update PRs).
