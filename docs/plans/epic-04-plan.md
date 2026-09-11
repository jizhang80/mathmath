# EPIC 04 plan (planner output)

Brief: `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md`. The planner found the EPIC over the 8-task
cap (11 work tasks + 2 wraps) and split it at the brief's own Door-façade seam without changing scope.

- **04a — Door core:** 04.1–04.6 (wrap 04.6), branch `epic-04a-door-core`.
- **04b — Door app:** 04.7–04.13 (wrap 04.13), branch `epic-04b-door-app`.
- **Seam between them:** the Door entry points on EPIC 03's Core map-actions/session type (04.5). 04b calls
  only those entry points; 04.10's extended App/Sources scan enforces it.

EPIC 04 starts only after EPIC 03 is merged. Rulings (all resolved, 2026-09-10):
- `tasks/arbitration/arbiter-04-predispatch.md`: Q-A, Q-B, Q-C, Q-D, Q-E, Q-F, Q-G;
- `tasks/arbitration/arbiter-02-none-of-these.md`: the none-of-these spelling (02.11 `hintKey` unchanged);
- `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md`: supersedes part of Q-B. The generic hint is
  `hint_tree["none-of-these"][0]`, and no other error type's hint is ever borrowed (I2). When nothing
  resolves, the hint slot shows the node's `paraphrase`. 04.3 raises `LO_HINT_NOT_FOUND` as internal data.
  The ruling adds a data task, **04.1b**.

04a now has 7 tasks including its wrap, within the cap.

| Id | Sub | Slug | Kind | Depends | Risk | C1 seam |
|---|---|---|---|---|---|---|
| 04.1 | a | contract-interaction-card-timing-summary-tint | contract | — | seam | — |
| 04.1b | a | data-demo-none-of-these-hints | data | 04.1 | seam | — |
| 04.2 | a | core-door-item-card-keypad | impl | — | seam | — |
| 04.3 | a | core-door-a-diagnosis-flow | impl | 04.1, 04.1b, 04.2 | seam | — |
| 04.4 | a | core-door-b-expedition-flow | impl | 04.1–04.3 | seam | — |
| 04.5 | a | core-door-entries-persistence-seam | impl | 04.4 | seam | App ↔ Core state transitions (Core half) |
| 04.6 | a | epic-04a-wrap | wrap | 04.1–04.5 | mechanical | — |
| 04.7 | b | rendering-mathview | impl | 04.6 | seam | — |
| 04.8 | b | app-expedition-screens | impl | 04.6, 04.7 | seam | — |
| 04.9 | b | app-diagnosis-screens | impl | 04.8 | seam | — |
| 04.10 | b | app-sources-door-scan | impl | 04.8, 04.9 | seam | App ↔ Core (render half, static) |
| 04.11 | b | demo-acceptance-record-template | docs | 04.6 | mechanical | — |
| 04.12 | b | contract-interaction-v1-0-0 | contract | 04.8–04.10 | seam | — |
| 04.13 | b | epic-04b-wrap | wrap | all | mechanical | — |

## Task scopes (summary; the planner's full JSON output is the source)

- **04.1:** interaction-contract v0.9.2 → v0.9.3. Resolves the answer-card timing and summary tint-delta
  finalization items (Q-A). It also lands:
  - the diagnosis.md W3 copy fix (Q-D);
  - the expedition.md Q6 narrowing (Q-G);
  - DEFERRED entries for tint deltas and for hint tiers 2–3 (Q-F).
  `docs/DEFERRED.md` has exactly one writer in EPIC 04: this task.
- **04.1b:** adds `hint_tree["none-of-these"]` to every `data/demo` node: three plain-text tiers that name
  no other error type. The content is agent-authored and machine-verified (I9), as the hand-written Demo
  bundle was in EPIC 01. The same task carries these ripple edits:
  - the embedded copy `App/Sources/DemoSnapshot/nodes.json` (03.4 byte-identity test);
  - the rendering-spike count table (hint row 63 → 123, total 143 → 203) and the test that pins it;
  - the manifest hashes, only if they are no longer placeholders.

  Instruments: `core-cli validate` (schema + L0), `RenderCheck` over the new strings, and a test that each
  node's none-of-these tier 1 differs from every other key's tier 1 on that node. There is no CAS step,
  because hints are not probe answers.
- **04.2:** Core screen-content values shared by both doors. They are the item view (no answer or
  `correct_choice_id` field), the answer card built only from an `ItemResult`, and the keypad key-set
  constant.
- **04.3:** the Door A façade over DiagnosisRun's public step API, for both triggers. It derives every
  diagnosis screen's content: hypothesis card, probe items with cards, remediation (Q-B), further-level offer,
  hint prose (Q-H), and terminal lines drawn from `CoreErrorText`. The Demo budget is 1.
- **04.4:** the Door B façade over `ExpeditionRun`. The answer card is its own phase before the next item
  (I3), and there is a D27 retry. On a second miss it assembles `misses` from the exact submitted
  strings and hands off to 04.3, then resumes. It also covers the Q5 line, end/abandon (Q-G) and summary
  content.
- **04.5:** Door entries on EPIC 03's map-actions/session type, the only task that writes that file:
  - Start expedition consumes the Include queue;
  - Unit expedition, Check me here, Start another, Back to the map;
  - write-after-every-state-changing-call, with write-failure banner data.
  It owns the C1 real-composition test.
- **04.6:** 04a wrap.
- **04.7:** `MathView` in `Packages/Rendering`, with a plain-text fallback when parsing fails (Q-E). The
  Rendering product is already linked, so the pbxproj is not edited.
- **04.8:** expedition screens: item view, keypad, choice buttons, answer card with an explicit continue, and
  summary. It replaces 03.11's placeholder for Include and Unit expedition. There is no answer `TextField`.
- **04.9:** diagnosis screens: hypothesis card sheet, probe, remediation, further-level offer, and
  terminal/hint. It replaces the Check me here placeholder.
- **04.10:** extends 03.9's App/Sources scan with the Door rules and widens the allow-list by exactly the 04.5
  entries. Each new rule class has a negative control.
- **04.11:** `docs/epics/demo-acceptance-record.md` template. It lists DEMO-BRIEF §7 items 1–7 as amended and
  the §8 checklist as amended by v2.2 §B, with every line tagged simulator (agent) or device (owner).
- **04.12:** interaction-contract v0.9.3 → v1.0.0. Only the header and the § Finalization owed section change.
- **04.13:** 04b wrap. It fills only the agent half of the acceptance record and states the tap-execution
  exclusion (D29).

## Planner notes kept for spec writers

- **EPIC 03 paths are provisional.** The file scopes of 04.5, 04.8, 04.9 and 04.10 point at EPIC 03 files
  that have not landed yet (03.7 façade, 03.9 scan, 03.11 hand-off, 03.12 holder). Spec writers re-anchor
  them to the paths EPIC 03 actually lands.
- **04.10 runs after 04.8/04.9**, because its one-call-per-button rule needs real Door views. The spec writer
  must make sure 04.8 and 04.9 do not need allow-list entries before 04.10 adds them. Either land the
  allow-list widening first or merge the two steps.
- **I3 needs a façade phase.** `ExpeditionRun.answer` advances `currentItem` within the same call, so the "no
  next item without a card" guard lives in the façade (card, then continue). No landed Core file is edited.
- **Glossary.** Do not coin new `*Session*` identifiers, and no "attempt" in any identifier. The earlier
  grandfather clause for `FailedProbeAttempt` is withdrawn: arbiter ruling `tasks/arbitration/arbiter-03-audit-f1-attempt.md`
  (cross-EPIC audit 01–03 F1) renames it to `ItemMiss`, and `incorrectAttempts`/`failedAttempts:` to `misses`.
  That rename is task 03.13b and lands before EPIC 04. The EPIC 04 specs name `pendingHandoffMisses`.
  `FurtherLevelOffer`/`levelBudget` need no grandfathering: they name the **backtrack level**, a defined glossary
  term (`contracts/domain-glossary.md` § Diagnosis). The wrap grep covers new identifiers and copy.
- **Optional owner Q5.** If the owner adds a `mathmathUITests` target to the Xcode project, 04b gains one
  XCUITest task after 04.10 and still fits the cap. Without it, the tap-through stays the owner's (D29).
