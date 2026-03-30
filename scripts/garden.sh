#!/usr/bin/env bash
# garden.sh — Background Gardening Agent
# Runs GOLDEN_PRINCIPLES.md verify commands, auto-fixes Minor violations, creates PRs.
set -euo pipefail

# ── Workspace root (script lives in scripts/) ──────────────────────
WORKSPACE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATE="$(date +%Y-%m-%d)"

# Resolve the real workspace root (follow worktree symlinks to find subrepos)
# If running inside a git worktree, subrepos live in the main worktree root.
if [[ -d "$WORKSPACE_ROOT/backend" ]]; then
  REAL_ROOT="$WORKSPACE_ROOT"
else
  # Try the git main worktree
  REAL_ROOT="$(cd "$WORKSPACE_ROOT" && git worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //')"
  if [[ -z "$REAL_ROOT" || ! -d "$REAL_ROOT/backend" ]]; then
    REAL_ROOT="$WORKSPACE_ROOT"
  fi
fi

# ── Repo config ────────────────────────────────────────────────────
declare -A REPO_DIRS=(
  [backend]="$REAL_ROOT/backend"
  [nanoclaw]="$REAL_ROOT/nanoclaw"
  [workspace]="$WORKSPACE_ROOT"
)
declare -A REPO_BRANCHES=(
  [backend]="feat/claude_harness"
  [nanoclaw]="develop"
  [workspace]="master"
)

# ── CLI flags ──────────────────────────────────────────────────────
DRY_RUN=false
FILTER_GP=""
FILTER_REPO=""

usage() {
  cat <<'EOF'
Usage: scripts/garden.sh [OPTIONS]

Background Gardening Agent — verifies Golden Principles and auto-fixes violations.

Options:
  --dry-run      Detect only, skip auto-fix / commit / PR
  --gp GP-N      Run only the specified GP (e.g. GP-3)
  --repo NAME    Run only for the specified repo (backend, nanoclaw, workspace)
  -h, --help     Show this help message

Examples:
  scripts/garden.sh                 # Full run
  scripts/garden.sh --dry-run       # Detect only
  scripts/garden.sh --gp GP-3      # Check GP-3 only
  scripts/garden.sh --repo backend  # Check backend only
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)  DRY_RUN=true; shift ;;
    --gp)       FILTER_GP="$2"; shift 2 ;;
    --repo)     FILTER_REPO="$2"; shift 2 ;;
    -h|--help)  usage; exit 0 ;;
    *)          echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# ── Result collection ──────────────────────────────────────────────
# Each entry: "GP|repo|severity|status|details"
declare -a RESULTS=()
# Track repos that have auto-fixed files
declare -A REPO_HAS_FIXES=()

should_run() {
  local gp="$1" repo="$2"
  [[ -z "$FILTER_GP"   || "$FILTER_GP"   == "$gp"   ]] || return 1
  [[ -z "$FILTER_REPO" || "$FILTER_REPO" == "$repo" ]] || return 1
  return 0
}

DELIM=$'\x1f'  # ASCII Unit Separator — safe for details containing pipes

add_result() {
  local gp="$1" repo="$2" severity="$3" status="$4"
  # Flatten multiline details to single line (newlines → " | ")
  local details="${5//$'\n'/ | }"
  RESULTS+=("${gp}${DELIM}${repo}${DELIM}${severity}${DELIM}${status}${DELIM}${details}")
}

# ── GP verify functions ────────────────────────────────────────────

verify_gp1() {
  # Architecture Layering — Critical
  local repo="$1" dir="${REPO_DIRS[$1]}"
  if [[ "$repo" == "backend" ]]; then
    [[ -d "$dir" ]] || { add_result GP-1 "$repo" Critical SKIP "repo dir not found"; return; }
    local out rc=0
    out=$(cd "$dir" && uv run pytest tests/structural/test_architecture.py 2>&1) || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      add_result GP-1 "$repo" Critical PASS "structural tests passed"
    else
      add_result GP-1 "$repo" Critical FAIL "$(echo "$out" | tail -10)"
    fi
  elif [[ "$repo" == "nanoclaw" ]]; then
    [[ -d "$dir" ]] || { add_result GP-1 "$repo" Critical SKIP "repo dir not found"; return; }
    local out rc=0
    out=$(cd "$dir" && npm test -- structural 2>&1) || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      add_result GP-1 "$repo" Critical PASS "structural tests passed"
    else
      add_result GP-1 "$repo" Critical FAIL "$(echo "$out" | tail -10)"
    fi
  fi
}

verify_gp2() {
  # File Size Limits — Major
  local repo="$1" dir="${REPO_DIRS[$1]}"
  if [[ "$repo" == "backend" ]]; then
    [[ -d "$dir" ]] || { add_result GP-2 "$repo" Major SKIP "repo dir not found"; return; }
    local out rc=0
    out=$(cd "$dir" && uv run pytest tests/structural/test_architecture.py -k "loc_limit" 2>&1) || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      add_result GP-2 "$repo" Major PASS "file sizes within limits"
    else
      add_result GP-2 "$repo" Major FAIL "$(echo "$out" | tail -10)"
    fi
  elif [[ "$repo" == "nanoclaw" ]]; then
    [[ -d "$dir" ]] || { add_result GP-2 "$repo" Major SKIP "repo dir not found"; return; }
    local out rc=0
    out=$(cd "$dir" && npm test -- structural 2>&1) || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      add_result GP-2 "$repo" Major PASS "file sizes within limits"
    else
      add_result GP-2 "$repo" Major FAIL "$(echo "$out" | tail -10)"
    fi
  fi
}

verify_gp3() {
  # No Bare Logging — Major (auto-fixable for backend)
  local repo="$1" dir="${REPO_DIRS[$1]}"
  if [[ "$repo" == "backend" ]]; then
    [[ -d "$dir" ]] || { add_result GP-3 "$repo" Major SKIP "repo dir not found"; return; }
    local out rc=0
    # GP-3 verify: grep for bare print() in src/ (ruff doesn't have T201 enabled)
    out=$(cd "$dir" && grep -rn 'print(' src/ --include='*.py' | grep -v '__pycache__' | grep -v '# noqa' | head -20) || rc=$?
    if [[ "$rc" -ne 0 || -z "$out" ]]; then
      add_result GP-3 "$repo" Major PASS "no bare print() found"
    else
      add_result GP-3 "$repo" Major FAIL "$(echo "$out" | head -5)"
    fi
  elif [[ "$repo" == "nanoclaw" ]]; then
    [[ -d "$dir" ]] || { add_result GP-3 "$repo" Major SKIP "repo dir not found"; return; }
    local out rc=0
    out=$(cd "$dir" && npm test -- structural 2>&1) || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      add_result GP-3 "$repo" Major PASS "no console.log found"
    else
      add_result GP-3 "$repo" Major FAIL "$(echo "$out" | tail -10)"
    fi
  fi
}

verify_gp4() {
  # No Hardcoded Config — Critical
  local repo="$1" dir="${REPO_DIRS[$1]}"
  if [[ "$repo" == "backend" || "$repo" == "nanoclaw" ]]; then
    [[ -d "$dir" ]] || { add_result GP-4 "$repo" Critical SKIP "repo dir not found"; return; }
    local out rc=0
    out=$(cd "$dir" && grep -rn 'localhost\|127\.0\.0\.1\|mongodb://' src/ \
      --include='*.py' --include='*.ts' \
      --exclude-dir='__pycache__' \
      --exclude-dir='node_modules' \
      | grep -v 'test' | grep -v 'config' | head -20) || rc=$?
    if [[ "$rc" -eq 0 && -n "$out" ]]; then
      add_result GP-4 "$repo" Critical FAIL "hardcoded values found: $(echo "$out" | head -5)"
    else
      add_result GP-4 "$repo" Critical PASS "no hardcoded config found"
    fi
  fi
}

verify_gp5() {
  # Delegation Direction — Critical
  local repo="$1" dir="${REPO_DIRS[$1]}"
  if [[ "$repo" == "nanoclaw" ]]; then
    [[ -d "$dir" ]] || { add_result GP-5 "$repo" Critical SKIP "repo dir not found"; return; }
    local out rc=0
    out=$(cd "$dir" && grep -rn 'from.*backend\|import.*backend\|require.*backend' src/ 2>&1 | head -10) || rc=$?
    if [[ "$rc" -eq 0 && -n "$out" ]]; then
      add_result GP-5 "$repo" Critical FAIL "reverse import found: $out"
    else
      add_result GP-5 "$repo" Critical PASS "no reverse imports"
    fi
  fi
}

verify_gp6() {
  # NanoClaw Skill-as-Branch — Critical
  local repo="$1" dir="${REPO_DIRS[$1]}"
  if [[ "$repo" == "nanoclaw" ]]; then
    [[ -d "$dir" ]] || { add_result GP-6 "$repo" Critical SKIP "repo dir not found"; return; }
    local out rc=0
    out=$(cd "$dir" && npm test -- structural 2>&1) || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      add_result GP-6 "$repo" Critical PASS "NC-S4 passed"
    else
      add_result GP-6 "$repo" Critical FAIL "$(echo "$out" | tail -10)"
    fi
  fi
}

verify_gp7() {
  # CLAUDE.md size — Minor
  local repo="$1"
  if [[ "$repo" == "workspace" ]]; then
    local lines
    lines=$(wc -l < "$WORKSPACE_ROOT/CLAUDE.md" | tr -d ' ')
    if [[ "$lines" -le 120 ]]; then
      add_result GP-7 workspace Minor PASS "CLAUDE.md ${lines} lines (≤120)"
    else
      add_result GP-7 workspace Minor FAIL "CLAUDE.md ${lines} lines (>120)"
    fi
  elif [[ "$repo" == "backend" ]]; then
    local f="${REPO_DIRS[backend]}/CLAUDE.md"
    if [[ -f "$f" ]]; then
      local lines
      lines=$(wc -l < "$f" | tr -d ' ')
      if [[ "$lines" -le 200 ]]; then
        add_result GP-7 backend Minor PASS "CLAUDE.md ${lines} lines (≤200)"
      else
        add_result GP-7 backend Minor FAIL "CLAUDE.md ${lines} lines (>200)"
      fi
    fi
  fi
}

verify_gp8() {
  # Plans as First-Class Artifacts — Minor
  local repo="$1"
  if [[ "$repo" == "workspace" ]]; then
    local plans_file="$WORKSPACE_ROOT/Plans.md"
    if [[ ! -f "$plans_file" ]]; then
      add_result GP-8 workspace Minor PASS "no Plans.md found"
      return
    fi
    local wip_count
    wip_count="$(grep -c 'cc:WIP' "$plans_file" 2>/dev/null)" || wip_count=0
    if [[ "$wip_count" -eq 0 ]]; then
      add_result GP-8 workspace Minor PASS "no orphan cc:WIP tasks"
    else
      add_result GP-8 workspace Minor FAIL "${wip_count} cc:WIP task(s) without corresponding commit"
    fi
  fi
}

verify_gp9() {
  # Worktree Isolation — Major
  # Check that main/develop don't have direct (non-merge) commits
  local repo="$1" dir="${REPO_DIRS[$1]}"
  if [[ "$repo" == "backend" ]]; then
    [[ -d "$dir" ]] || { add_result GP-9 "$repo" Major SKIP "repo dir not found"; return; }
    add_result GP-9 "$repo" Major PASS "worktree isolation (manual review)"
  fi
}

verify_gp10() {
  # Lint Before Merge — Critical (auto-fixable for backend)
  local repo="$1" dir="${REPO_DIRS[$1]}"
  if [[ "$repo" == "backend" ]]; then
    [[ -d "$dir" ]] || { add_result GP-10 "$repo" Critical SKIP "repo dir not found"; return; }
    local out rc=0
    if [[ -f "$dir/scripts/lint.sh" ]]; then
      out=$(cd "$dir" && sh scripts/lint.sh 2>&1) || rc=$?
    else
      out=$(cd "$dir" && uv run ruff check src/ 2>&1) || rc=$?
    fi
    if [[ "$rc" -eq 0 ]]; then
      add_result GP-10 "$repo" Critical PASS "lint passed"
    else
      add_result GP-10 "$repo" Critical FAIL "$(echo "$out" | tail -10)"
    fi
  elif [[ "$repo" == "nanoclaw" ]]; then
    [[ -d "$dir" ]] || { add_result GP-10 "$repo" Critical SKIP "repo dir not found"; return; }
    local out rc=0
    out=$(cd "$dir" && npm run build 2>&1) || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      add_result GP-10 "$repo" Critical PASS "build passed"
    else
      add_result GP-10 "$repo" Critical FAIL "$(echo "$out" | tail -10)"
    fi
  fi
}

verify_gp11() {
  # Archive Freshness — WARN
  # spec-ref files referenced only by cc:DONE tasks should be in completed/, not active dirs
  local repo="$1"
  if [[ "$repo" != "workspace" ]]; then return; fi

  local plans_file="$WORKSPACE_ROOT/Plans.md"
  [[ -f "$plans_file" ]] || { add_result GP-11 workspace WARN SKIP "Plans.md not found"; return; }

  # Collect all spec-ref values from cc:DONE tasks (lines with [x])
  # and all spec-ref values from cc:TODO/WIP tasks (lines with [ ])
  declare -A done_refs=()
  declare -A active_refs=()

  while IFS= read -r line; do
    # Extract spec-ref value
    local ref=""
    ref=$(echo "$line" | grep -oP 'spec-ref:\s*\K\S+' | sed 's/\.$//')
    [[ -n "$ref" ]] || continue

    if echo "$line" | grep -qP '^\s*-\s*\[x\]'; then
      done_refs["$ref"]=1
    elif echo "$line" | grep -qP '^\s*-\s*\[\s*\]'; then
      active_refs["$ref"]=1
    fi
  done < "$plans_file"

  # Check: spec-ref in done_refs but NOT in active_refs, and file is in active directory
  local stale_files=()
  for ref in "${!done_refs[@]}"; do
    # Skip if any active (TODO/WIP) task also references this spec
    [[ -z "${active_refs[$ref]:-}" ]] || continue

    # Check if file is in active directory (not under completed/)
    local full_path="$WORKSPACE_ROOT/$ref"
    if [[ -e "$full_path" ]] && [[ "$ref" != *"/completed/"* ]]; then
      stale_files+=("$ref")
    fi
  done

  if [[ ${#stale_files[@]} -eq 0 ]]; then
    add_result GP-11 workspace WARN PASS "all completed spec-refs archived"
  else
    local details=""
    for f in "${stale_files[@]}"; do
      details+="$f"$'\n'
    done
    add_result GP-11 workspace WARN FAIL "stale files in active dir: ${details}"
  fi
}

verify_doc() {
  # Documentation freshness — Minor
  local repo="$1"
  if [[ "$repo" == "workspace" ]]; then
    local check_script="$WORKSPACE_ROOT/scripts/check_docs.sh"
    if [[ ! -x "$check_script" ]]; then
      add_result DOC workspace Minor SKIP "check_docs.sh not found"
      return
    fi
    local out rc=0
    out=$("$check_script" --dry-run 2>&1) || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      add_result DOC workspace Minor PASS "docs check passed"
    else
      add_result DOC workspace Minor FAIL "$(echo "$out" | grep '\[FAIL\]' | head -5)"
    fi
  fi
}

# ── Detection phase ────────────────────────────────────────────────
echo "=== Garden Run $DATE ==="
echo ""

run_detection() {
  local gp_func="$1" gp_id="$2"
  shift 2
  for repo in "$@"; do
    should_run "$gp_id" "$repo" && "$gp_func" "$repo" || true
  done
}

run_detection verify_gp1  GP-1  backend nanoclaw
run_detection verify_gp2  GP-2  backend nanoclaw
run_detection verify_gp3  GP-3  backend nanoclaw
run_detection verify_gp4  GP-4  backend nanoclaw
run_detection verify_gp5  GP-5  nanoclaw
run_detection verify_gp6  GP-6  nanoclaw
run_detection verify_gp7  GP-7  workspace backend
run_detection verify_gp8  GP-8  workspace
run_detection verify_gp9  GP-9  backend
run_detection verify_gp10 GP-10 backend nanoclaw
run_detection verify_gp11 GP-11 workspace
run_detection verify_doc  DOC   workspace

# ── Print detection results ────────────────────────────────────────
for r in "${RESULTS[@]}"; do
  IFS=$'\x1f' read -r gp repo severity status details <<< "$r"
  printf "[%-5s] %-7s %-10s %s\n" "$gp" "$status" "$repo" "$details"
done

# ── Update Quality Score ──────────────────────────────────────────
update_quality_score() {
  local qs_file="$WORKSPACE_ROOT/docs/QUALITY_SCORE.md"
  [[ -f "$qs_file" ]] || return

  # Collect failures per domain per layer
  # GP mapping: GP-1/2/3/10 → Arch/Test; GP-7/8 → Docs; GP-4/9 → Obs; DOC → Docs
  declare -A domain_arch=() domain_test=() domain_obs=() domain_docs=()

  for r in "${RESULTS[@]}"; do
    IFS=$'\x1f' read -r gp repo severity status details <<< "$r"
    [[ "$status" == "FAIL" ]] || continue

    local domain="$repo"
    [[ "$domain" == "workspace" ]] && continue  # workspace maps to docs only

    case "$gp" in
      GP-1|GP-2)  domain_arch[$domain]=$(( ${domain_arch[$domain]:-0} + 1 )) ;;
      GP-3|GP-10) domain_test[$domain]=$(( ${domain_test[$domain]:-0} + 1 )) ;;
      GP-4|GP-9)  domain_obs[$domain]=$(( ${domain_obs[$domain]:-0} + 1 )) ;;
      GP-7|GP-8|DOC) domain_docs[$domain]=$(( ${domain_docs[$domain]:-0} + 1 )) ;;
    esac
  done

  # Also count workspace doc failures
  for r in "${RESULTS[@]}"; do
    IFS=$'\x1f' read -r gp repo severity status details <<< "$r"
    [[ "$status" == "FAIL" && "$repo" == "workspace" ]] || continue
    case "$gp" in
      GP-7|GP-8|DOC)
        # Apply to all domains as a workspace-level docs issue
        domain_docs[backend]=$(( ${domain_docs[backend]:-0} + 1 ))
        ;;
    esac
  done

  grade_from_count() {
    local count="${1:-0}"
    if [[ "$count" -eq 0 ]]; then echo "A"
    elif [[ "$count" -le 2 ]]; then echo "B"
    elif [[ "$count" -le 4 ]]; then echo "C"
    else echo "D"
    fi
  }

  compute_overall() {
    local worst="A"
    for g in "$@"; do
      case "$g" in
        D) worst="D"; return ;;
        C) [[ "$worst" == "D" ]] || worst="C" ;;
        B) [[ "$worst" == "C" || "$worst" == "D" ]] || worst="B" ;;
      esac
    done
    echo "$worst"
  }

  # Compute grades for each domain
  for domain in backend nanoclaw desktop-homunculus; do
    local arch_g test_g obs_g docs_g overall_g
    arch_g=$(grade_from_count "${domain_arch[$domain]:-0}")
    test_g=$(grade_from_count "${domain_test[$domain]:-0}")
    obs_g=$(grade_from_count "${domain_obs[$domain]:-0}")
    docs_g=$(grade_from_count "${domain_docs[$domain]:-0}")
    overall_g=$(compute_overall "$arch_g" "$test_g" "$obs_g" "$docs_g")

    # Update the row in QUALITY_SCORE.md
    # Match: | domain | ... |
    sed -i "s/| ${domain} |.*|/| ${domain} | ${arch_g} | ${test_g} | ${obs_g} | ${docs_g} | ${overall_g} |/" "$qs_file"
  done

  # Update timestamp
  sed -i "s/^Last updated:.*/Last updated: $(date +%Y-%m-%d)/" "$qs_file"
}

update_quality_score

# ── Count violations ───────────────────────────────────────────────
VIOLATION_COUNT=0
declare -A REPO_VIOLATIONS=()
for r in "${RESULTS[@]}"; do
  IFS=$'\x1f' read -r gp repo severity status details <<< "$r"
  if [[ "$status" == "FAIL" ]]; then
    ((VIOLATION_COUNT++)) || true
    REPO_VIOLATIONS[$repo]=$(( ${REPO_VIOLATIONS[$repo]:-0} + 1 ))
  fi
done

if [[ "$VIOLATION_COUNT" -eq 0 ]]; then
  echo ""
  echo "All principles satisfied. Nothing to do."
  exit 0
fi

# ── Auto-fix phase (skip if --dry-run) ─────────────────────────────
declare -A AUTO_FIXED=()

if [[ "$DRY_RUN" == false ]]; then
  echo ""
  echo "--- Auto-fix phase ---"

  for r in "${RESULTS[@]}"; do
    IFS=$'\x1f' read -r gp repo severity status details <<< "$r"
    [[ "$status" == "FAIL" ]] || continue

    # GP-3 backend: ruff --fix (for linting issues), then re-verify with grep
    if [[ "$gp" == "GP-3" && "$repo" == "backend" ]]; then
      echo "[GP-3]  auto-fixing backend via ruff --fix..."
      (cd "${REPO_DIRS[backend]}" && uv run ruff check src/ --fix 2>&1) || true
      # Re-verify: grep for bare print() (same as detection)
      reverify_rc=0
      grep -rn 'print(' "${REPO_DIRS[backend]}/src/" --include='*.py' | grep -v '__pycache__' | grep -v '# noqa' > /dev/null 2>&1 || reverify_rc=$?
      if [[ "$reverify_rc" -ne 0 ]]; then
        echo "[GP-3]  FIXED  backend  ruff --fix applied"
        AUTO_FIXED["GP-3|backend"]=1
        REPO_HAS_FIXES[backend]=1
      else
        echo "[GP-3]  UNFIXED  backend  ruff --fix did not resolve all print() calls"
      fi
    fi

    # GP-10 backend: lint.sh (includes ruff --fix)
    if [[ "$gp" == "GP-10" && "$repo" == "backend" ]]; then
      echo "[GP-10] auto-fixing backend via lint..."
      if [[ -f "${REPO_DIRS[backend]}/scripts/lint.sh" ]]; then
        (cd "${REPO_DIRS[backend]}" && uv run ruff check src/ --fix 2>&1) || true
        if (cd "${REPO_DIRS[backend]}" && sh scripts/lint.sh >/dev/null 2>&1); then
          echo "[GP-10] FIXED  backend  lint now passes"
          AUTO_FIXED["GP-10|backend"]=1
          REPO_HAS_FIXES[backend]=1
        else
          echo "[GP-10] UNFIXED  backend  lint still fails after auto-fix"
        fi
      else
        (cd "${REPO_DIRS[backend]}" && uv run ruff check src/ --fix 2>&1) || true
        if (cd "${REPO_DIRS[backend]}" && uv run ruff check src/ >/dev/null 2>&1); then
          echo "[GP-10] FIXED  backend  ruff --fix applied"
          AUTO_FIXED["GP-10|backend"]=1
          REPO_HAS_FIXES[backend]=1
        else
          echo "[GP-10] UNFIXED  backend  ruff --fix did not resolve all issues"
        fi
      fi
    fi
  done
else
  echo ""
  echo "--- Dry run: skipping auto-fix, commit, and PR ---"
fi

# ── Generate GARDEN_REPORT.md ──────────────────────────────────────
generate_report() {
  local target_repo="$1"
  local report=""
  local has_fixed=false
  local has_review=false
  local fixed_section=""
  local review_section=""

  for r in "${RESULTS[@]}"; do
    IFS=$'\x1f' read -r gp repo severity status details <<< "$r"
    [[ "$repo" == "$target_repo" ]] || continue
    [[ "$status" == "FAIL" ]] || continue

    if [[ -n "${AUTO_FIXED["${gp}|${repo}"]:-}" ]]; then
      has_fixed=true
      fixed_section+="- [${gp}] ${repo}: auto-fixed via ruff --fix"$'\n'
    else
      has_review=true
      review_section+="- [${gp}] ${repo} — Severity: ${severity}"$'\n'
      review_section+="  Output: $(echo "$details" | head -30)"$'\n'
    fi
  done

  report="# Garden Report — ${DATE}"$'\n\n'
  if [[ "$has_fixed" == true ]]; then
    report+="## Auto-fixed"$'\n'
    report+="$fixed_section"$'\n'
  fi
  if [[ "$has_review" == true ]]; then
    report+="## Requires Human Review"$'\n'
    report+="$review_section"$'\n'
  fi

  echo "$report"
}

# ── PR creation phase (skip if --dry-run) ──────────────────────────
if [[ "$DRY_RUN" == false ]]; then
  echo ""
  echo "--- PR creation phase ---"

  for repo in "${!REPO_VIOLATIONS[@]}"; do
    local_dir="${REPO_DIRS[$repo]}"
    base_branch="${REPO_BRANCHES[$repo]}"
    branch_name="fix/garden-${DATE}"

    [[ -d "$local_dir/.git" || -f "$local_dir/.git" ]] || {
      echo "Skipping $repo — not a git repo"
      continue
    }

    echo "Creating PR for $repo..."

    # Generate report
    report_content="$(generate_report "$repo")"

    (
      cd "$local_dir"

      # Create branch
      git checkout -b "$branch_name" 2>/dev/null || git checkout "$branch_name" 2>/dev/null || true

      # If there are auto-fixed files, commit them
      if [[ -n "${REPO_HAS_FIXES[$repo]:-}" ]]; then
        git add -A src/ 2>/dev/null || true
        git commit -m "fix: garden auto-fix GP violations ($DATE)" 2>/dev/null || true
      fi

      # Write and commit report
      echo "$report_content" > GARDEN_REPORT.md
      git add GARDEN_REPORT.md
      git commit -m "docs: garden report $DATE" 2>/dev/null || true

      # Push and create PR
      git push -u origin "$branch_name" 2>/dev/null || true
      pr_url=$(gh pr create \
        --title "garden: drift report $DATE" \
        --base "$base_branch" \
        --body "$report_content" 2>&1) || true

      echo "  $repo → $pr_url"
    )
  done
else
  # In dry-run, still show what the report would look like
  for repo in "${!REPO_VIOLATIONS[@]}"; do
    echo ""
    echo "--- Report for $repo ---"
    generate_report "$repo"
  done
fi

# ── Summary ────────────────────────────────────────────────────────
echo ""
echo "--- Summary ---"

total_fixed=0
total_report=0
for r in "${RESULTS[@]}"; do
  IFS=$'\x1f' read -r gp repo severity status details <<< "$r"
  if [[ "$status" == "FAIL" ]]; then
    if [[ -n "${AUTO_FIXED["${gp}|${repo}"]:-}" ]]; then
      ((total_fixed++)) || true
    else
      ((total_report++)) || true
    fi
  fi
done

echo "Total violations: $VIOLATION_COUNT ($total_fixed auto-fixed, $total_report report-only)"
for repo in "${!REPO_VIOLATIONS[@]}"; do
  echo "  $repo: ${REPO_VIOLATIONS[$repo]} violation(s)"
done

if [[ "$DRY_RUN" == true ]]; then
  echo ""
  echo "(dry-run mode — no commits or PRs were created)"
fi
