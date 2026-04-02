#!/usr/bin/env bash
# e2e.sh — workspace-level E2E verification pipeline
#
# Usage:
#   bash scripts/e2e.sh
#
# Runs sub-repo E2E scripts in order:
#   1. backend/scripts/e2e.sh   — required (fail-fast)
#   2. desktop-homunculus/scripts/e2e.sh — optional (CONDITIONAL TODO if absent)
#
# Note: UI browse verification (DH Agent browse protocol) is out of scope here.
# Shell-automatable phases only.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$WORKSPACE_ROOT"

BE_STATUS="SKIP"
DH_STATUS="SKIP"
OVERALL_PASS=true

# ---------------------------------------------------------------------------
# Backend E2E
# ---------------------------------------------------------------------------
echo ""
echo "=== [1/2] Backend E2E ==="
if bash backend/scripts/e2e.sh; then
    BE_STATUS="PASSED"
    echo "[ws-e2e] Backend E2E: PASSED"
else
    BE_STATUS="FAILED"
    OVERALL_PASS=false
    echo "[ws-e2e] Backend E2E: FAILED" >&2
fi

# ---------------------------------------------------------------------------
# Desktop-Homunculus E2E (conditional)
# ---------------------------------------------------------------------------
echo ""
echo "=== [2/2] Desktop-Homunculus E2E ==="
DH_E2E_SCRIPT="desktop-homunculus/scripts/e2e.sh"
if [[ -f "$DH_E2E_SCRIPT" ]]; then
    if bash "$DH_E2E_SCRIPT"; then
        DH_STATUS="PASSED"
        echo "[ws-e2e] DH E2E: PASSED"
    else
        DH_STATUS="FAILED"
        OVERALL_PASS=false
        echo "[ws-e2e] DH E2E: FAILED" >&2
    fi
else
    DH_STATUS="CONDITIONAL TODO"
    echo "[ws-e2e] $DH_E2E_SCRIPT not found — DH CONDITIONAL TODO"
    echo "[ws-e2e] Reason: desktop-homunculus standalone mode not yet verified (see DH-PROBE-1 / DH-E2E-1)"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=== Workspace E2E Summary ==="
printf "  %-28s %s\n" "Backend E2E"            "$BE_STATUS"
printf "  %-28s %s\n" "Desktop-Homunculus E2E" "$DH_STATUS"
echo ""
if $OVERALL_PASS; then
    echo "-> workspace e2e: PASSED"
    exit 0
else
    echo "-> workspace e2e: FAILED"
    exit 1
fi
