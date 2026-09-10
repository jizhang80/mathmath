# ARBITER RULING: task 02.11 — which probe outcomes emit `diagnosis.probe_completed`

**Date**: 2026-09-10
**Spec**: `tasks/epic-02-task-11-diagnosis-machine-seam.md`
**Trigger**: writer↔reviewer non-convergence (2 BLOCK cycles). Cycle 1 (dead `.capped` branch) was fixed and is
not reopened. Cycle 2: the spec's §6 pinned "`.diagnosisProbeCompleted` NOT emitted on `.declined`, IS emitted on
`.unavailable`", which contradicts the domain doc's payload `{ candidate_id, edge_id, pass|fail|declined }`.

## Ruling

1. `.diagnosisProbeCompleted` **is emitted** on probe outcomes `pass` (`ProbeOutcome.refuted`), `fail`
   (`ProbeOutcome.confirmed`) and `declined` (`ProbeOutcome.declined`) — exactly once per level at which one of
   these outcomes occurs, after `.diagnosisHypothesisFormed` for that level and before any
   `.diagnosisNodeBlocked` / `.diagnosisReturned`.
2. `.diagnosisProbeCompleted` **is not emitted** on `ProbeOutcome.unavailable` (`DIAG_PROBE_UNAVAILABLE`). The
   terminal is carried by `.diagnosisReturned` plus `DiagnosisOutcome.code == .diagProbeUnavailable`.
3. **Representation of a declined probe.** `DiagnosisProbeResult(outcome: .declined, results: [],
   incorrectAttempts: [], code: nil)`; the diagnosis terminal is `.unconfirmed` with `code == nil`,
   `probeResults == []`, no `probeLog` row, `depthReached == level - 1`. Because `CoreEvent` is a bare name
   (no payload), the `pass|fail|declined` payload value is carried by the pairing value
   `DiagnosisProbeResult.outcome`, mapped `refuted → pass`, `confirmed → fail`, `declined → declined`;
   `unavailable` has no payload value, which is why it emits no event.

No contract text change is needed. No locked decision changes. Not a Q5.

## Evidence

| # | Source | Text | Bearing |
|---|---|---|---|
| 1 | `docs/domains/diagnosis.md:116-117` (Notifications produced) | "`diagnosis.probe_completed` — `{ candidate_id, edge_id, pass\|fail\|declined }`." | The payload's outcome enum is closed at `pass\|fail\|declined`. `declined` is a value the event carries, so the event fires on decline. `unavailable` is not a value, so an unavailable probe cannot populate the event. |
| 2 | `contracts/domain-glossary.md:42` | "**Probe** — two items on the candidate, ~60 s; outcome **pass / fail / declined** → diagnosis outcome **refuted / confirmed / unconfirmed / capped**." | Contract-level vocabulary: a probe has three outcomes, and `declined` is one of them. "Unavailable" is not a probe outcome. It is a failure to form a probe. |
| 3 | `contracts/interaction-contract.md:86-89` (`## 4. Diagnosis (Door A)`, `probe` bullet) | "`pass` → `refuted` … `fail` → `confirmed` … `declined` → `unconfirmed` → hint → returned. Fewer than 2 items → `DIAG_PROBE_UNAVAILABLE` → `unconfirmed`." | Three arrows run from probe outcomes (`pass`, `fail`, `declined`). The unavailable case is stated separately as an error code that bypasses the probe. Both reach `unconfirmed`, but only `declined` is a probe outcome. |
| 4 | `docs/domains/diagnosis.md:68-74` (W3) | "**Pre:** a `Diagnosis`; two items available. … 2. Draw 2 `ProbeItem`s …; fewer → `DIAG_PROBE_UNAVAILABLE`, outcome `unconfirmed`, hint and return. … **Post:** `diagnosis.probe_completed`" | W3's precondition is "two items available". The unavailable exit returns early, so W3's Post (`probe_completed`) does not apply to it. Decline is W3 step 1, taken with the precondition in force. |
| 5 | `docs/domains/diagnosis.md:39-40` (ProbeRun) | "checked in code (I1); pass/fail; declinable (Q2)." | Same three-outcome model. |
| 6 | `contracts/interaction-contract.md:101-115` (`## 5. Notifications (in-process names, exact)`) | name list + "Payloads are ids, enums, booleans and small integers only (I5)." | This lists names only and assigns no per-outcome emission rule, so there is no conflict with the ruling. The spec's former §6 cited this text as support for its opposite reading. That was a misreading, because this clause says nothing about when the event fires. |
| 7 | `contracts/telemetry.md:22-23`; `docs/domains/telemetry.md:44-45` | `item_result` … "diagnosis W3"; source "`expedition.item_answered`, `diagnosis.probe_completed`" with fields "node id, correct, retry flag, tier"; `edge_observation` "derived on device per prerequisite edge of the item's node", `downstream_result ∈ {pass, fail}` | Telemetry derives its per-item facts from the probe's checked items. On a decline there are no items, so no `item_result` and no `edge_observation` are produced. The consumer derives from `DiagnosisProbeResult.results` (empty), so emitting the event on decline is harmless. On an unavailable probe there is nothing to derive, which is consistent with no event. Telemetry derivation is EPIC 11 scope, and this file constructs no telemetry payload. |
| 8 | `Packages/Core/Sources/Core/Events/CoreEvent.swift:3-8, :27` | "`CoreEvent` is a bare name registry — it carries no payload; … a caller that needs to pair an event with data defines its own pairing type" · `case diagnosisProbeCompleted = "diagnosis.probe_completed"` | The case is bare, so the payload value is carried by `DiagnosisProbeResult.outcome` (the pairing type). No `CoreEvent` edit is needed. |
| 9 | `PROJECT-BRIEF-v2.md:65` (D11); `:143` | "Diagnoses are hypotheses confirmed by probes; probes double as validation data." · "probe on X (2 items, ~60 s)" | Validation data comes only from checked items (pass/fail). The brief pins no event rule, so it is consistent with the ruling. |

## Findings analysis

| # | Claim | Verification | Classification |
|---|---|---|---|
| 1 | The spec's "no event on `.declined`" contradicts the domain payload `pass\|fail\|declined` | Evidence 1, 2, 3 | VALID. The spec must emit the event on decline. |
| 2 | The spec's "event on `.unavailable`" lacks support | Evidence 1, 3, 4. Unavailable is absent from the payload enum and exits W3 before its Post. | VALID. The spec must not emit the event on unavailable. |
| 3 | (Implicit in the former spec §6) `interaction-contract.md` § 5 supports the no-event-on-decline reading | Evidence 6. § 5 is a name list plus an I5 payload-type rule. | INVALID as support. It is neutral, and the ruling is consistent with it. |

## Contract / doc text

No contract change is required. The one optional clarification is a **docs** edit (not a contract), and nothing
blocks on it. `docs/domains/diagnosis.md` W3 **Post** could read "`diagnosis.probe_completed` (outcome
`pass|fail|declined`; not emitted on `DIAG_PROBE_UNAVAILABLE`) → …". It is owned by whichever docs-maintenance
pass next touches the diagnosis domain doc. It is not owned by task 02.11, whose §2 scope excludes `docs/*`.

## Spec sections changed

§1 AC3, AC4; §3 (added the verbatim glossary, telemetry and CoreEvent anchors, plus this ruling); §4 step 11.e;
§5 T1, T5 (new negative control), T9; §6 (the probe-completed bullet was replaced, and one mapping bullet was
added). The capped/budget logic (§1 I4, AC6–AC8, §4 steps 7, 9, 11.g, §6 first two bullets) is unchanged.
