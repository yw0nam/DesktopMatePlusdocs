#!/usr/bin/env bash
# tests/scripts/test-cleanup-merged.sh — Smoke tests for cleanup-merged.sh
#
# Usage: bash tests/scripts/test-cleanup-merged.sh
# Exit 0 = all pass, non-zero = failures

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLEANUP="${SCRIPT_DIR}/scripts/cleanup-merged.sh"
ERRORS=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; echo "  $2"; ERRORS=$((ERRORS + 1)); }

# ── Test 1: --dry-run exits cleanly and prints done message ──────────────────
OUTPUT=$(bash "$CLEANUP" --dry-run 2>&1)
if echo "$OUTPUT" | grep -q "cleanup-merged.sh done."; then
  pass "--dry-run exits cleanly"
else
  fail "--dry-run exits cleanly" "expected 'cleanup-merged.sh done.' in output"
fi

# ── Test 2: our branch pattern matches expected prefixes ─────────────────────
OUR_PATTERN="^(feat|fix|docs|refactor|chore|test|ci|build|quality|design)/"
for branch in feat/foo fix/bar docs/update refactor/thing quality/report-2026; do
  if [[ "$branch" =~ $OUR_PATTERN ]]; then
    pass "our pattern matches: $branch"
  else
    fail "our pattern matches: $branch" "'$branch' should match OUR_PATTERN"
  fi
done

# ── Test 3: non-ours are rejected ────────────────────────────────────────────
for branch in main master develop upstream/something random-branch; do
  if [[ ! "$branch" =~ $OUR_PATTERN ]]; then
    pass "non-ours rejected: $branch"
  else
    fail "non-ours rejected: $branch" "'$branch' should NOT match OUR_PATTERN"
  fi
done

# ── Test 4: skill/* pattern is caught by nanoclaw skip filter ────────────────
SKIP_PATTERN="^skill/"
for branch in skill/backend-http skill/knowledge-base-volume; do
  if [[ "$branch" =~ $SKIP_PATTERN ]]; then
    pass "skill/* excluded: $branch"
  else
    fail "skill/* excluded: $branch" "'$branch' should match SKIP_PATTERN"
  fi
done

# ── Test 5: skill/* would otherwise match OUR_PATTERN (it doesn't — confirm) ─
for branch in skill/backend-http; do
  if [[ ! "$branch" =~ $OUR_PATTERN ]]; then
    pass "skill/* not in OUR_PATTERN: $branch"
  else
    fail "skill/* not in OUR_PATTERN: $branch" "skill/ should not be in OUR_PATTERN"
  fi
done

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if [[ $ERRORS -eq 0 ]]; then
  echo "All tests passed."
  exit 0
else
  echo "$ERRORS test(s) failed."
  exit 1
fi
