# Contract: Runtime tiers (LOCK-FIRST)

**Contract version:** v1.0.0 · Source: D7, D15, D32, D34, v2.1 A2–A4; I1, I2; `docs/domains/runtime-tiers.md`

> Tier 0 is the product. Tier 1 adds two optional calls on eligible devices. Tier 2 does not exist.

## Tier 0 (always)
- Item checking, hypothesis formation (graph query + distractor lookup), fringe/scheduler, layout, state
  transitions, hint delivery from stored tiers. No model, no network. A suite runs all three doors with the
  Tier 1 adapter forced unavailable and connectivity absent; it is a wrap-gate item for every App EPIC (I2).

## Tier 1 (iOS/iPadOS 26+, Apple Intelligence available — D34)
- **Framework:** Foundation Models, `LanguageModelSession`, outputs typed with `@Generable`. No other model
  runtime (no WebLLM, no cloud) may be linked into the app; a spec adding one is BLOCKed (D15, D36).
- **Availability:** `SystemLanguageModel.default.availability` checked at launch and on change; anything but
  `.available` → Tier 0 silently; Settings › Intelligence shows one line why. Never a prompt to enable it.
- **Calls (closed set):**
  | task | input | output type | threshold | fallback |
  |---|---|---|---|---|
  | `classify` | the student's optional one-line "what did you do?" + the node's `ErrorType` catalogue | `@Generable struct { error_type: <enum incl. none_of_these>, confidence: Double in 0…1 }` | 0.7 [ESTIMATE: Q1, tuned at M4′] | the Tier 0 distractor-tag result stands; `FallbackDecision{classify, below_threshold}` |
  | `reword` | one hint tier's stored text | `@Generable struct { text: String }` | deterministic acceptance check: numbers, symbols and the step described unchanged | the stored wording; `FallbackDecision{reword, …}` |
- **Gating rules:** every call has a timeout [ESTIMATE: 4 s] and a guardrail handler; a late, refused or
  below-threshold result is a `FallbackDecision` (`task, reason, confidence`) — persisted locally, emitted
  to telemetry as enums only. No retry loop. The student's typed line never leaves the call and never
  reaches telemetry or state (I5).
- **Never guesses (I2):** no path turns an unconfirmed `ClassificationResult` into a `Diagnosis`; a
  suggestion is shown for the student to confirm; the probe alone confirms. **Never decides correctness
  (I1):** the adapter exposes no call that takes an answer or a step; `expedition` and `diagnosis` item
  checking do not import the adapter (dependency test).
- **Defaults:** both features **off** until M4 passes acceptance (Q4); `reword` stays off after that unless
  M4 shows a measured gain.

## M4′ spike (owner, offline)
- Same `classify` call over the `SyntheticSolutionSet` (six-way log-equation enum), on this Mac or an
  eligible device; report top-1, confusion matrix, `none_of_these` misuse, abstention at threshold; go line
  top-1 ≥ 80 % [ESTIMATE: owner-set]. Below → D15 architecture revisit. No eligible runtime → Q5 stop.
- If self-reported confidence proves flat, replace the threshold with agreement across two samplings (Q2);
  record the switch here as a versioned change.

## Tier 2 — queued (D15, v2.1 A4)
- Not built. Would require an API-key proxy server (D36) and re-opens D17's "no identifier" analysis.

## Enforcement
- type system: `@Generable` result types make off-schema output unrepresentable (App EPIC).
- test: adapter-absent suite; dependency test that `Core`, `expedition` and `diagnosis` checking never
  import `FoundationModels` (I14 test already forbids it in `Core`).
- config: thresholds and timeouts live in one `TierConfig` constant file cited by name.
