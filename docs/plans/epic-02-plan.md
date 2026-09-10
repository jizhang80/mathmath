# EPIC 02 plan (planner output)

Brief: `docs/epics/epic-02-core-behaviour.md`. The planner found the EPIC over the 8-task cap (11 tasks + 2
wraps) and split it at the brief's own §8 seam without changing scope:

- **02a — Door B core:** 02.1–02.8 (wrap 02.8), branch `epic-02-core-behaviour`.
- **02b — Door A core + merge:** 02.9–02.13 (wrap 02.13), branch `epic-02b-door-a-core-merge`.

One id space; specs at `tasks/epic-02-task-<MM>-<slug>.md`. Pre-dispatch rulings on Q-A, Q-B, Q-E, Q-F, Q-G:
`tasks/arbitration/arbiter-02-predispatch.md`.

| Id | Sub | Slug | Kind | Depends | Risk | C1 seam |
|---|---|---|---|---|---|---|
| 02.1 | a | contract-interaction-numeric-normalisation | contract | — | seam | — |
| 02.2 | a | contract-data-model-remediated-flag (conditional on Q-A) | contract | — | seam | — |
| 02.3 | a | l0t-demo-trail-resolution (per Q-E ruling) | contract/data | — | seam | — |
| 02.4 | a | core-error-calendar-day-mastery | impl | 02.2 | seam | — |
| 02.5 | a | marker-trail-reconciliation | impl | 02.1, 02.3, 02.4 | seam | — |
| 02.6 | a | fringe-compose-seam | impl | 02.2, 02.4, 02.5 | seam | marker → trail → fringe |
| 02.7 | a | item-checker-expedition-run | impl | 02.1, 02.6 | seam | — |
| 02.8 | a | epic-02a-wrap | wrap | 02.1–02.7 | mechanical | — |
| 02.9 | b | contract-state-merge-rule | contract | 02.8 | seam | — |
| 02.10 | b | prerequisite-query-classify | impl | 02.8 | seam | — |
| 02.11 | b | diagnosis-machine-seam | impl | 02.10 | seam | expedition ↔ diagnosis |
| 02.12 | b | state-merge | impl | 02.9 | seam | — |
| 02.13 | b | epic-02b-wrap | wrap | all | mechanical | — |

## Task scopes

**02.1** — Bump interaction-contract to v0.9.1: normative §2 numeric normalisation (optional sign, integer,
decimal, `a/b`; whitespace; leading zeros; exact-rational comparison `3/4 = 0.75`; per-item absolute
`tolerance`, default 0); drop that item from § Finalization owed. Must cover the demo answer forms
(`5/6`, `-10`, `32000`). Any interaction-contract text ruled by the arbiter (Q-A alternative, Q-F) lands here.
File: `contracts/interaction-contract.md`.

**02.2** — (conditional on Q-A) optional boolean `remediated` on the StudentState node entry (absent = false)
through data-model text + version, `student-state.schema.json`, `contracts/examples/student-state.json`,
`Packages/Core/Sources/Core/Model/StudentState.swift`, `IdentifierBlocklistParityTests.swift`,
`OptionalAbsentTests.swift`. Any Q-F schema change lands here.

**02.3** — Carry out the Q-E ruling: route (a) clarify L0-T in `contracts/graph-constraints.md` (versioned) or
route (b) fix `data/demo/edges.json` + manifest sha256, keeping L0-1…L0-10 green.

**02.4** — `CoreError` gains the full R-6 set (all `EXP_*`, `DIAG_*`, `GRAPH_NO_PREREQUISITE`,
`MAP_MARKER_OFF_TRAIL`, `EXP_STATE_WRITE_FAILED`); injected `CalendarDay` (no `Date()`); ladder
`[1,3,7,14,30]` last rung repeating; `CoreEvent` value with the exact §5 names; §1 transitions
(`itemCorrect`, `itemMiss` review, `diagnosisBlocked`) — clearing needs distinct items (evidence from
`probe_log`); shared seeded property-test support on the existing `SeededGenerator`. Files under
`Packages/Core/Sources/Core/{CoreError.swift,State/}` and matching tests + `Tests/CoreTests/Support/PropertyGen.swift`.

**02.5** — `set_marker`, default marker, `generate_trail` with D47 extension, runtime L0-T segment check
(`EXP_TRAIL_INVALID`, previous trail stands), W7 load-time reconciliation (`EXP_NODE_NOT_IN_GRAPH` keep-and-
ignore; `MAP_MARKER_OFF_TRAIL` + default marker). Does not edit `L0Checker.swift`. Extension positive case on an
in-memory bundle (data/demo has no `next_courses` target present).

**02.6** — D48 fringe + `compose` (queued node → fringe in trail order → ≤ 2 due reviews oldest `last_probe`
first, cap 5; deterministic item draw preferring unused, by id; `EXP_NO_FRINGE`, `EXP_ITEM_POOL_EMPTY`). The
item draw is defined here and reused by 02.7 and 02.11. Owns C1 marker→trail→fringe
(`MarkerTrailFringeSeamTests.swift`, all real on `data/demo`).

**02.7** — deterministic `ItemChecker` (numeric per 02.1, `mc` by choice id; no free text) + expedition run
machine (answer + `why` always returned, D27 retry, one diagnosis per run, blocked on spent second miss, `end`
with summary, `expedition_log`, `probe_log`, `abandoned`), plus the suspend/resume hand-off diagnosis consumes
(so 02.11 never edits this file).

**02.8** — 02a wrap: `/wrap-epic` gates, acceptance `docs/audits/epic-02a-acceptance.md`, merge.

**02.9** — Normative StudentState merge rule in `contracts/data-model.md` per the Q-B ruling.

**02.10** — deepest-unmastered-prerequisite query (BFS, level cap parameter, fog counts, tie-break confidence →
depth → id, `implies_prerequisite` bias, `GRAPH_NO_PREREQUISITE`) + Tier-0 distractor-tag `classify`
(error type or `none_of_these`). No model, no adapter parameter.

**02.11** — §4 diagnosis machine (two triggers; hypothesis → probe/hint → remediation/hint → returned;
declinable probe; second level offered never automatic; budget parameter (2, Demo 1) checked before any probe;
`capped`; `remediated` set on remediation). Tier-0 completeness suite. Owns C1 expedition↔diagnosis
(`ExpeditionDiagnosisSeamTests.swift`, real run + real diagnosis + resume on `data/demo`).

**02.12** — pure `merge(StudentState, StudentState)`: commutative, idempotent, never lowers mastery, no
identifier; algebraic-law property tests.

**02.13** — 02b wrap: acceptance `docs/audits/epic-02-acceptance.md` tracing brief §4 items 1–10 to tests;
interaction-contract stays below v1.0.0 (EPIC 04 bumps it).

## Planner notes kept for spec writers

- Interface-first ownership: no two tasks write the same file. `StudentState.swift` only by 02.2;
  `contracts/data-model.md` by 02.2 then 02.9, sequentially.
- Glossary: say **fringe**, never "frontier" (the expedition domain doc itself uses "frontier"); no
  "session", "start marker", "attempt" in new identifiers (wrap grep).
- `MAP_MARKER_OFF_TRAIL` registry user_text ("The marker stays where it was") mismatches the load-time
  fallback where the marker moves — flag for EPIC 03 (UI text owner).
- Brief §7.10 live-landmark retry fix enters only if CI flakes, as a separate `fix(pipeline)` task.
