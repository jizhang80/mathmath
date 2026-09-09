# Idea — mathmath

> Phase 2 output, re-cut on 2026-09-09. This is the **consolidated structured extract** of
> [`PROJECT-BRIEF-v2.md`](../PROJECT-BRIEF-v2.md) as amended by `AMENDMENT-v2.1.md` … `AMENDMENT-v2.5.md`
> (all dated 2026-09-09; a later amendment wins on conflict). The brief and amendments are ground truth:
> **on any conflict, they win.** This file exists because the ground truth is now six files; it records
> every decision *in force*, not the history of how it got there. Decisions D1–D42 are locked; changing one is
> a Q5 owner decision. `PROJECT-BRIEF-v1.md` is superseded and kept for history only.

## One-line description

An Ontario grade 9–12 math learning system, shipped as a single-user native iOS/iPadOS app, in which the
cross-grade concept graph is a **map** the student explores in ~3-minute **expeditions** of probe items, and
in which a blocked node triggers an in-map **diagnosis** that finds the deepest unmastered prerequisite,
confirms it with a ~60-second probe, remediates the minimum piece and returns.

## Who uses it

| Role | Surface | Primary use |
|---|---|---|
| **Student** (grades 9–12) | Native iOS/iPadOS app (iPhone-first) | Open the map; run expeditions; place the start marker on their course trail; tap nodes, regions and landmarks; take the diagnosis when a node is blocked |
| **Owner** | — | Product testing at Demo and M3; delivery verification (including physical-device verification) at every wrap-gate. **Not a content reviewer** (D10, D12, D13) |

There is **no parent role** (D38): the product is a single-user game for students. The Local model (Tier 1,
on-device Foundation Models) and the Generation model (offline Claude API) are system actors, not users.

## Core problem it solves

Two problems, one base. (1) "Falling behind in math" — the differentiator over generic AI chat is that the
system **knows which concept node a student is weak on, why, and which downstream territory that node
feeds**; the method is just-in-time remediation with a ≤ 2-level backtrack. (2) v2's addition: the product
must **create the wanting in small doses rather than presuppose it** — target-age testers reported that a
"bring your homework" entry does not attract struggling students, while a fragmented-time, level-by-level
form might. So the front door is the map and the expedition; diagnosis is an event inside them.

**One base, three doors.** Base: cross-grade concept graph with prerequisite edges; deterministic item
checking; per-node error catalogues; tiered hint trees; 60-second probes that both confirm a diagnosis and
validate the graph; pre-generated content. **Door C — Map**: regions by math's taxonomy, edges as rivers,
fog over unmastered nodes, courses as trails, a greyed horizon beyond grade 12, landmarks. **Door B —
Expeditions**: ~5 probe items from the fog frontier, spaced repetition over the graph; clearing lifts fog.
**Door A — Diagnosis**: hypothesis → probe upstream → minimal remediation → return; triggered from an
expedition (D27) and, as a desktop web feature at M5, from a homework problem with CAS step verification.

## Reference applications

- **ALEKS / Knowledge Space Theory** (Doignon & Falmagne, 1985) — the theoretical basis; ALEKS has operated
  on it commercially since the late 1990s [SOURCED: aleks.com; Cosyn et al., J. Math. Psychology 2021]. Its
  public topic structure is an L1 agreement source.
- **Khan Academy**, **OpenStax**, **CK-12** — independently built prerequisite structures used as L1
  multi-source agreement inputs. An edge with ≥ 2 independent sources is accepted.

## Scale expectation

- **Client:** native Swift 6 / SwiftUI app; map on SwiftUI `Canvas` (first-party SpriteKit permitted only
  if a few hundred nodes demand it); SwiftMath for math display with a WKWebView + KaTeX fallback for
  notation it cannot render; Tier 1 via the Foundation Models framework with `@Generable` guided
  generation. A Swift Package `Core` (Foundation only) owns graph data, L0 validation, layout, scheduler
  and state transitions; Android's `core` will be a port sharing the JSON data formats (D32, D33).
- **No application server** (D36): static hosting of versioned content JSON with an offline snapshot
  bundled in the app; one anonymous, serverless, append-only telemetry write endpoint; cross-device sync of
  the student-state JSON via iCloud (iCloud Drive container or CloudKit — chosen at M3), active only when
  the device is signed in to iCloud, silent local fallback otherwise.
- **Offline pipeline** in Python (D41), owner-run, calling the Claude API for generation and the `Core` CLI
  for L0 and layout (D42).
- **Platform baseline (D34, as amended):** Doors B/C and Tier 0 diagnosis on iOS/iPadOS 18+; Tier 1 on
  iOS/iPadOS 26+ with Apple Intelligence-capable hardware (A17 Pro / M1 or later) and Apple Intelligence
  enabled [SOURCED: Apple Newsroom 2025-09; WWDC25 Session 286], availability checked at runtime; Door A
  homework mode is desktop web at M5; Android after iOS.
- **Distribution (D35, as amended):** Apple Developer Program membership exists. Demo builds are installed
  directly from Xcode with development signing on the two testers' registered devices; TestFlight is the
  path for any later external testing. A privacy-policy page is required only at external TestFlight / App
  Store publication (the first D19 trigger; a page, not an entity).

## Compliance constraints

- **D17 (as amended by v2.3/v2.5)** — telemetry is anonymous and aggregate, **on by default, one-tap off**,
  and carries **no identifier of any kind** (no install, device or session id). All cross-event continuity
  is computed on the device and sent as derived events (a single "day-N return" event; per-edge L3 events
  `{edge_id, upstream_state, downstream_result}` that the server only counts). App Store privacy label:
  "Data Not Linked to You", as a property of the data.
- **Endpoint constraint** — "no IP retention" is a Phase 5 hard constraint on the telemetry endpoint
  (request logging disabled or IP-stripped at ingress) and an L0-level acceptance item in `telemetry`.
- **D18** — Crown-copyright permission is *not* required: nodes store expectation codes plus the project's
  own paraphrase and link out to the official page for verbatim text.
- **D19** — no legal entity, domain, or compliance work until money is charged or identifiable data is
  collected; neither is in scope. The privacy-policy page at external publication is a page, not an entity.
- **§10 licensing position (unchanged from v1)** — Ontario curriculum documents are Crown copyright;
  non-commercial use of insubstantial excerpts with attribution is permitted, substantial reproduction
  requires King's Printer permission [SOURCED: publications.gov.on.ca General FAQs]. Codes, course names,
  strand names and structure are facts and not protected. No permission request is on the critical path.
- **D22** — landmarks are real, named, verifiable things with a source link; nothing fabricated.

## Explicit non-goals

Queued (brief §9 as amended; see `docs/DEFERRED.md`):

1. **Android** — second codebase, after iOS ships (D31).
2. **Door A homework mode** (structured editor + CAS step verification) — desktop web, built at M5 (D34).
3. **Firefox** (all doors); Chrome Prompt API is no longer on the critical path.
4. Handwriting / photo OCR (**D9**, I10 — no OCR in any door).
5. Tier 2 cloud inference (**D15**, re-rationalised by v2.1 A4: a possible attractor if in-product AI
   conversation proves part of the appeal; carries inference cost plus an API-key proxy server, D36).
6. Accounts, payments, any legal entity (D19); self-built leaderboards or rankings — if ever built, Game
   Center (D39).
7. **Parent view** — removed (D38; D16 void).
8. Other subjects (D25); real-time or animated game mechanics (D24 keeps the door open, nothing is built).
9. Grade 8 and below (**D1**).

## Decisions in force

| ID | Decision (as amended) | Source |
|---|---|---|
| D1 | Scope: Ontario grades 9–12 only. | v2 |
| D2 | Sole authoritative content source: Ontario Ministry of Education curriculum documents. | v2 |
| D3 | One cross-grade concept graph; each course is a node subset + depth marker. | v2 |
| D4 | Just-in-time remediation, backtrack ≤ 2 levels per session, triggered as an in-map event; deeper gaps are marked `blocked` on the map only (the map is the record). | v2, v2.5 §3 |
| D5 | Answers are not blocked; diagnosis accompanies answers wherever an answer is shown. | v2 |
| D6 | Step correctness decided by CAS, never by a language model. | v2 |
| D7 | Three-tier runtime; Tier 0 alone is a usable product. | v2 |
| D8 | **Replaced by D34.** | v2.2 |
| D9 | Structured math editor input (homework mode); no OCR. | v2 |
| D10 | Graph verified by structure, source agreement, probe data — not human review. | v2 |
| D11 | Diagnoses are hypotheses confirmed by probes; probes double as validation data. | v2 |
| D12 | Content is batch-generated; owner defines structure and rules only. | v2 |
| D13 | Zero human pre-review; disputed edges ship at low confidence. | v2 |
| D14 | Starting chain: MTH1W linear relations/equations → exponent laws → polynomials/factoring → quadratics → function concept/transformations → exponential functions → logarithms & advanced functions. | v2 |
| D15 | Tier 2 queued; if Tier 1 fails, architecture is revisited, not patched. | v2 |
| D16 | **Void** (parent view removed). | v2.3 |
| D17 | Telemetry anonymous, aggregate, on by default, one-tap off, no identifiers of any kind, account-less. | v2.3, v2.5 §1 |
| D18 | No Crown-copyright permission needed: codes + own paraphrase, link out for verbatim text. | v2 |
| D19 | No legal entity, domain, or compliance work until money is charged or identifiable data is collected. | v2 |
| D20 | Map organised by math's natural taxonomy, not course codes; courses are an overlay (trails). | v2 |
| D21 | Regions (initial, refinable at M2): Number & Operations · Algebra · Functions · Geometry & Measurement · Trigonometry · Calculus · Probability & Statistics · Discrete. Horizon labels beyond grade 12 are names only. | v2 |
| D22 | Landmarks are real, named, verifiable things with a source link, linked to ≥ 1 node, often across regions. | v2 |
| D23 | Expedition = existing probe mechanism (≈ 5 items, ≈ 3 minutes) + spaced repetition over the graph; no separate game content. | v2 |
| D24 | No third-party game engine; first-party SpriteKit permitted if `Canvas` performance demands. Data, layout and state strictly separated from rendering. (Web stack wording superseded by D32.) | v2, v2.2 |
| D25 | Math only; cross-subject reuse is a demand signal, not a design input. | v2 |
| D26 | A form-testing Demo runs first, on hand-written data, decoupled from M1/M2. | v2 |
| D27 | Expedition error tolerance: one retry item on the same node; second miss → Door A event; at most one Door A event per expedition; later misses mark the node and continue. | v2.1 |
| D28 | Self-placed start marker per trail; default at the first node of the selected course trail; nodes upstream of the marker stay in fog, are excluded from the frontier and are entered only through Door A. | v2.1 |
| D29 | Agent gate = all tests pass under `xcodebuild` on the iOS simulator; physical-device verification is the owner's, at the wrap-gate; no agent claims it. | v2.1, v2.4 §6 |
| D30 | *Unassigned. Do not reuse.* | v2.5 §5 |
| D31 | Native iOS/iPadOS first, in Swift; Android is a second codebase after iOS ships. | v2.2 |
| D32 | Swift 6, SwiftUI; map on `Canvas` (SpriteKit permitted per D24); math display SwiftMath with WKWebView + KaTeX fallback; Tier 1 via Foundation Models `@Generable`; persistence = `Codable` structs in `Core` written as JSON to Application Support (SwiftData removed); no third-party dependency beyond SwiftMath without a recorded reason. | v2.2, v2.4 §1 |
| D33 | Swift Package `Core` (Foundation only) holds graph data, L0 validation, region-constrained force layout, scheduler, state transitions; a test asserts the import boundary; Android's `core` is a port sharing the JSON formats. Layout is precomputed by a build step and read at runtime; L0 runs in the same step and failing data is not emitted. | v2.2, v2.4 §7 |
| D34 | Platform baseline: Doors B/C + Tier 0 diagnosis on iOS/iPadOS 18+; Tier 1 on iOS/iPadOS 26+ with Apple Intelligence-capable hardware; homework mode desktop web at M5; Android after iOS. | v2.2, v2.4 §5 |
| D35 | Demo distribution: direct Xcode install with development signing on registered tester devices; TestFlight for later external testing; privacy-policy page only at external publication. | v2.2, v2.4 §4 |
| D36 | No application server: static content hosting + one anonymous serverless append-only telemetry endpoint; iCloud (Apple-managed identity) for cross-device state sync, only when signed in; a server only for Tier 2 or accounts (both queued). | v2.3, v2.4 §1 |
| D37 | *Unassigned. Do not reuse.* | v2.5 §5 |
| D38 | No parent view; single-user game for students. | v2.3 |
| D39 | Leaderboards / achievements, if ever built, use Game Center; not built now. | v2.3 |
| D40 | Telemetry doubles as product-behaviour observation: session start/end; expedition started/completed; per-item node and result (L3); marker placement and moves; landmark taps; day-N return. | v2.3 |
| D41 | The offline content pipeline is Python; output is the shared JSON consumed by `Core`. | v2.4 §3 |
| D42 | Single-implementation principle: anything pipeline and app must agree on lives once in `Core` and is exposed via its CLI target (currently L0 validation and layout); Python invokes, never reimplements. | v2.5 §4 |

## Milestones (ordered; no time estimates)

| Milestone | Content |
|---|---|
| M0 — Baseline | ✅ |
| **Demo** — Map form test | D26; native iOS per `DEMO-BRIEF.md` as amended by v2.1 §D (surviving parts) and v2.2 §B: hand-written JSON, two trails (MTH1W, MCR3U), start marker (D28), tolerance (D27), one sourced landmark, a SwiftMath rendering spike as the first task. Serves as the Phase 4 UI/UX artifact for Doors B and C. Runs first. |
| M4′ — Tier 1 spike | Foundation Models with a `@Generable` enum on an eligible device (or this Mac); same node, six-way error enum, synthetic round-trip data, top-1 ≥ 80 % go line [ESTIMATE: owner-set]. If no eligible device is available, raise Q5, do not work around. Parallel with M1. |
| M1 — Spine + data model | Unchanged; add Region / Trail / Landmark schemas and the two new L0 rules. |
| M2 — Concept graph, starting chain v0 | Unchanged; assign regions and confirm D21 against the real graph. |
| M3 — Native Tier 0 end-to-end | One expedition with a Door A diagnosis event on real M2 data; map render from M2 data replaces demo data; L3 telemetry in. Homework/CAS flow removed from M3. |
| M4 — Tier 1 integration | Foundation Models, availability-gated, Tier 0 fallback (if M4′ passed). |
| M5 — Coverage expansion | Remaining strands/courses; landmarks across all regions; **Door A homework mode as a desktop web app** (Pyodide + SymPy, MathLive); Android port planned. |
| Release | iOS after M5; Android after its port. |

## Residual unknowns (experiments, not decisions)

- Does the map form make a student click in and come back? — Demo.
- Foundation Models enum-classification accuracy on the six-way enum — M4′.
- Whether D21's eight regions survive contact with the real graph — M2.
- What a landmark needs to contain to make a node feel concrete — Demo (one landmark), refined at M5.
- Which iCloud mechanism (Drive container vs CloudKit) for the state file — M3.
- Whether in-product AI conversation is part of the appeal (Tier 2 rationale) — Demo observations.

## Change log

| Date | Change |
|---|---|
| 2026-09-08 | Initial extract from `PROJECT-BRIEF-v1.md` (owner-ratified same day). |
| 2026-09-09 | Re-cut as the consolidated extract of `PROJECT-BRIEF-v2.md` + `AMENDMENT-v2.1`–`v2.5`: three doors, native iOS, no parent view, telemetry without identifiers, decisions D1–D42 in force. |
