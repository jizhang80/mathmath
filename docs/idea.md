# Idea — mathmath

> Phase 2 output, re-cut on 2026-09-09, web-first update 2026-10-06. This is the **consolidated structured extract** of
> [`PROJECT-BRIEF-v2.md`](../PROJECT-BRIEF-v2.md) as amended by `AMENDMENT-v2.1.md` … `AMENDMENT-v2.8.md`
> (v2.1–v2.7 dated 2026-09-09, v2.8 dated 2026-10-06; a later amendment wins on conflict). The brief and amendments are ground truth:
> **on any conflict, they win.** This file exists because the ground truth is now nine files; it records
> every decision *in force*, not the history of how it got there. Decisions D1–D50 are locked (D28 superseded by D45; D30, D37 unassigned); changing one is
> a Q5 owner decision. `PROJECT-BRIEF-v1.md` is superseded and kept for history only.

## One-line description

A math learning system, shipped as a single-user web app installable as a PWA (iPad/iPhone Safari first; native iOS frozen, D50), whose continent runs from foundational
through undergraduate engineering mathematics with Ontario grades 9–12 as the first content tier (D1, D43),
in which the cross-grade concept graph is a **map** the student explores along **their own trail** (D47) in ~3-minute **expeditions** of probe items, and
in which a blocked node triggers an in-map **diagnosis** that finds the deepest unmastered prerequisite,
confirms it with a ~60-second probe, remediates the minimum piece and returns.

## Who uses it

| Role | Surface | Primary use |
|---|---|---|
| **Student** (grades 9–12) | Web app / installed PWA (iPad and iPhone Safari first; desktop browsers supported) | Open the map on their trail; run expeditions (or a unit expedition); set the "we are here in class" marker from the course's unit list; tap nodes, regions and landmarks; take the diagnosis when a node is blocked |
| **Owner** | — | Product testing at Demo and M3; delivery verification (including physical-device verification in iPad/iPhone Safari, installed to the home screen) at every wrap-gate. **Not a content reviewer** (D10, D12, D13) |

There is **no parent role** (D38): the product is a single-user game for students. The Generation model (offline Claude API) are system actors, not users.

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
fog over unmastered nodes, the student's trail with course segments and dashed extensions, a greyed horizon,
landmarks. **Door B — Expeditions**: ~5 probe items from the trail's outer fringe plus review slots; clearing lifts fog.
**Door A — Diagnosis**: hypothesis → probe upstream → minimal remediation → return; triggered from an
expedition (D27) and, as a desktop-first surface of the same web app at M5, from a homework problem with CAS step verification.

**One map, one trail per student** (v2.6 §A, D44–D48). The trail is the unit of personalisation: generated
from the selected course syllabi, the course-progress marker the student sets from the course's unit list
("we are here in class"), and the student's mastery state. New-learning items are drawn only from the
trail's **outer fringe** — nodes whose prerequisites are cleared and which are not — within the current and
next unit; up to two review slots per expedition revisit cleared nodes on the spaced-repetition ladder.
The same model serves the sprinter (trail extends past the course end, dashed, by marker position), the
student staying half a step ahead (trail is the course) and the student carrying upstream debt (blocked
nodes reached through Door A) — without modes. Basis: Knowledge Space Theory — assess the knowledge state,
present the outer fringe [SOURCED: Doignon & Falmagne 1985; ALEKS].

## Reference applications

- **ALEKS / Knowledge Space Theory** (Doignon & Falmagne, 1985) — the theoretical basis; ALEKS has operated
  on it commercially since the late 1990s [SOURCED: aleks.com; Cosyn et al., J. Math. Psychology 2021]. Its
  public topic structure is an L1 agreement source.
- **Khan Academy**, **OpenStax**, **CK-12** — independently built prerequisite structures used as L1
  multi-source agreement inputs. An edge with ≥ 2 independent sources is accepted.
- **OpenStax (CC BY 4.0)** and **MIT OCW (CC BY-NC-SA)** — the designated authorities for undergraduate nodes
  (D2 as revised, D43) [SOURCED: openstax.org licensing].

## Scale expectation

- **Client:** a web app, installable as a PWA and usable offline after first load (D31). The concrete stack
  is chosen by the harness and locked in `docs/tech-stack.md` (D32 as revised); the owner verifies at
  requirement level only. A renderer-free `Core` package (no DOM or browser API) owns graph data, L0
  validation, layout, trail generation, scheduler, state transitions and merge (D33). No third-party game
  engine (D24). The native Swift code is frozen (D50).
- **No application server** (D36): static hosting of versioned content JSON with an offline snapshot;
  one anonymous, serverless, append-only telemetry write endpoint. Student state lives in browser storage
  with a persistent-storage request and file export/import; no cross-device sync (v2.8 §9).
- **Offline pipeline** in Python (D41), owner-run, calling the Claude API for generation and the `Core` CLI
  for L0 and layout (D42).
- **Platform baseline (D34, as amended by v2.8):** Doors B/C and Tier 0 diagnosis on current Safari for
  iOS/iPadOS 18+ and current desktop Chrome/Safari [ESTIMATE: floor confirmed at Phase 5]. Tier 1 is
  deferred. Door A homework mode is a desktop-first surface of the same web app at M5.
- **Distribution (D35, as amended by v2.8):** a URL on static hosting, installed via Add to Home Screen;
  Demo testers open a preview deployment URL; no app store. A privacy-policy page is required only when the
  URL is published beyond the testers (the first D19 trigger; a page, not an entity).

## Compliance constraints

- **D17 (as amended by v2.3/v2.5)** — telemetry is anonymous and aggregate, **on by default, one-tap off**,
  and carries **no identifier of any kind** (no install, device or session id). All cross-event continuity
  is computed on the device and sent as derived events (a single "day-N return" event; per-edge L3 events
  `{edge_id, upstream_state, downstream_result}` that the server only counts). "Not linked to the user" is a property
  of the data, not a declaration.
- **Endpoint constraint** — "no IP retention" is a Phase 5 hard constraint on the telemetry endpoint
  (request logging disabled or IP-stripped at ingress) and an L0-level acceptance item in `telemetry`.
- **D18** — Crown-copyright permission is *not* required: nodes store expectation codes plus the project's
  own paraphrase and link out to the official page for verbatim text.
- **D19** — no legal entity, domain, or compliance work until money is charged or identifiable data is
  collected; neither is in scope. The privacy-policy page at public publication is a page, not an entity.
- **§10 licensing position (unchanged from v1)** — Ontario curriculum documents are Crown copyright;
  non-commercial use of insubstantial excerpts with attribution is permitted, substantial reproduction
  requires King's Printer permission [SOURCED: publications.gov.on.ca General FAQs]. Codes, course names,
  strand names and structure are facts and not protected. No permission request is on the critical path.
- **D22** — landmarks are real, named, verifiable things with a source link; nothing fabricated.

## Explicit non-goals

Queued (brief §9 as amended; see `docs/DEFERRED.md`):

1. **Native apps** (iOS, Android) — native iOS frozen (D50); any app-store presence decided later (D31).
2. **Door A homework mode** (structured editor + CAS step verification) — desktop-first surface of the web
   app, built at M5 (D34).
3. **Tier 1** on-device model, the M4′ spike and M4 — deferred (v2.8 §8). Firefox is not a target (D34).
4. **Cross-device sync** of student state (v2.8 §9; introducing it is a Q5).
5. Handwriting / photo OCR (**D9**, I10 — no OCR in any door).
6. Tier 2 cloud inference (**D15**, re-rationalised by v2.1 A4: a possible attractor if in-product AI
   conversation proves part of the appeal; carries inference cost plus an API-key proxy server, D36).
7. Accounts, payments, any legal entity (D19); self-built leaderboards or rankings (D39).
8. **Parent view** — removed (D38; D16 void).
9. Other subjects (D25); real-time or animated game mechanics (D24 keeps the door open, nothing is built).
10. Grade 7–8 content: an optional "shore" region may be drawn without content (D21 revised; not in the Demo,
   decided at M5). Ideas layer (v2.6 §C) and additional syllabi as trails (D49) — see `docs/DEFERRED.md`.

## Decisions in force

| ID | Decision (as amended) | Source |
|---|---|---|
| D1 | Scope: the map covers foundational through undergraduate engineering mathematics; content build order is strict — D14 chain → remaining grade 9–12 strands → undergraduate. "Ontario grades 9–12" is the first content tier, not the product boundary. | v2, v2.7 §1 |
| D2 | Authority by tier: Ontario Ministry curriculum documents for grade 9–12 nodes (`expectation_codes`); a designated CC-licensed source (OpenStax CC BY 4.0, MIT OCW CC BY-NC-SA) for undergraduate nodes (`source_ref`). A node carries at least one; neither fails L0. | v2, v2.7 §1 |
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
| D21 | Regions (revised): Number & Operations · Algebra · Functions · Geometry & Measurement · Trigonometry · Calculus (single- and multivariable, depth by node) · Linear Algebra · Differential Equations · Probability & Statistics · Discrete Mathematics. Horizon (names only): Analysis, Topology, Number Theory, Abstract Algebra. Optional "shore" for grade 7–8 fractions/integers/ratio: drawn, no content, no fog (not in the Demo). | v2, v2.6 |
| D22 | Landmarks are real, named, verifiable things with a source link, linked to ≥ 1 node, often across regions. | v2 |
| D23 | Expedition = existing probe mechanism (≈ 5 items, ≈ 3 minutes) + spaced repetition over the graph; no separate game content. | v2 |
| D24 | No third-party game engine; rendering technology chosen at Phase 5, escalated only on measured performance. Data, layout and state strictly separated from rendering. | v2, v2.2, v2.8 §11 |
| D25 | Math only; cross-subject reuse is a demand signal, not a design input. | v2 |
| D26 | A form-testing Demo runs first, on hand-written data, decoupled from M1/M2. | v2 |
| D27 | Expedition error tolerance: one retry item on the same node; second miss → Door A event; at most one Door A event per expedition; later misses mark the node and continue. | v2.1 |
| D28 | **Superseded by D45** (mechanics unchanged, semantics replaced). | v2.1, v2.6 |
| D29 | Agent gate = all tests pass in CI, including end-to-end tests under the WebKit and Chromium engines; physical-device verification (iPad/iPhone Safari, installed to the home screen) is the owner's, at the wrap-gate; no agent claims it. | v2.1, v2.4 §6, v2.8 §10 |
| D30 | *Unassigned. Do not reuse.* | v2.5 §5 |
| D31 | Web first: the student-side product is a web app installable as a PWA; primary targets iPad and iPhone Safari, desktop Chrome/Safari supported; native app-store presence decided later. | v2.2, v2.8 §1 |
| D32 | Stack delegated to the harness: chosen at Phase 5 against `claude-tech-stack-preferences.md` and locked in `docs/tech-stack.md` with a rationale per choice; owner verifies at requirement level only; a post-lock tool change is recorded there, not a Q5. Constraints: one strictly typed language for `Core` and UI; boundary validation from `contracts/schemas/`; no third-party game engine; no runtime server beyond D36; offline after first load; a WebKit test path. | v2.2, v2.4 §1, v2.8 §3 |
| D33 | A renderer-free `Core` package in the web stack's language (no DOM or browser API; a test asserts the boundary) holds graph types, L0 validation, region-constrained layout, trail generation, scheduler, state transitions and merge. Layout is precomputed by a build step and read at runtime; L0 runs in the same step and failing data is not emitted. | v2.2, v2.4 §7, v2.8 §4 |
| D34 | Platform baseline: Doors B/C + Tier 0 diagnosis on current Safari for iOS/iPadOS 18+ and current desktop Chrome/Safari [ESTIMATE: floor confirmed at Phase 5]; Tier 1 deferred; homework mode a desktop-first surface of the same web app at M5. | v2.2, v2.4 §5, v2.8 §6 |
| D35 | Distribution: a URL on static hosting, installed via Add to Home Screen; Demo testers use a preview deployment URL; no app store; privacy-policy page only when the URL is published beyond the testers. | v2.2, v2.4 §4, v2.8 §7 |
| D36 | No application server: static content hosting + one anonymous serverless append-only telemetry endpoint with no IP retention; student state in browser storage (persistent-storage request, file export/import); no cross-device sync (introducing it is a Q5); a server only for Tier 2 or accounts (both queued). | v2.3, v2.4 §1, v2.8 §9 |
| D37 | *Unassigned. Do not reuse.* | v2.5 §5 |
| D38 | No parent view; single-user game for students. | v2.3 |
| D39 | Leaderboards / achievements not built; if ever built, the mechanism is decided then, with no self-built accounts or ranking service. | v2.3, v2.8 §11 |
| D40 | Telemetry doubles as product-behaviour observation: session start/end; expedition started/completed; per-item node and result (L3); marker placement and moves; landmark taps; day-N return. | v2.3 |
| D41 | The offline content pipeline is Python; output is the shared JSON consumed by `Core`. | v2.4 §3 |
| D42 | Single-implementation principle: anything pipeline and app must agree on lives once in the web `Core` and is exposed via its command-line entry point (currently L0 validation and layout); Python invokes, never reimplements. Until the web `Core`'s L0 and layout land, the pipeline may keep calling the Swift `core-cli`; the switch is recorded. | v2.5 §4, v2.8 §5 |
| D43 | Map scope: foundational through undergraduate engineering mathematics, drawn at full size from the Demo on; content order strict (D14 chain → grade 9–12 strands → undergraduate); undergraduate sources CC-licensed. | v2.6 |
| D44 | Trail first: default view and expedition scheduling are anchored on the student's trail; the continent is background, reachable by zooming out. | v2.6 |
| D45 | Course-progress marker (replaces D28's semantics): the student marks "we are here" from the course's unit list; units map to expectation codes; the scheduler draws from the current and next unit's nodes on the trail's fringe; nodes upstream of the marker are excluded and reached only through Door A. Unit source: one designated textbook per course (`unit_source`, chosen at M1) orders expectations by chapter (the L1 `textbook_order` source); fallback is grouping by strand in Ministry order. Demo unit lists are hand-written. | v2.6, v2.7 §2 |
| D46 | Unit expeditions: the student may restrict an expedition to one unit (pre-test review). Scheduler parameter only. | v2.6 |
| D47 | The trail is the unit of personalisation: a per-student object generated from the selected syllabi, the marker (D45) and mastery state; may extend beyond the course end. Extension rule: when the marker passes the last unit, the trail extends from the course's terminal nodes along downstream edges, preferring the next course in the same stream per the Ministry prerequisite chart (spine data `next_courses[]`, never logic) [SOURCED: Ontario 2007 curriculum prerequisite chart], then undergraduate trails when their nodes exist; opt-in by marker position, drawn dashed. No per-archetype modes. | v2.6, v2.7 §4 |
| D48 | Fringe rule: a **new-learning** item is eligible only if its node is on the trail's outer fringe (prerequisites cleared, node not cleared). An expedition = fringe slots (within current + next unit) + up to 2 due-review slots from the spaced-repetition ladder (expedition Q2/Q3). Policy = D48 + D27 + Door A + review slots. | v2.6, v2.7 §3 |
| D49 | Additional syllabi as trails (queued): AP Calculus AB/BC, AP Statistics, IB Mathematics AA/AI, first-year undergraduate — added when their nodes exist; a trail is a node-id list. | v2.6 |
| D50 | Native iOS frozen: the Swift code (`Packages/`, `App/`) and EPIC 01–04 records stay unchanged; no agent edits them; their CI job runs only on changes under those paths. Web work derives from the brief, `contracts/` and `docs/domains/`; Swift `core-cli` outputs over `data/demo/` may serve as a test oracle, and the contract wins on disagreement. | v2.8 §2 |

## Milestones (ordered; no time estimates)

| Milestone | Content |
|---|---|
| M0 — Baseline | ✅ |
| **Demo** — Map form test | D26; **web**, re-run per `DEMO-BRIEF.md` as amended by v2.1 §D (surviving parts), v2.2 §B (surviving parts) and v2.8 §12: hand-written JSON, two trails (MTH1W, MCR3U) with hand-written unit lists and the "we are here in class" marker (D45), ten region outlines + horizon per revised D21 (nodes only in Number, Algebra, Functions), camera on the tester's trail (D44), fringe selection within current + next unit (D48), tolerance (D27), one sourced landmark, a math-rendering check over every bundle string as the first task; verification on iPad/iPhone Safari from the URL, installed and offline; acceptance item 7: did the tester move the class marker and did the first expedition feel related to class (v2.6 §D). Serves as the Phase 4 UI/UX artifact for Doors B and C. Runs first. |
| M1 — Spine + data model | Unchanged; add Region / Trail / Landmark schemas and the two new L0 rules. L0 and layout through the `Core` CLI (D42). |
| M2 — Concept graph, starting chain v0 | Unchanged; assign regions and confirm D21 against the real graph. |
| M3 — Web Tier 0 end-to-end | Content hosting with offline snapshot and refresh; L3 telemetry in; one expedition with a Door A diagnosis event on real M2 data; map render from M2 data replaces demo data. No cross-device sync. |
| M4′, M4 — Tier 1 | **Deferred** (v2.8 §8); re-entry when an on-device model API exists in target Safari or a native wrapper is decided. |
| M5 — Coverage expansion | Remaining grade 9–12 strands/courses, then the undergraduate tier (D43 order); landmarks across all regions; shore-region decision; **Door A homework mode built into the same web app** (desktop-first). |
| Release | Public URL after M5; native app-store presence decided later (D31, D50). |

## Residual unknowns (experiments, not decisions)

- Does the map form make a student click in and come back? — Demo.
- Whether D21's eight regions survive contact with the real graph — M2.
- What a landmark needs to contain to make a node feel concrete — Demo (one landmark), refined at M5.
- Whether Safari evicts browser storage for an installed vs. a non-installed app in practice — measured at the Demo (v2.8 §9).
- Whether in-product AI conversation is part of the appeal (Tier 2 rationale) — Demo observations.
- Proof-based territory (Discrete, parts of Analysis): numeric/MC probes do not fit; the expedition form there
  is undecided. Does not block; content order reaches it last (v2.6 §E).
- Framing by motivation (sprint / stay ahead / recover): the same expedition may need different packaging;
  decided from telemetry (D40), not designed now (v2.6 §E).

## Change log

| Date | Change |
|---|---|
| 2026-09-08 | Initial extract from `PROJECT-BRIEF-v1.md` (owner-ratified same day). |
| 2026-09-09 | Re-cut as the consolidated extract of `PROJECT-BRIEF-v2.md` + `AMENDMENT-v2.1`–`v2.5`: three doors, native iOS, no parent view, telemetry without identifiers, decisions D1–D42 in force. |
| 2026-09-09 | v2.6/v2.7 applied: one map, one trail per student (D43–D49); D1, D2, D21 revised; D28 superseded by D45; I8 amended; residual unknowns added. |
| 2026-10-06 | v2.8 applied: web first (D31), native frozen (D50 new), stack delegated to the harness (D32), `Core` and D42 move to the web stack, Tier 1 / M4′ / M4 deferred, local state only, D24/D29/D33–D36/D39 revised; Demo re-runs on the web. |
