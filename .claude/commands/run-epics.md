---
description: Run a range of EPICs back-to-back (run-epic + wrap-epic each), halting only on a genuine stop condition.
---

# /run-epics <from> <to>

Chain `/run-epic <N>` → (`/wrap-epic` is invoked inside run-epic) for `N` in `[from..to]`, autonomously. This is the Phase 7b auto-execute driver.

## Per-EPIC loop
For each `N`:
1. `git checkout main && git pull --ff-only` (if remote).
2. Run **/run-epic <N>** (which ends by running /wrap-epic and merging on green).
3. Proceed to `N+1` only if the wrap was green and no halt condition fired.

## Halt conditions (stop the chain, report, do not continue)
- **H1 — Q5 / owner-stop:** a new `docs/blocked/run-stop-*.md` appeared (a genuine owner decision is needed).
- **H2 — RED audit:** the integration-auditor returned RED and findings weren't resolved.
- **H3 — wrap not green:** an EPIC's wrap-gates failed and couldn't be made green within the retry budget.
- **H4 — cascade:** the cascade trigger fired (2 consecutive EPICs each > 3 **rework** `fix:` commits — corrections of earlier same-EPIC work against shipped code; see /wrap-epic §Cascade detection) → surface Q5.
- **H5 — pipeline crash / repeated escalation loop.**

## Rules
- Owner involvement: **nothing** unless a halt condition fires. No daily summaries, no per-EPIC pushes.
- On any halt, leave `main` at the last green EPIC, report which EPIC stopped and why, and what decision/fix is needed.
- The owner pulls progress when they choose (wrap-reports, `git log --oneline`, `scripts/gate.sh`).
