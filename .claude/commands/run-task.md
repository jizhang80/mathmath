---
description: Run a single task spec end-to-end (implementer ⇄ tester) for mathmath.
---

# /run-task <task-spec-path>

Execute ONE task spec to green. Input: a path like `tasks/epic-<NN>-task-<MM>-<slug>.md`.

## Process
1. **Validate input.** Read the task spec. If it doesn't exist, STOP and report.
2. **Context bundle.** If `tasks/context/epic-<NN>-task-<MM>-context.md` is missing, dispatch **task-context-compiler** to produce it.
3. **Implement.** Dispatch **implementer** with the spec + bundle. It writes source code (in the layout defined by `docs/tech-stack.md`; the spec's §2 file scope is authoritative) + a smoke test, conforms to every contract in `contracts/`, and runs `pnpm typecheck && pnpm lint && pnpm test`.
   - If implementer BLOCKs (spec drift/contradiction → `tasks/blocked/`): this is **Q4** → dispatch **spec-arbiter**; on its escalation, **spec-architect**, then **brief-amender**; a genuine new decision is **Q5** → write an owner-stop file and STOP.
4. **Test.** Dispatch **tester**. Depth follows the spec's `risk` tier: mechanical → light pass (smoke verification + boundary/error cases, four gates); seam → comprehensive suite (happy-edge / negative / error-taxonomy / B.1 conformance / idempotency / no-leak, plus one real-composition test across the seam and a negative control for every regression guard). The tester may upgrade a mechanical task to seam depth; it may never downgrade. Never re-verify the happy path a passing smoke test already covers. Run `pnpm test`.
   - If tester finds a real bug → one retry through **implementer**. If tester BLOCKs on a testability gap → **spec-arbiter** (Q4).
5. **Verify gates.** `pnpm typecheck && pnpm lint && pnpm format:check` green (whole repo), plus tests scoped to the task's file-scope modules (`pnpm vitest run <paths>`) green. `risk: seam` tasks run the full `pnpm test` instead of the scoped run. The full suite otherwise runs once at wrap gate (d).
6. **Commit.** One clean task-commit, Conventional Commits scoped to the EPIC/contract (e.g. `feat(graph): …`, `test(probe): …`). Do not push.

## Rules
- Q-protocol throughout (Q1 self-answer from contracts/docs; Q2 retry; Q3 bypass; Q4 spec-arbiter; Q5 owner-stop — rare; changing a locked decision D1–D19 is always Q5).
- Conform to every contract in `contracts/` (Phase 6; planned set in `contracts/README.md`). The toolchain is whatever `docs/tech-stack.md` locks in Phase 5 — BLOCK on a spec that pins a tool that file does not name.
- Hold invariants I1–I13 (`CLAUDE.md`): the CAS decides step correctness, never a model (I1); every model call has a confidence threshold and a deterministic Tier-0 fallback (I2); no identifying field is persisted or transmitted (I5); no verbatim Ministry text (I6); input comes from the structured math editor only (I10).
- UI / rendering / the interaction flow are in scope; Playwright E2E runs at wrap (gate d), not per task.
- A single retry per failing stage; if still red, escalate (don't loop forever).
