---
phase: qa
status: complete
created: 2026-07-03
updated: 2026-07-03
round: 1
verdict: converged | halted | iterating
---
# QA Summary — <intent summary> (round <N>)

## At a glance

| Gate | Status |
|------|--------|
| Board empty | ✅ / ❌ |
| Review empty | ✅ / ❌ |
| No high findings | ✅ / ❌ |
| No medium findings | ✅ / ❌ |
| Tests pass | ✅ / ❌ |
| Coverage ≥ threshold | ✅ / ❌ |
| Coverage no regression | ✅ / ❌ |
| Lint clean | ✅ / ❌ |
| Typecheck clean | ✅ / ❌ |
| User signoff | ✅ / ❌ |

**Verdict**: CONVERGED (all gates pass) | HALTED (manual intervention needed) | ITERATING (will continue in next round)

## Per-ticket review summary

| Ticket | Reviewer verdict | Findings (H/M/L) | Human approved |
|--------|------------------|------------------|----------------|
| STORY-001 | APPROVED | 0/0/1 | ✅ |
| STORY-002 | NEEDS-FIX | 1/2/0 | ❌ |

## Cross-ticket coherence
<paragraph from foundry-cross-reviewer>

## New tickets routed to board
- NEW-001 — <finding> (priority P1) → routed to Ready
- NEW-002 — <finding> (priority P2) → routed to Ready

## Next round actions
- [ ] Re-spawn writer sub-agent for NEW-001, NEW-002 (back to Phase 6)
- [ ] OR: human sign-off if all gates green