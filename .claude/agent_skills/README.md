# Agent Skills

Team-specific resources for each agent in desktopmate-plus.

## Directory Convention

- `{team-name}/skills/{skill-name}/SKILL.md` — team-specific skill
- `{team-name}/scripts/` — team-specific scripts
- `{team-name}/references/` — team-specific reference docs
- Team directory names use hyphens: `dh-team`, `backend-team`, etc.

## How to Add a New Team

1. Create `agent_skills/{team-name}/` directory
2. Create `{team-name}/README.md` with Skills/Scripts/References sections
3. Add `.claude/agent_skills/{team-name}/README.md` to
   `.claude/agents/{team-name}.md` "Load After /clear" (position 2)

## How to Create a New Skill

**REQUIRED:** Follow `superpowers:writing-skills` methodology (TDD for skills).

1. RED: Run pressure scenario WITHOUT the skill — document baseline
2. GREEN: Create `agent_skills/{team}/skills/{name}/SKILL.md`:
   - YAML frontmatter: `name` + `description` (start with "Use when...")
   - Max 1024 chars frontmatter, description in third person
   - Overview → When to Use → Core Pattern → Quick Reference
3. REFACTOR: Close loopholes, re-test
4. Update `agent_skills/{team}/README.md` index
5. Commit and push

## SKILL.md Frontmatter

```yaml
---
name: skill-name
description: Use when [specific triggering conditions]
allowed-tools: (optional)
---
```

## Relationship to .claude/skills/

| Path | Purpose | Scope |
|------|---------|-------|
| `.claude/skills/` | Shared workflow skills | All agents |
| `.claude/agents/` | Agent context files | Per-agent |
| `.claude/agent_skills/` | Team-specific tools, scripts, references | Per-team |

- No duplication: if a skill applies to 2+ teams, move it to `.claude/skills/`
- `agent_skills/` complements, not replaces, existing structures
