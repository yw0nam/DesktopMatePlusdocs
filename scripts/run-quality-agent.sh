#!/usr/bin/env bash
# run-quality-agent.sh — quality-agent를 claude -p로 로컬 실행
# Branch 생성, 보고서 작성, PR 생성은 quality-agent가 직접 수행한다.
# crontab: 7 9 * * * bash /home/spow12/codes/2025_lower/DesktopMatePlus/scripts/run-quality-agent.sh

set -euo pipefail

# ── PATH: ensure uv and other user-installed tools are available ───
# Required for cron runs where PATH is minimal
export PATH="$HOME/.local/bin:$HOME/anaconda3/bin:$HOME/.cargo/bin:$PATH"

CLAUDE_BIN="/home/spow12/.local/bin/claude"
WORKSPACE="/home/spow12/codes/2025_lower/DesktopMatePlus"
LOG_DIR="$WORKSPACE/docs/reports"
DATE=$(date +%Y-%m-%d)
BRANCH="quality/report-${DATE}"

cd "$WORKSPACE"

# ── cleanup trap: 실패 시 브랜치 정리 ────────────────────────────────
cleanup() {
  local exit_code=$?
  if [ $exit_code -ne 0 ]; then
    echo "[$(date)] ERROR: run-quality-agent.sh failed (exit $exit_code)" >> "$LOG_DIR/cron.log"
    # 현재 브랜치가 quality 브랜치면 master로 복귀 후 삭제
    if git rev-parse --abbrev-ref HEAD | grep -q "^quality/"; then
      git checkout master 2>/dev/null || true
      git branch -D "$BRANCH" 2>/dev/null || true
    fi
  fi
}
trap cleanup EXIT

# ── quality-agent 실행 ───────────────────────────────────────────────
# Branch 생성 / 보고서 작성 / commit / push / PR 생성은 agent 내부에서 수행.
# .claude/agents/quality-agent.md의 Step 0~6 순서를 따른다.
"$CLAUDE_BIN" -p "
You are the quality-agent for this workspace. Follow .claude/agents/quality-agent.md exactly (Step 0 through Step 6 in order).

Step 0 sets up the branch BEFORE any file writes.
After all checks, write the report, then commit and create a PR (Step 6).
" \
  --allowedTools "Bash,Read,Write,Grep,Glob" \
  >> "$LOG_DIR/cron-${DATE}.log" 2>&1

echo "[$(date)] quality-agent completed for ${DATE}" >> "$LOG_DIR/cron.log"
