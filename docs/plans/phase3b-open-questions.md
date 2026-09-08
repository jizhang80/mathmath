# Phase 3b — Open questions roll-up

Generated from the ten domain docs under `docs/domains/*.md` on 2026-09-08, for owner ratification.
Wording is compressed for this table; **the domain doc is the wording of record** for every Default and
Trade-off — read the cited doc before deciding. IDs are `<domain-shortname>-Q<n>` in the order each doc
lists its questions.

**Ratified by the owner on 2026-09-08.** All 40 open questions are ratified: eight were discussed and
ratified individually — `telem-Q3`, `parent-Q1`, `parent-Q3`, `tier-Q2`, `session-Q1`, `lo-Q3`,
`platform-Q1`, `gen-Q1` — and the remaining 32 were ratified wholesale (default accepted). Two of the eight
carry more than the bare default: `telem-Q3` (no id at all, plus a per-batch cap on `AggregateBatch`
observations feeding `ProbeStats`) and `parent-Q3` (unbounded local retention plus an explicit
clear-history action). See each domain doc's `## Open questions` section for the ratified line, and the
`Ratified` column below.

| ID | Domain | Question (≤15 words) | Default | Trade-off (≤20 words) | Depends on / conflicts with | Ratified |
|---|---|---|---|---|---|---|
| spine-Q1 | curriculum-spine | Paraphrase format and overlap threshold? | Verb-initial sentence, ≤140 chars, rejects 6-gram overlap with source | Stricter defends I6 but forces awkward wording; looser risks "insubstantial excerpt" line | Feeds every downstream paraphrase consumer (parent-view SuggestedAction text, LO Explanations use own text, not this) | ✅ default |
| spine-Q2 | curriculum-spine | Do streamed courses sharing a code share one Expectation? | No — one per (course, code), `equivalent_to[]` links them | Duplication inflates bundle; merging forces one paraphrase across vintages/depths | Shapes concept-graph's L0 coverage check granularity (every code ↔ ≥1 Node) | ✅ default |
| spine-Q3 | curriculum-spine | Addendum conflicts with 2005 text — who wins? | Addendum wins for touched codes; base survives as provenance | Simple, but drops phrasing some classrooms follow | Interacts with concept-graph's "removals are the dangerous class" re-check on Ministry revision | ✅ default |
| graph-Q1 | concept-graph | Shape of the confidence formula? | Bounded additive prior per source tag + generation_agreement, clamped [0.1, 0.9], then Beta-style update from probe_stats | Transparent, but weights arbitrary until L3 data exists | Depends on gen-Q1/Q2 (run count/independence feed `generation_agreement`); conflicts with telem-Q3 — no install id means no per-install de-duplication of the probe data this formula updates on | ✅ default |
| graph-Q2 | concept-graph | What does "unmastered" mean with no prior data? | Unknown counts as a probeable candidate | Diagnostic reach/early L3 data vs. probing nodes the student already knows | Feeds session-Q1 (probe decline thins the very data this default is betting on) | ✅ default |
| graph-Q3 | concept-graph | Tie-breaking among equally deep prerequisites? | Highest edge confidence, then lowest depth marker, then node id | Deterministic and testable, but biases probing toward confident edges, starving disputed ones | Depends on graph-Q1 (confidence formula must exist first) | ✅ default |
| graph-Q4 | concept-graph | How do disputed edges surface in the product? | Invisible to Student/Parent, listed only in the Owner's report | Keeps the product's confident voice, but no in-product signal a weak edge drives wrong hypotheses | None found | ✅ default |
| lo-Q1 | learning-objects | Number of hint tiers? | Three (nudge → targeted → worked step), fixed for all nodes | Predictable generation/UI; a hard node earns no extra depth | None found | ✅ default |
| lo-Q2 | learning-objects | ProbeItem pool size per node? | 6 [ESTIMATE: three non-overlapping probes at ≤2 backtracks/session] | Bigger pools cost bundle size/dilute per-item stats; smaller make repeats recognisable | Depends on I4's fixed ≤2-backtrack cap; interacts with telem-Q4 (30-probe minimum aggregate — pool size caps how fast that fills) | ✅ default |
| lo-Q3 | learning-objects | May a hint tier reveal the final answer? | Yes at tier 3 — works the failing step, not the whole solution | Tree can't become a gate, but tier 3 may duplicate the answer view | None found | ✅ default |
| lo-Q4 | learning-objects | Downstream handling of `none_of_these`? | Abstention — no hypothesis/probe/backtrack; frequency reaches telemetry as enum-incompleteness evidence | Session ends with a located error and no explanation; a fallback hypothesis would be a guess | Assumes a telemetry event kind for per-node `none_of_these` frequency that telemetry's own TelemetryEvent enum does not clearly name (see consistency review finding 1) | ✅ default |
| gen-Q1 | content-generation | How many independent runs, and what k? | 3 runs, intersection at k = 2 | Cheap but a weak independence signal; 5 runs would sharpen statistics at cost | Feeds graph-Q1 directly (`generation_agreement` is this count) | ✅ default |
| gen-Q2 | content-generation | Vary prompts, models, or neither across runs? | Vary prompt phrasing at a fixed model, recording both | Cheap/comparable, but shared priors make "independent" generous | Feeds graph-Q1's independence assumption | ✅ default |
| gen-Q3 | content-generation | What happens when a node's intersection is empty? | Emit nothing, list it in the report; graph's connectivity check catches it | Honest, but can block the D14 starting chain until re-run | Can stall concept-graph W1's "starting chain connected end-to-end" check | ✅ default |
| gen-Q4 | content-generation | Reproducibility guarantee and cost ceiling? | Record seed/model/temperature/PromptVersion; claim re-runnability, not bit-exact reproduction; Owner-set token ceiling per batch | Honest about drift and safe against runaway cost, but weakens the audit story for an older bundle | None found | ✅ default |
| verify-Q1 | verification | Equivalence strictness — symbolic only, or numeric fallback? | Symbolic first; numeric sampling at a fixed seed if inconclusive, method recorded | Sampling rescues undecidable cases but is probabilistic; fixed seed/method keeps it reproducible | None found | ✅ default |
| verify-Q2 | verification | Is a correct step that skips several manipulations accepted? | Yes — equivalence to the previous step is the test, not step size | Matches "teacher not interrogator"; a big leap can hide where a later error was seeded | None found | ✅ default |
| verify-Q3 | verification | Per-step / per-problem timeout? | 2 s per step, 10 s per problem [ESTIMATE, re-set from M4′ latency data] | Tight bound turns hard-but-valid steps into timeout; loose bound stalls the UI | Depends on the M4′ Pyodide first-load latency measurement (brief §8) | ✅ default |
| verify-Q4 | verification | How are unsupported constructs (matrices, calculus notation) handled? | Report `VERIFY_UNSUPPORTED`, fall back to answer-only mode | Honest under I1/I2, but that student gets the weakest experience | None found | ✅ default |
| session-Q1 | tutoring-session | May the student decline the probe? | Yes — Diagnosis stays `unconfirmed`, no remediation | Keeps the probe a confirmation; thins `ProbeStats` | Weakens graph-Q2's data bet and telem-Q4's 30-probe minimum-aggregate threshold | ✅ default |
| session-Q2 | tutoring-session | What happens on "none of these"? | Generic hint, no hypothesis, no probe | No guessed diagnosis (I2); least help where the catalogue is weak | Same default as lo-Q4; also gated by tier-Q3 (model returning "none of these" with high confidence) | ✅ default |
| session-Q3 | tutoring-session | How many attempts before suggesting a stop? | None — no nagging | Keeps teacher-not-chatbot; no fatigue signal | None found | ✅ default |
| session-Q4 | tutoring-session | Does a session survive a page reload? | Yes — resume the last Attempt | Costs persisted intermediate state; losing work on refresh costs trust | Depends on platform-Q2/Q3 (asset swap timing and quota-exceeded eviction order both touch what's still in the Store on resume) | ✅ default |
| tier-Q1 | runtime-tiers | What are the `Threshold` values? | 0.7 for classification and mapping [ESTIMATE], tuned by M4′ | Higher = more Tier 0, safe but less helpful; lower risks confident wrong guesses | Depends on the M4′ spike, which consumes gen's SyntheticSolutionSet (gen-Q1-4) and lo's enum (lo-Q1-4) | ✅ default |
| tier-Q2 | runtime-tiers | Is the WebLLM fallback automatic or opt-in? | Opt-in, given the ≈2 GB download [ESTIMATE] | Fewer students reach Tier 1; automatic spends disk unasked, risks eviction | Interacts with platform-Q3 (quota handling) and platform-Q4 (self-host vs CDN, bundle size) | ✅ default |
| tier-Q3 | runtime-tiers | Model returns "none of these" with high confidence — trust it? | Treat as abstention, counted separately in M4′ misuse rate | A novel error looks like model failure; trusting it hides a gap in the enum | Directly gates session-Q2's "none of these" default | ✅ default |
| tier-Q4 | runtime-tiers | Is hint wording adaptation on by default? | Off until M4 passes acceptance | Loses the one Tier 1 feature a student notices; on risks drift in fixed sentences | None found | ✅ default |
| parent-Q1 | parent-view | Access control on a shared device? | Separate `/parent` route, no PIN | PIN is a credential (D19 rules out accounts) and fails open anyway; without one a student can hide a session by omission | None found | ✅ default |
| parent-Q2 | parent-view | Can the student see the parent view? | Yes — nothing hidden | Avoids two contradictory accounts of one session, but rules out franker parent-only wording | None found | ✅ default |
| parent-Q3 | parent-view | `SessionRecord` retention window? | Unbounded, local only (D19) | Better `Trend`, costs few bytes, but an indefinite record of a child's mistakes with no delete affordance | None found | ✅ default + clear-history action |
| parent-Q4 | parent-view | Export or print for a teacher meeting? | None in MVP | Makes "ask the teacher about Y" actionable, but is the first artefact that could carry data off-device | Directly in telem-Q1/telem-Q3 territory (D17/D19) — export reopens the identifiability question telemetry was built to avoid | ✅ default |
| parent-Q5 | parent-view | Is `SuggestedAction` from templates only? | Yes — no model | Deterministic, testable, free, but reads repetitively over many sessions | Depends on spine-Q1 (paraphrase text is what fills the templates) | ✅ default |
| telem-Q1 | telemetry | Where does the write endpoint live? | Deferred to Phase 5, between a serverless function and a hosted static-form endpoint | Serverless gives validation/clean export but its logs typically capture IPs, defeating D17 unless disabled; a form endpoint cedes control to a third party | Conflicts with telem-Q3's "no id at all" stance if IP logging isn't disabled | ✅ default |
| telem-Q2 | telemetry | Batch cadence? | At most once/day, on app start, when online | Daily blurs session boundaries, keeps request rate low; more frequent recovers single-use-student data but makes sessions distinguishable in the stream | Interacts with telem-Q3 — more frequent batches partially re-identify via timing even with no id | ✅ default |
| telem-Q3 | telemetry | Is a random per-install id acceptable? | No id at all — aggregate only | An install id would allow de-duplication/per-student sequences (stronger L3 evidence), but any stable id is a fingerprint under D17 | Conflicts with graph-Q1 (Beta-style confidence update assumes independent probe observations; without dedup a heavy single-student user can skew an edge's stats) | ✅ default + per-batch cap |
| telem-Q4 | telemetry | Minimum aggregate before an edge's data may move `Confidence`? | 30 upstream probes per edge [ESTIMATE, mirrors M4′ synthetic-set size] | Low threshold updates confidence early where data is thinnest, risking noise on a disputed edge; high threshold leaves L3 silent for a long stretch | Depends on lo-Q2 (probe pool size caps fill rate) and session-Q1 (decline rate thins the pool further) | ✅ default |
| platform-Q1 | platform | Hard-block or warn on a failed environment check? | Warn and proceed, except where WebGPU/storage would break Tier 1 or the store | Maximises reach, but a machine quietly missing D8 gives a slow first impression the owner can't distinguish from a defect | None found | ✅ default |
| platform-Q2 | platform | Asset update policy? | Background download, atomic swap at next launch | The graph never changes under a running session, but a student can sit on a stale bundle indefinitely if the tab is never closed | Feeds session-Q4 (what's active in the Store when a reload resumes) | ✅ default |
| platform-Q3 | platform | Storage quota handling when `PLATFORM_QUOTA_EXCEEDED` fires? | Request persistent storage on first load; on overflow keep session records and consent, drop cached bundles first | Preserves the parent view and L3 evidence, but a dropped bundle needs a re-download an offline user cannot perform | Interacts with tier-Q2 (WebLLM download competes for the same headroom) | ✅ default |
| platform-Q4 | platform | Self-host Pyodide, or fetch from a CDN? | Self-host, for offline | Keeps the offline promise and removes a third party from the load path, at the cost of bundle size on the static host | Interacts with tier-Q2 (both compete for the same storage budget under D8) | ✅ default |

**Row count: 40** (spine 3, concept-graph 4, learning-objects 4, content-generation 4, verification 4,
tutoring-session 4, runtime-tiers 4, parent-view 5, telemetry 4, platform 4).

## Suggested ratification order

1. **Content shape** — `spine-Q1, spine-Q2, spine-Q3, verify-Q1, verify-Q2, verify-Q3, verify-Q4, lo-Q1, lo-Q3`.
   Fixes the atomic units (paraphrase format, equivalence rules, hint depth) every other domain builds on;
   none of these depend on a decision made elsewhere.

2. **Generation & graph statistics** — `gen-Q1, gen-Q2, gen-Q3, gen-Q4, graph-Q1, graph-Q2, graph-Q3, graph-Q4, lo-Q2, lo-Q4`.
   Run-count/independence settings feed straight into the graph confidence formula and disputed-edge
   handling; probe pool sizing and `none_of_these` handling depend on the hint/probe shape from batch 1.

3. **Runtime tiers** — `tier-Q1, tier-Q2, tier-Q3, tier-Q4`.
   Threshold values are tuned from the M4′ spike, which consumes the synthetic set and enum settled in
   batch 2 — cannot be ratified earlier.

4. **Session flow** — `session-Q1, session-Q2, session-Q3, session-Q4`.
   Probe-decline, `none_of_these`, and reload behaviour sit directly on the tier-fallback and
   graph/probe mechanics ratified in batches 2–3.

5. **Telemetry** — `telem-Q1, telem-Q2, telem-Q3, telem-Q4`.
   Endpoint hosting, cadence and the no-id stance determine what evidence batch-2's confidence formula
   can actually use; needs the session/tier event shape settled first, and should close before the
   parent-view export question that touches the same privacy boundary.

6. **Parent view & platform operations** — `parent-Q1, parent-Q2, parent-Q3, parent-Q4, parent-Q5, platform-Q1, platform-Q2, platform-Q3, platform-Q4`.
   Parent view only reads settled `SessionRecord`/graph/telemetry data, and platform's storage/update
   policy is an operational concern largely independent of content decisions — safe to close last, though
   `parent-Q4` should be revisited if `telem-Q1`/`telem-Q3` change.
