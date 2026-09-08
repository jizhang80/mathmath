# Phase 3b — Domain design doc spec (authoring instructions)

Applies to every file in `docs/domains/<domain>.md`. Ground truth: `PROJECT-BRIEF-v1.md` (D1–D19 locked),
invariants I1–I13 in `CLAUDE.md`, ratified domain list in `docs/plans/phase3-domain-decomposition.md`.
Writing rules: English; every number tagged `[SOURCED: …]` / `[ESTIMATE: …]`; no time estimates;
no verbatim Ministry curriculum text (cite codes only). Docs are for the owner (product tester, not a
content reviewer) and for agents that will later write contracts and task specs — be concrete.

## Template (sections in this order, these headings verbatim)

1. `## Purpose` — what this domain is for, who it serves, which milestones (from the decomposition table).
2. `## Actors and roles` — table: actor | what they can do here | what they cannot. Actors are drawn from
   the closed set: **Student**, **Parent**, **Owner** (runs offline pipelines, product-tests), **System**
   (deterministic runtime), **Local model** (Tier 1), **Generation model** (offline, Claude API).
3. `## Core entities` — narrative, not schema. Name each entity once and reuse the name everywhere. Only
   describe entities this domain **owns** (ownership table below); reference others by name + owning domain.
4. `## Workflows` — one subsection per significant operation: `### W<n> — <name>` with **Pre**
   (preconditions), **Steps** (numbered; name the tier — Tier 0 / Tier 1 — for every step that could
   involve a model, and the Tier-0 fallback), **Post** (what is true afterwards, what is persisted, what
   events are emitted). Every workflow must terminate.
5. `## UI surfaces` — placeholder route paths per role (`/student/...`, `/parent/...`, none for offline
   domains); confirmed in Phase 4.
6. `## Notifications produced` — in-app events this domain emits for other domains: `domain.event_name`
   with a one-line payload description. Consumers named.
7. `## Errors produced` — error codes `DOMAINPREFIX_REASON` (upper snake; prefix from the table below),
   each with: when it fires, what the user sees (or "internal"), whether it is recoverable.
8. `## Invariants enforced here` — which of I1–I13 this domain is the primary owner of, and the concrete
   mechanism (type, schema check, test, gate).
9. `## Open questions` — numbered `Q<n>`; each has **Default:** (the proposed answer) and **Trade-off:**
   (one line). Only questions the owner must decide; anything derivable from the brief is decided in-text
   with a citation. Aim for 3–8 per domain.
10. `## Change log` — `| 2026-09-08 | Drafted (Phase 3b). |`.

Target length 4–8 KB per doc.

## Entity ownership (one owner per entity; others reference by name)

| Domain | Prefix | Owns |
|---|---|---|
| curriculum-spine | `SPINE` | Course, Strand, Expectation (code + paraphrase + official link), Spine bundle |
| concept-graph | `GRAPH` | Node, Edge, Source tag, Confidence, ProbeStats, Graph bundle, L0 report |
| learning-objects | `LO` | Explanation, WorkedExample, ErrorType (per-node enum incl. "none of these"), HintTree (tiers per ErrorType), ProbeItem, LearningObject bundle |
| content-generation | `GEN` | GenerationRun, PromptVersion, RunOutput, IntersectionResult, SyntheticSolutionSet |
| verification | `VERIFY` | Problem (LaTeX), Step, StepVerdict, FirstFailure, DomainCheck |
| tutoring-session | `SESSION` | Session, Attempt, Diagnosis (hypothesis + candidates), ProbeRun, Remediation, SessionRecord |
| runtime-tiers | `TIER` | TierCapability, ModelAdapter, ClassificationResult (with confidence), Threshold, FallbackDecision |
| parent-view | `PARENT` | NodeStatus, Gap, Trend, SuggestedAction, ParentSummary |
| telemetry | `TELEM` | TelemetryEvent, ConsentState, AggregateBatch |
| platform | `PLATFORM` | AssetManifest, AssetVersion, EnvironmentCheck, Store (IndexedDB), ServiceWorker state |

## Fixed facts (decide in-text, cite; do not raise as open questions)

- Tier 0 node mapping is a menu: Course → Strand → Node (brief §4.2). Tier 1 maps free text to a node
  with confidence; below threshold → menu (I2).
- Probe = 2 short items, ~60 s [SOURCED: brief §2, §7]. Pass → "not the issue", return; fail → minimal
  remediation on that node. Both outcomes logged locally and, if consented, to telemetry.
- Backtrack ≤ 2 levels per session (D4); deeper gaps → SessionRecord + parent view only.
- Answers never withheld (D5): the answer and the diagnosis are shown together.
- No accounts (D19): all state is local to the browser profile (IndexedDB). No sync in MVP.
- Baseline env (D8): desktop, ≥16 GB RAM, ≥20 GB free, Chrome 148+/Edge, WebGPU. Others → unsupported page
  listing the queued items (§9).
- Starting chain (D14) is the content scope for M2–M5.
- Input is MathLive → LaTeX only (D9).

## Cross-domain seams the docs must name explicitly (they become C1 seam tests later)

verification↔tutoring-session (StepVerdict / FirstFailure), concept-graph↔tutoring-session (prerequisite
query), learning-objects↔tutoring-session (HintTree / ProbeItem lookup), runtime-tiers↔tutoring-session
(ClassificationResult + FallbackDecision), tutoring-session↔telemetry (event emission under consent),
tutoring-session↔parent-view (SessionRecord read), platform↔all (asset loading, store access),
content-generation↔{concept-graph, learning-objects} (bundle handoff + validation).
