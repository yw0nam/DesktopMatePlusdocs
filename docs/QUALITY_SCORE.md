# Quality Score

Last updated: 2026-04-07

| Domain | Arch | Test | Obs | Docs | Overall |
|--------|------|------|-----|------|---------|
| backend | A | A | A | A | A |
| nanoclaw | A | A | A | A | A |
| desktop-homunculus(Rust) | UNCHECKED | UNCHECKED | UNCHECKED | UNCHECKED | UNCHECKED |
| desktop-homunculus(MOD) | B | B | UNCHECKED | UNCHECKED | B |

> **UNCHECKED**: garden.sh does not scan DH Rust code (no cargo dependency required).
> DH MOD (TS) rows are updated by `garden.sh` on each run.

## Grade Definitions

A: All GP checks pass, no known debt
B: 1-2 minor violations or known debt
C: Major violations present, tracked
D: Critical violations or no coverage
UNCHECKED: Not evaluated by garden.sh — manual review required

## Auto-update

Run `scripts/garden.sh` to refresh grades based on GP results.
- UNCHECKED cells are never overwritten by auto-update.
- DH Rust rows remain UNCHECKED permanently unless manually updated.

## Violations Summary

_Last updated by garden.sh run. 0 violations = last run clean._

- GP-3 (backend): 0 violations
- GP-3 (nanoclaw): 0 violations
- GP-13 (DH MOD console.log): 0 violations
- GP-13 (DH MOD file size): 1 violations
- DH Rust: UNCHECKED
