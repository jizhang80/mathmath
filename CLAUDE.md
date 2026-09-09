# CLAUDE.md — mathmath

**mathmath** (working name; candidate *Upstream*; never `mathpath`) — an Ontario grade 9–12 math learning system for students. One cross-grade concept graph is rendered as a **map** organised by math's own taxonomy (Door C); students move across it in ~3-minute **expeditions** of probe items that lift fog (Door B); when a node is blocked, an in-map **diagnosis** event walks upstream to the deepest unmastered prerequisite, confirms it with a ~60-second probe, remediates the minimum piece and returns (Door A). Courses are trails drawn over the map; landmarks are real, sourced, real-world things linked to nodes. It is a **single-user native iOS/iPadOS app in Swift** — no accounts, no parent view; Android is a later port. Runtime infrastructure is static hosting of versioned content JSON plus one anonymous telemetry write endpoint; **no application server**. The desktop web homework mode (structured editor + CAS step verification) is deferred to M5.

**Ground truth: [`PROJECT-BRIEF-v2.md`](PROJECT-BRIEF-v2.md) as amended by [`AMENDMENT-v2.1.md`](AMENDMENT-v2.1.md) … [`AMENDMENT-v2.5.md`](AMENDMENT-v2.5.md)** — a later amendment wins on conflict; amendments are deltas, the brief is not rewritten. [`docs/idea.md`](docs/idea.md) is the consolidated extract (decisions in force, milestones, unknowns). Decisions **D1–D42 are locked** (D30 and D37 are unassigned; never reuse them). Changing a D-number is **always a Q5 owner decision** — never an agent's call.

## Principal languages & conventions

- **Swift 6 + SwiftUI** is the student-side principal language (D31, D32). A Swift Package **`Core`** holds graph data types, L0 validation, layout, the expedition scheduler and student-state transitions; `Core` imports **Foundation only** (D33). Anything the pipeline and the app must agree on is implemented **once, in `Core`**, and exposed through its command-line target (D42).
- **Python** is the offline content-pipeline language (D41): spine extraction, generation runs, L1/L2, SymPy answer verification, layout precompute. It calls the `Core` CLI for L0 and layout; it never reimplements them.
- **TypeScript** only for the M5 desktop homework mode.
- The stack is locked in **`docs/tech-stack.md`** (bootstrap Phase 5, 2026-09-09); BLOCK on any spec pinning a tool that file does not name. The Xcode project file is never edited by an agent (synchronized `App/Sources` folder). No third-party dependency beyond SwiftMath without a recorded reason (D32). No third-party game engine (D24); Apple's first-party SpriteKit is permitted only if `Canvas` performance demands it.
- Gates: `scripts/gate.sh` — the four gates of `docs/tech-stack.md` §3 (swift-format + ruff; pyright strict; `Core` tests on the iOS simulator; App build on the simulator + pytest). `main` is protected: changes land only through a PR with both CI jobs green. **Physical-device verification is the owner's delivery verification at the wrap-gate; no agent task may claim it** (D29).
- **Docs and code in English; conversation with the owner in Chinese.**
- Quantitative claims carry `[SOURCED: …]` or `[ESTIMATE: …]`. **No time estimates anywhere.**
- **Priority order: quality > token conservation > speed** (project override of the playbook's quality > rapid > token).

## Hard invariants

A spec that contradicts one of these is **BLOCKed**.

| # | Invariant | D |
|---|---|---|
| I1 | **Wherever step verification exists, step correctness is decided by CAS, never by a language model.** No code path lets a model output decide whether a step or a probe answer is right; expedition items are checked deterministically in code. | D6 |
| I2 | **Tier 0 alone must be a usable product**: every model call has a confidence threshold and a deterministic fallback; the system never guesses a diagnosis. | D7 |
| I3 | **Answers are never withheld**; diagnosis accompanies the answer wherever an answer is shown (expedition items, homework mode). | D5 |
| I4 | Remediation is just-in-time: **backtrack ≤ 2 levels per session**; **deeper gaps are marked on the map only** — no record page, no other consumer. | D4 |
| I5 | **No PII, no accounts.** Telemetry is anonymous and aggregate, **on by default with one-tap off, and carries no identifier of any kind** (no install, device or session id); the endpoint retains no IP. Cross-device sync uses Apple-managed identity only. | D17, D19, D36 |
| I6 | **No verbatim Ministry text** stored or shipped: nodes carry expectation codes + the project's own `paraphrase`, and link out to the official page. | D18 |
| I7 | **One cross-grade graph**; a course is a node subset + depth marker, drawn as a trail over the map. Never 11 separate syllabi. | D3, D20 |
| I8 | Every accepted graph passes the **L0 checks**: acyclic; no later→earlier course edge; code↔node coverage both ways; in-degree outliers flagged; starting chain connected; **every node has exactly one region; every trail is a path in the graph.** | §5 |
| I9 | **Zero human content review** — content is generated + machine-verified; disputed edges ship at low confidence, settled by probe data. Never add an "owner reviews content" step. | D10, D12, D13 |
| I10 | **Input is defined per door**: expedition items are numeric or multiple-choice; homework mode uses a structured math editor; **no OCR in any door.** | D9 |
| I11 | Docs: every quantitative claim tagged `[SOURCED]`/`[ESTIMATE]`; **no time estimates**. | §12 |
| I12 | Docs and code in **English**; conversation with the owner in **Chinese**. | §12 |
| I13 | Priority: **quality > token conservation > speed**. | §12 |
| I14 | **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary. | D33, D42 |
| I15 | **Landmarks are real, named, verifiable things with a resolving `source_url`.** A landmark that cannot be sourced is dropped, never invented. | D22 |

## Model policy

- **Fable** — **only** the owner's interactive planning/design sessions (Phase 1–6 decisions, EPIC plans, Phase-8 capture, process changes). Never runs `/run-epic`, `/run-task`, or any agent.
- **Opus** — reasoning tier: `planner`, `epic-scoper`, `spec-arbiter`, `spec-architect`, `brief-amender`; also the **orchestrating session** running `/run-epic` / `/run-epics` (owner switches the session model first).
- **Sonnet** — execution: `implementer`, `tester`, `task-writer`, `task-reviewer`.
- **Haiku** — mechanical: `task-context-compiler`, `integration-auditor`, file inventories, greps.

An agent's scope must match its tier; if a Sonnet agent needs Opus-level reasoning, the scope is too broad — split it.

## Directory layout

- `PROJECT-BRIEF-v2.md` + `AMENDMENT-v2.*.md` — owner's locked brief and its deltas, ground truth. `PROJECT-BRIEF-v1.md` — superseded, kept for history. `DEMO-BRIEF.md` — the map form-test Demo (D26), as amended. `bootstrap.md` — process playbook v0.5 (Phases 0–8). `claude-tech-stack-preferences.md` — stack-selection rules, input to Phase 5 (web-oriented; D32/D33 override it for the iOS app).
- `docs/` — `idea.md` (consolidated extract of brief + amendments), `kit-adaptation.md` (port spec: kept / stripped / changed), `carry-forward.md` (six principles + controls C1–C8), `lessons.md` (starts empty; owner-triggered Phase 8 only), `DEFERRED.md` (deferral ledger, C6 template), `domains/` (Phase 3 design, one file per domain), `design-system/ prototype/` (Phase 4 web prototype — superseded for student surfaces by the native Demo; Door A session pages remain reference for the M5 homework mode), `epics/ audits/ blocked/ plans/` (Phase 7 execution records).
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
