---
description: Run one EPIC end-to-end on its own branch — plan, author+review task specs (with escalation), implement+test each, then wrap.
---

# /run-epic <NN>

Build one EPIC autonomously. Owner involvement: **none unless Q5.**

## Phase A0 — Brief
- If `docs/epics/epic-<NN>-*.md` is missing, dispatch **epic-scoper** to synthesize it from `docs/epic-plan.md` + the relevant `docs/domains/<module>.md` + `contracts/*`.

## Phase A1 — Branch
- `git checkout main && git pull --ff-only` (if a remote exists), then `git checkout -b epic-<NN>-<slug>`. The EPIC works on its own branch; merge to `main` only on green (see wrap).

## Phase A2 — Plan
- Dispatch **planner** (reads the brief + contracts + domain doc) → an ordered, dependency-aware task list. If it reports the EPIC exceeds the size cap, split at the brief's own seams and record the split in `docs/epic-plan.md` (or surface Q5 if the split changes scope).

## Phase A3 — Author + review task specs (escalation chain)
For each task, in dependency order:
1. **task-context-compiler** → context bundle.
2. **task-writer** → task spec.
3. **task-reviewer** → PASS or BLOCK.
   - On BLOCK, retry writer once. Still failing (≥2 cycles) → **spec-arbiter** (Q4). Its escalations: **spec-architect** (decomposition/brief) → **brief-amender** (brief) → **Q5** owner-stop (genuine new decision).
4. Commit the task specs (`chore(epic-<NN>): task specs`).

## Phase A4 — Implement + test
For each task in topological (dependency) order, run the **/run-task** loop (implementer ⇄ tester, single retry, escalate on BLOCK). One clean task-commit per verified task.

## Phase A5 — Wrap
- Run **/wrap-epic <NN>**. Only a green wrap merges the branch to `main`.

## Rules
- Q-protocol throughout; Q5 is the only owner stop and must be rare (if frequent, the design under-locked — surface it). Changing a locked decision D1–D49 is always Q5.
- Conform to every contract in `contracts/` (Phase 6; planned set in `contracts/README.md`). The toolchain and application file layout are whatever `docs/tech-stack.md` locks in Phase 5 — BLOCK on any brief or spec that pins a tool that file does not name. Hold invariants I1–I15 (`CLAUDE.md`): the CAS decides step correctness, every model call has a confidence threshold and a Tier-0 fallback, no identifying fields, no verbatim Ministry text, no human content-review step, `Core` imports Foundation only, every landmark has a resolving `source_url`.
- A derailed task reverts to its last task-commit; a badly drifted EPIC drops its branch and re-plans from `main`.
