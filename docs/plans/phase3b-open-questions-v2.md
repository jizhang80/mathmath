# Phase 3b — Open questions for owner ratification (v2 re-cut)

Date: 2026-09-09. **Status: RATIFIED by owner 2026-09-09 — all defaults accepted, §2 items accepted.** Ground truth: `PROJECT-BRIEF-v2.md` + `AMENDMENT-v2.1`–`v2.5`; `docs/idea.md`.
Rule (bootstrap Phase 3b): each question carries a default and a one-line trade-off; the owner ratifies or
overrides. Resolving these now saves Q5 events in execution. Full text lives in each domain doc.

## 0. v2 domain list

| # | Domain | Status 2026-09-09 |
|---|---|---|
| 1 | `curriculum-spine` | edited (trails replace the browse menu; M6 → M5) |
| 2 | `concept-graph` | edited (`region`, `position`, two new L0 rules, `Core` CLI — D33/D42) |
| 3 | `learning-objects` | edited (typed ProbeItems with distractor tags; Landmark entity — D22/I15) |
| 4 | `content-generation` | edited (Python — D41; SymPy answer checks; landmark variant; W4 build step) |
| 5 | `verification` | moved to M5 desktop web homework mode (D34); text preserved |
| 6 | `diagnosis` | **rewritten** from `tutoring-session` (Door A as in-map event) |
| 7 | `map` | **new** (Door C) |
| 8 | `expedition` | **new** (Door B; owns `StudentState`) |
| 9 | `runtime-tiers` | **rewritten** (Foundation Models, D32/D34) |
| 10 | `platform` | **rewritten** (native shell, JSON state, iCloud sync — D36) |
| 11 | `telemetry` | **rewritten** (D17 as amended, D40, v2.5 §1–§2) |
| — | `parent-view` | **removed** (D38) |

## 1. Questions pending ratification

| Domain | Q | Default | Trade-off (one line) |
|---|---|---|---|
| map | Q1 Fog return on due | No — cleared stays cleared; a *due* ring; only a failed re-probe can move to `blocked` | Never takes away earned progress; re-fogging would punish absence |
| map | Q2 Region tint | Empty regions pure fog; populated regions tinted by cleared fraction over the student's selected trails | Trail-relative is visible progress; graph-wide reads as ~0 |
| map | Q3 Horizon | D21 labels only, greyed, not tappable | Signals continuation without speculative content |
| map | Q4 Label zoom | Region names at overview; node names when drawn diameter ≥ ~44 pt [ESTIMATE]; landmark names always | Simple and testable; dense regions may overlap at mid zoom |
| map | Q5 "Include in next expedition" from node panel | Yes, one node, ahead of the scheduler if on the frontier; ignored with a message if upstream of the marker | Gives tapping a purpose; a longer queue is policy the student should not manage |
| expedition | Q1 Clear rule | Two correct on distinct items, any runs; retry counts | One clears on a guess; three feels slow |
| expedition | Q2 Spaced repetition | Fixed ladder 1/3/7/14/30 days [ESTIMATE]; advance on correct, reset on miss; ≤ 2 due slots per run | Transparent; adaptive scheduling needs data D17 forbids |
| expedition | Q3 Slot mix | 5 slots: ≤ 3 frontier (map-queued first), ≤ 2 due; either fills the other | Every run moves forward; cleared nodes still revisited |
| expedition | Q4 Numeric matching | Exact after normalisation (`3/4` = `0.75`); per-item declared tolerance, default 0; no CAS on device | Items needing symbolic comparison are authored as `mc` |
| expedition | Q5 Second miss after the run's Door A event is spent | Answer card + "We'll come back to this one"; node marked `blocked`; no hint | Keeps the 3-minute rhythm; no help until next run or "Check me here" |
| expedition | Q6 Interrupted run | Current item kept while the app lives; a terminated run is logged abandoned | No half-finished runs; at most one item's context lost |
| diagnosis | Q1 Where the `ErrorType` comes from on a phone | Distractor tagging at generation (Tier 0 lookup); Tier 1 only over an optional one-line "what did you do?", off until M4 | Deterministic and free; only as good as generated distractors |
| diagnosis | Q2 Decline the probe | Yes — `unconfirmed`, hint on origin, return | Confirmation not interrogation; thins L3 (carried from v1) |
| diagnosis | Q3 Second level | Offered, never automatic | Respects the rhythm; a decliner reaches level 2 only via the map's `blocked` marker |
| diagnosis | Q4 "Check me here" upstream of the marker | The tapped node is the origin; budget counts from it | Simple; the student can walk upstream one tap at a time (D28 intent) |
| runtime-tiers | Q2 Confidence from a `@Generable` enum | Self-reported `confidence` in [0, 1] + explicit `none_of_these`; calibrated at M4′; if flat, replace with agreement across two samplings | Cheap but may be uninformative; two samplings double latency |
| runtime-tiers | Q4 (second half) Free-text classification on by default? | Off until M4 passes; wording adaptation stays off unless M4 shows a gain | Loses the noticeable feature; on, risks drift in fixed hint sentences |
| platform | Q1 iCloud mechanism | Decided at M3 (v2.4 §1); Demo local only | Document container is simple; CloudKit gives explicit conflicts |
| platform | Q2 Content update | Background fetch, atomic swap at next launch | Graph never changes under a run; stale until relaunch |
| platform | Q3 Sync conflict merge | Per-node in `Core`: higher mastery wins, max `correct_count`, latest dates; logs unioned; latest marker | Never loses progress; may resurrect a `blocked` mark until the next probe |
| platform | Q4 App deletion | Local file goes; iCloud copy restores; no export in MVP | Platform convention; unsynced progress is the A5 trade the owner accepted |
| telemetry | Q2 Cadence and day-N buckets | ≤ 1 batch/day on launch; day-N in {1, 2–3, 4–7, 8–14, 15–30, 31+} [ESTIMATE] | Coarse enough not to fingerprint; a one-time user contributes nothing |

Carried unchanged and already ratified 2026-09-08: concept-graph Q1–Q4; content-generation Q1–Q4;
curriculum-spine Q1–Q3; learning-objects Q1–Q4 (Q2 carries a v2 note); verification Q1–Q4 (M5);
runtime-tiers Q1, Q3, Q4 (wording half); telemetry Q1 (now with the no-IP constraint hard), Q3, Q4.

## 2. Items the owner may want to veto (added on my judgement under v2.4 §2 authorisation)

- **I14** (`Core` renderer-free and single-source; D33/D42) and **I15** (landmarks real and sourced; D22)
  added to the `CLAUDE.md` invariant table so agents can BLOCK on them.
- `tutoring-session` renamed to `diagnosis` (file moved with history) rather than kept under the old name.
- Removed `unknown` from the mastery states (v2 §5 listed four): `fog` with `last_probe = nil` carries it.
- `blocked` nodes are always frontier-eligible regardless of marker position (expedition Core entities) —
  the reconciliation of D28 with I4, otherwise a remediated upstream node could never be cleared.
