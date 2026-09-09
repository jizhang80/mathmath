# Domain — runtime-tiers

Prefix: `TIER`. Ground truth: `PROJECT-BRIEF-v2.md` + amendments (D7, D15, D32, D34, v2.1 A2–A4);
invariants I1–I15 in `CLAUDE.md`.

## Purpose

Owns Tier 1: every language-model call the iOS app makes, and the confidence gating that keeps Tier 0 a
complete product on its own (D7 / I2). Tier 1 is the **Foundation Models framework** — Apple's on-device
system model, called with `@Generable` guided generation so every output is a typed value, never free text
(D32) — available only on iOS/iPadOS 26+ with Apple Intelligence-capable hardware and Apple Intelligence
enabled (D34) [SOURCED: Apple Newsroom 2025-09; WWDC25 Session 286]; availability is checked at runtime and
ineligible devices run Tier 0 silently. There is no model download to manage and no WebGPU or storage
budget: the OS owns the model. AI is primarily a build-time tool for this product (v2.1 A3); runtime AI is
limited to the two calls below. Tier 2 (cloud) stays queued (D15), now rationalised as a possible
attractor rather than a fallback (v2.1 A4). Milestones **M4′** (spike), **M4** (integration). The M5
desktop homework mode's Tier 1 (Chrome Prompt API) is out of this domain's MVP scope and is designed at M5.

## Actors and roles

| Actor | Can do here | Cannot |
|---|---|---|
| Student | See whether Tier 1 is active; turn it off | Raise a `Threshold`; make the model authoritative |
| Owner | Run the M4′ spike on this Mac or an eligible device; set thresholds; read the matrix | Change a locked decision (D7, D15) |
| System | Read `CapabilityFacts` (platform); call the model under a `@Generable` schema; gate on `Threshold`; log fallbacks | Use model output for correctness (I1) or an unconfirmed diagnosis (I2) |
| Local model (Tier 1) | Return `{error_type ∈ enum, confidence}` over volunteered text; a re-worded hint | Emit free text to the student, out-of-enum values, new mathematics |
| Generation model | Supply the `SyntheticSolutionSet` M4′ scores against | Run in the product (offline only, D12) |

## Core entities

- **TierCapability** — the startup verdict from **platform**'s `CapabilityFacts`: the system language
  model reports *available*, or a reason it does not (device ineligible, Apple Intelligence off, model not
  ready). Cached per launch; re-checked when the OS reports a change. Never sent as a device property (I5);
  only the boolean "a Tier 1 path was active" travels with a diagnosis event (**telemetry**).
- **ModelAdapter** — one interface over `LanguageModelSession`, two calls: **classification** —
  `{error_type ∈ enum, confidence}` over the node's `ErrorType` catalogue (**learning-objects**),
  `none_of_these` included, input being the student's optional one-line "what did you do?" (**diagnosis**
  Q1); **wording adaptation** — a rephrase of a `HintTree` tier whose semantics learning-objects fixes.
  Both outputs are `@Generable` types, so off-schema output is unrepresentable; out-of-enum is impossible by
  construction, and only `confidence` needs gating.
- **ClassificationResult** — `{error_type, confidence}`; **Threshold** — one value per task; below it
  Tier 0 behaviour is the answer; **FallbackDecision** — task, reason (`below_threshold`, `unavailable`,
  `timeout`, `guardrail`), the confidence seen; persisted locally, emitted to telemetry under consent.

## Workflows

### W1 — Detect capability at launch
**Pre:** `platform.capability_facts`. **Steps:** query the system model's availability; on anything but
*available* run Tier 0 silently — no prompt to enable Apple Intelligence beyond a line in Settings.
**Post:** `TierCapability` cached; `tier.capability_detected`.

### W2 — Classify volunteered text (Tier 1 path of diagnosis W1)
**Pre:** Tier 1 available and the feature on (Q4); the student typed the optional line; the node's enum
loaded. **Steps:** one call under the `@Generable` result type with the enum as a `@Guide`; a timeout or a
guardrail refusal is a `FallbackDecision`; gate `confidence` on the `Threshold`. **Post:** a
`ClassificationResult` shown to the student as a suggestion to confirm — the Tier 0 distractor lookup
stands otherwise (I2).

### W3 — Adapt hint wording
**Pre:** Tier 1 available, the feature on (Q4), a hint tier from the `HintTree`. **Steps:** ask for a
rephrase only; reject output changing numbers, symbols or the step described (a deterministic check on
extracted tokens); on rejection or timeout return the stored wording. **Post:** `tier.wording_adapted`.

### W4 — Decide and log a fallback
**Pre:** a call that returned late, refused, or below `Threshold`. **Steps:** construct a
`FallbackDecision`, hand the caller Tier 0 behaviour, persist locally, emit under consent (I5); no retry
loop. **Post:** `tier.fallback_decided`.

### W5 — Run the M4′ spike (offline, Owner)
**Pre:** the `SyntheticSolutionSet` (**content-generation**) for the logarithmic-equation node and its
6-value enum [SOURCED: brief §8]; an eligible device, or this Mac (macOS 26 on Apple Silicon runs the same
framework — a `[SOURCED: WWDC25 Session 286]` claim to re-verify at spike time; the phone measurement is
still taken before M4 wraps). **Steps:** run the classification call over the set with a `@Generable` enum
output; compute top-1 accuracy, confusion matrix, `none_of_these` misuse rate and abstention at low
confidence; compare against top-1 ≥ 80 % [ESTIMATE: owner-set], an upper bound since synthetic errors are
cleaner. **Post:** a report fixing initial `Threshold`s; below the bar D15 triggers an architecture
revisit, not a patch. **No eligible device and no Apple Intelligence on the Mac → Q5 owner-stop, never a
workaround** (v2.2).

## UI surfaces

Native: **Settings › Intelligence** — whether Tier 1 is active and why not (one line), a Tier 1 switch.
Fallbacks are silent by design; W5 is Owner-run, no screen.

## Notifications produced

- `tier.capability_detected` — `{ available: bool }` → **platform**, **telemetry** (boolean only).
- `tier.classification_returned` — `{ task, confidence, above_threshold }` → **diagnosis**.
- `tier.fallback_decided` — `{ task, reason, confidence }`, `tier.wording_adapted` — `{ node_id, tier }`
  → **diagnosis**, **telemetry**.

## Errors produced

All are recoverable and end in Tier 0 behaviour.

- `TIER_UNAVAILABLE` — the system model is not available on this device or right now; internal.
- `TIER_GUARDRAIL_REFUSED` — the framework's safety guardrail declined the request; fallback logged.
- `TIER_BELOW_THRESHOLD` — confidence under `Threshold`; the Tier 0 result stands (I2).
- `TIER_TIMEOUT` — the call exceeded its bound; fallback logged.

## Invariants enforced here

- **I2**, primary owner — every call is threshold-gated with a named Tier 0 fallback; a suite runs the
  product with the adapter forced unavailable, and no path turns an unconfirmed `ClassificationResult`
  into a `Diagnosis`.
- **I1**, co-owner with **verification** (M5) — the interface exposes no correctness call; item checking
  in **expedition** and **diagnosis** never imports this domain; enforced by a dependency test.
- **I5** — fallback and evaluation records carry ids, enums and confidences only; the student's typed line
  never leaves the call. **I11** — the 80 % bar ships with its tag.
- **I14** — `Core` does not import Foundation Models; the adapter lives in the app layer.

**Seams:** ↔ diagnosis (`ClassificationResult`, wording, `FallbackDecision`); learning-objects → (enum,
hint text as fixed input); content-generation → (`SyntheticSolutionSet`, W5); platform → (capability
facts); → telemetry (booleans and enums under consent).

## Open questions

**Q1 — What are the `Threshold` values?** **Default:** 0.7 for classification [ESTIMATE], tuned by M4′.
**Trade-off:** higher means more Tier 0, safe but less helpful; lower risks confident wrong suggestions.
**Ratified 2026-09-08:** default accepted; carried.

**Q2 — How is `confidence` obtained from a guided-generation enum?** **Default:** the `@Generable` result
type carries a self-reported `confidence: Double` in [0, 1] with a `@Guide` range, plus `none_of_these`
as an explicit abstention; calibration measured at M4′, and if self-report proves uninformative the
threshold is replaced by "abstain unless the enum value is repeated across two samplings". **Trade-off:**
self-reported confidence is cheap and may be flat; two samplings double latency.
**Ratified 2026-09-09:** default accepted.

**Q3 — What if the model returns `none_of_these` with high confidence?** **Default:** abstention — the
Tier 0 result stands, no hypothesis from the text — counted separately in M4′ misuse. **Trade-off:** a
novel error looks like model failure; trusting it hides a gap in the enum.
**Ratified 2026-09-08:** default accepted; carried.

**Q4 — Are the two Tier 1 features on by default?** **Default:** both off until M4 passes acceptance;
wording adaptation stays off after that unless M4 shows a measurable gain. **Trade-off:** loses the one Tier
1 feature a student would notice; on, it risks drift in exactly the sentences learning-objects fixed.
**Ratified 2026-09-08 (wording):** default accepted; classification-of-text is new and pending.
**Ratified 2026-09-09:** classification-of-text off by default — accepted.

## Change log

| 2026-09-08 | Drafted (Phase 3b, Chrome Prompt API + WebLLM). Open questions ratified. |
| 2026-09-09 | Rewritten for Foundation Models on iOS (D32, D34, v2.1 A2–A4, v2.2 M4′ retarget): no download management, no WebGPU/storage budget, `@Generable` outputs, free-text node mapping dropped with the homework entry. Q2 and Q4's second half pending owner ratification. |
