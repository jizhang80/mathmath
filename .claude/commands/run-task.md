---
description: Run a single task spec end-to-end (implementer ⇄ tester) for mathmath.
---

# /run-task <task-spec-path>

Execute ONE task spec to green. Input: a path like `tasks/epic-<NN>-task-<MM>-<slug>.md`.

## Process
1. **Validate input.** Read the task spec. If it doesn't exist, STOP and report.
2. **Context bundle.** If `tasks/context/epic-<NN>-task-<MM>-context.md` is missing, dispatch **task-context-compiler** to produce it.
3. **Implement.** Dispatch **implementer** with the spec + bundle. It writes source code (in the layout defined by `docs/tech-stack.md`; the spec's §2 file scope is authoritative) + a smoke test, conforms to every contract in `contracts/`, and runs `scripts/gate.sh` (format/lint, typecheck, `Core` build+test, App build + `pytest`, per `docs/tech-stack.md` §3).
   - If implementer BLOCKs (spec drift/contradiction → `tasks/blocked/`): this is **Q4** → dispatch **spec-arbiter**; on its escalation, **spec-architect**, then **brief-amender**; a genuine new decision is **Q5** → write an owner-stop file and STOP.
4. **Test.** Dispatch **tester**. Depth follows the spec's `risk` tier: mechanical → light pass (smoke verification + boundary/error cases, four gates); seam → comprehensive suite (happy-edge / negative / error-taxonomy / B.1 conformance / idempotency / no-leak, plus one real-composition test across the seam and a negative control for every regression guard). The tester may upgrade a mechanical task to seam depth; it may never downgrade. Never re-verify the happy path a passing smoke test already covers. Run the full gate.
   - If tester finds a real bug → one retry through **implementer**. If tester BLOCKs on a testability gap → **spec-arbiter** (Q4).
5. **Verify gates.** Format+lint and typecheck clean (whole repo), plus tests scoped to the task's file-scope modules (`swift test --filter <name>` in `Packages/Core`, `uv run pytest <path>` in `pipeline/`) green. `risk: seam` tasks, or any task touching `App/Sources`, run the full simulator build+test (`xcodebuild test -scheme Core-Package`, `xcodebuild build -scheme mathmath`) + `pytest` instead of the scoped run. The full suite otherwise runs once at wrap gate (d). Agents verify on the iOS simulator only — never claim physical-device verification (D29).
6. **Commit.** One clean task-commit, Conventional Commits scoped to the EPIC/contract (e.g. `feat(graph): …`, `test(probe): …`). Do not push.

## Rules
- Q-protocol throughout (Q1 self-answer from contracts/docs; Q2 retry; Q3 bypass; Q4 spec-arbiter; Q5 owner-stop — rare; changing a locked decision D1–D42 is always Q5).
- Conform to every contract in `contracts/` (Phase 6; planned set in `contracts/README.md`). The toolchain is whatever `docs/tech-stack.md` locks in Phase 5 — BLOCK on a spec that pins a tool that file does not name.
- Hold invariants I1–I15 (`CLAUDE.md`): the CAS decides step correctness, never a model (I1); every model call has a confidence threshold and a deterministic Tier-0 fallback (I2); no identifying field is persisted or transmitted (I5); no verbatim Ministry text (I6); input is defined per door, with no OCR path in any door (I10); `Core` imports Foundation only, the render layer never computes state, and L0/layout exist once, in `Core` (I14); every landmark has a resolving `source_url` (I15).
- UI / rendering / the expedition/diagnosis flow are in scope; the Demo/M3 device acceptance is the owner's product test at the wrap gate (gate d), not per task — agents verify on the simulator only.
- A single retry per failing stage; if still red, escalate (don't loop forever).
