# CLAUDE.md — mathmath

**mathmath** (working name) — an Ontario grade 9–12 math learning system for students and parents: it verifies each homework step with a CAS, locates the first wrong step, classifies the error, walks a cross-grade concept dependency graph to the deepest unmastered prerequisite, confirms it with a ~60-second probe, remediates the minimum piece, and returns to the problem. Parents get a read-only view of where the student is stuck. A **static-hosted PWA** — no server-side application logic in MVP; the only write path is an opt-in anonymous telemetry endpoint.

**Ground truth: [`PROJECT-BRIEF-v1.md`](PROJECT-BRIEF-v1.md).** Decisions **D1–D19 are locked**. Changing a D-number is **always a Q5 owner decision** — never an agent's call.

## Principal language & conventions

- **TypeScript, strict mode** is the principal language. The stack is locked in **bootstrap Phase 5** — **do not pin libraries until `docs/tech-stack.md` exists**; BLOCK on any spec pinning a tool that file does not name.
- **Python** only (a) inside Pyodide at runtime and (b) for typed offline pipelines.
- Gates until the stack is locked: `pnpm typecheck && pnpm lint && pnpm format:check && pnpm test`. Boundary validation via a schema library; test runner per `docs/tech-stack.md`.
- **Docs and code in English; conversation with the owner in Chinese.**
- Quantitative claims carry `[SOURCED: …]` or `[ESTIMATE: …]`. **No time estimates anywhere.**
- **Priority order: quality > token conservation > speed** (project override of the playbook's quality > rapid > token).

## Hard invariants

A spec that contradicts one of these is **BLOCKed**.

| # | Invariant | D |
|---|---|---|
| I1 | Step correctness is decided by **CAS, never by a language model** — no code path lets a model output decide whether a step is right. | D6 |
| I2 | **Tier 0 alone must be a usable product**: every model call has a confidence threshold and a deterministic fallback; the system never guesses a diagnosis. | D7 |
| I3 | **Answers are never withheld**; diagnosis always accompanies the answer. | D5 |
| I4 | Remediation is just-in-time: **backtrack ≤ 2 levels per session**; deeper gaps go to the record/parent view only. | D4 |
| I5 | **No PII, no accounts** — telemetry is anonymous, aggregate, opt-in, account-less; no field that identifies a person. | D17, D19 |
| I6 | **No verbatim Ministry text** stored or shipped: nodes carry expectation codes + the project's own `paraphrase`, and link out to the official page. | D18 |
| I7 | **One cross-grade graph**; a course is a node subset + depth marker. Never 11 separate syllabi. | D3 |
| I8 | Every accepted graph passes the **L0 checks**: acyclic; no later→earlier course edge; code↔node coverage both ways; in-degree outliers flagged; starting chain connected. | §5 |
| I9 | **Zero human content review** — content is generated + machine-verified; disputed edges ship at low confidence, settled by probe data. Never add an "owner reviews content" step. | D10, D12, D13 |
| I10 | Input is a **structured math editor** (MathLive → LaTeX). No OCR/handwriting paths. | D9 |
| I11 | Docs: every quantitative claim tagged `[SOURCED]`/`[ESTIMATE]`; **no time estimates**. | §12 |
| I12 | Docs and code in **English**; conversation with the owner in **Chinese**. | §12 |
| I13 | Priority: **quality > token conservation > speed**. | §12 |

## Model policy

- **Fable** — **only** the owner's interactive planning/design sessions (Phase 1–6 decisions, EPIC plans, Phase-8 capture, process changes). Never runs `/run-epic`, `/run-task`, or any agent.
- **Opus** — reasoning tier: `planner`, `epic-scoper`, `spec-arbiter`, `spec-architect`, `brief-amender`; also the **orchestrating session** running `/run-epic` / `/run-epics` (owner switches the session model first).
- **Sonnet** — execution: `implementer`, `tester`, `task-writer`, `task-reviewer`.
- **Haiku** — mechanical: `task-context-compiler`, `integration-auditor`, file inventories, greps.

An agent's scope must match its tier; if a Sonnet agent needs Opus-level reasoning, the scope is too broad — split it.

## Directory layout

- `PROJECT-BRIEF-v1.md` — owner's locked brief, ground truth. `bootstrap.md` — process playbook v0.5 (Phases 0–8). `claude-tech-stack-preferences.md` — stack-selection rules, input to Phase 5.
- `docs/` — `idea.md` (structured extract of the brief), `kit-adaptation.md` (port spec: kept / stripped / changed), `carry-forward.md` (six principles + controls C1–C8), `lessons.md` (starts empty; owner-triggered Phase 8 only), `DEFERRED.md` (deferral ledger, C6 template), `domains/ design-system/ prototype/` (Phase 3–4 design output), `epics/ audits/ blocked/ plans/` (Phase 7 execution records).
- `contracts/` — machine-checkable contracts, populated in Phase 6. `tasks/{context,blocked,arbitration}/` — Phase 7 task packets. `modules/` — reusable modules, preferred over building from scratch. `.claude/{agents,commands,settings.json}`.

Application source layout is defined by `docs/tech-stack.md`; a spec's §2 file scope is authoritative.

## Pointers

`bootstrap.md` (playbook) · `claude-tech-stack-preferences.md` (stack rules) · `contracts/` (source of truth — see RULE 5; planned set + enforcement ladder in `contracts/README.md`) · `docs/lessons.md` · `docs/carry-forward.md` (inherited principles and controls) · `docs/kit-adaptation.md` (kit port spec).

---

# RULES

## 1. Think Before Coding
**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.

**How to handle "unclear" depends on the phase:**
- **Design phases (owner in the loop):** if something is unclear, stop, name it, and ask the owner.
- **Auto-execute (Phase 7):** do **not** ask reflexively. Route through the Q-protocol — Q1 (information): answer yourself from `contracts/` and `docs/`; Q4 (spec drift): route to the spec-arbiter; only Q5 (a genuine owner decision) stops for the owner. Never silently guess; re-anchor to the contract instead.

## 2. Simplicity First
**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code (extract on the second real consumer, not the first).
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.

## 3. Surgical Changes
**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the request.

## 4. Goal-Driven Execution
**Define success criteria. Loop until verified.**

For multi-step tasks, state a brief plan:
```
1. [Step] -> verify: [check]
2. [Step] -> verify: [check]
3. [Step] -> verify: [check]
```

## 5. Conform to Contracts
**The contracts are the source of truth. Don't invent what's already decided.**

- Conform to everything in `contracts/`. Never invent a pattern a contract already defines (envelopes, error codes, IDs, vocabulary).
- When stuck, re-anchor to the contract — don't improvise forward.
- Failures should surface at the test/UI layer: prefer compile-time typing and boundary validation over runtime-only behavior, so nothing important hides in code no one reads.
