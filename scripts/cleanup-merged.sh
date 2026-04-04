#!/usr/bin/env bash
# cleanup-merged.sh — Remove stale worktrees and merged remote branches
#
# Usage: cleanup-merged.sh [--dry-run]
#
# Covers:
#   - DesktopMatePlus workspace root  (master)
#   - backend                         (master)
#   - nanoclaw                        (develop)  — skill/* excluded
#   - desktop-homunculus              (main)
#
# Only removes branches matching our naming convention:
#   feat|fix|docs|refactor|chore|test|ci|build|quality|design

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# FORMAT: repo_path|default_branch|skip_branch_pattern
REPOS=(
  "${WORKSPACE_ROOT}|master|"
  "${WORKSPACE_ROOT}/backend|master|"
  "${WORKSPACE_ROOT}/nanoclaw|develop|^skill/"
  "${WORKSPACE_ROOT}/desktop-homunculus|main|"
)

# Branch prefixes we own — never delete anything outside this set
OUR_PATTERN="^(feat|fix|docs|refactor|chore|test|ci|build|quality|design)/"

_run() {
  if $DRY_RUN; then
    echo "[dry-run] $*"
  else
    eval "$@"
  fi
}

for ENTRY in "${REPOS[@]}"; do
  IFS='|' read -r REPO_PATH DEFAULT_BRANCH SKIP_PATTERN <<< "$ENTRY"
  [[ -d "$REPO_PATH/.git" ]] || continue

  echo ""
  echo ">>> $REPO_PATH  (default: $DEFAULT_BRANCH)"

  # Fetch + prune so merged detection is up to date
  git -C "$REPO_PATH" fetch --prune origin 2>/dev/null || true

  MAIN_ABS="$(git -C "$REPO_PATH" rev-parse --show-toplevel)"

  # ── 1. Stale worktrees ─────────────────────────────────────────────────────
  while read -r wt_path wt_hash wt_ref; do
    [[ "$wt_path" == "$MAIN_ABS" ]] && continue          # skip main worktree
    branch="${wt_ref#refs/heads/}"

    # skip if not our naming convention
    [[ "$branch" =~ $OUR_PATTERN ]] || continue

    # skip if not yet merged
    if ! git -C "$REPO_PATH" branch -r --merged "$DEFAULT_BRANCH" \
        | grep -q "origin/${branch}$"; then
      echo "  skip worktree (not merged): $wt_path  [$branch]"
      continue
    fi

    echo "  remove worktree: $wt_path  [$branch]"
    _run "git -C '$REPO_PATH' worktree remove --force '$wt_path'"
  done < <(git -C "$REPO_PATH" worktree list \
    | awk '{path=$1; hash=$2; ref=$3} ref!="" {print path, hash, substr(ref,2,length(ref)-2)}')

  # ── 2. Merged remote branches ──────────────────────────────────────────────
  git -C "$REPO_PATH" branch -r --merged "$DEFAULT_BRANCH" \
    | grep -v 'HEAD' \
    | sed 's|^ *origin/||' \
    | grep -v "^${DEFAULT_BRANCH}$\|^master$\|^main$\|^develop$" \
    | while read -r branch; do
        # apply per-repo skip pattern (skill/* for nanoclaw)
        [[ -n "$SKIP_PATTERN" && "$branch" =~ $SKIP_PATTERN ]] && continue
        # only delete our branches
        [[ "$branch" =~ $OUR_PATTERN ]] || continue

        echo "  delete remote branch: $branch"
        _run "git -C '$REPO_PATH' push origin --delete '$branch'"
      done
done

echo ""
echo "cleanup-merged.sh done."
