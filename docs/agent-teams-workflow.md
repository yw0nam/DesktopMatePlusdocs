# Agent Teams Workflow

## Setup

Agent Teams enabled via `.claude/settings.json`:
```json
{
  "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
  "teammateMode": "tmux"
}
```

## Teams

| Teammate | Target repo | Worktree path |
|----------|-------------|---------------|
| `backend-team` | `backend/` | `worktrees/backend-{slug}/` |
| `nanoclaw-team` | `nanoclaw/` | `worktrees/nanoclaw-{slug}/` |
| `dh-team` | `desktop-homunculus/` | `worktrees/dh-{slug}/` |

## How to Spawn

After creating worktrees (Phase 5), say to the Leader:

```
Create an agent team. Spawn teammates for repos with cc:TODO tasks:
- backend-team: works in worktrees/backend-{slug}/
- nanoclaw-team: works in worktrees/nanoclaw-{slug}/

Each teammate should:
1. Read their repo's CLAUDE.md (original repo path, not worktree)
2. cd into the assigned worktree path
3. Run /harness-work breezing --no-discuss all for their [target:] tasks
4. Report back to leader when done: tasks completed, files changed, test results
```

## Rules

- **MANDATORY**: Implementation MUST use tmux Agent Teams. `Agent` tool (sub-agent) is FORBIDDEN for implementation — loses repo isolation and bypasses worktree workflow.
- **Agent tool IS allowed** for: research-only tasks (reading files, web search, analysis) with no code changes.
- Send structured messages to teammates **individually** — `SendMessage(to: "*")` fails for structured type.
- `git worktree remove` after harness-work always requires `--force` — `.claude/state/` session files are created inside worktrees.
