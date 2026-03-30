# Agent Context Files

Each agent in the `desktopmate-plus` team owns one file here.
Load your file immediately after `/clear` to restore essential context.

## Rules

- **200-line limit per file** — if content grows beyond this, split into `.claude/agents/{name}/` subdirectory and link from the main file
- **Agent owns their file** — each agent updates their own file after each feature
- **No code here** — paths, commands, role reminders only. Implementation details go in CLAUDE.md or team-local.md
- **Keep `Current Sprint` fresh** — update after each Plans.md Phase completes

## Template

```markdown
# {agent-name}

## Role
One-line role description.

## Load After /clear
Files to read immediately after /clear (in order):
1. `.claude/agents/{name}.md` ← this file
2. (repo CLAUDE.md or team-local.md)
3. `Plans.md` — scan for active cc:TODO tagged for your repo
4. (spec-ref of current task, if assigned)

## Key Paths
- path/to/thing — purpose

## Skills
- `/skill-name` — when to use

## Current Sprint
- **Active Phase**: Phase N — {name}
- **My tasks**: TASK-ID (status)

## Known Gotchas
- Short bullet per gotcha. Long explanations → link to [docs/faq/](../../docs/faq/)
```
