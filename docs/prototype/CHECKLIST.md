# Phase 4c — completeness checklist and review

> **2026-09-09:** this checklist is **closed without the owner Do/Act steps** — the v2 pivot
> (`AMENDMENT-v2.2.md` §D) makes the native Demo the Phase 4 artifact for student surfaces and removes the
> parent view (D38). Rows for `tutoring-session` W1–W3, W7 and `verification` remain reference for the M5
> homework mode; every other row is superseded by `docs/domains/map.md`, `expedition.md`, `diagnosis.md`,
> `platform.md`, `telemetry.md`, `runtime-tiers.md`.

Status (2026-09-08): **Check done by Claude; Do (owner click-through) and Act pending.** Playbook:
for every workflow in every domain doc, is there a clickable entry point and a clear termination? Loop
until every row is resolved or explicitly written to `docs/DEFERRED.md`.

Instrument (C3): the table below was built by reading each `docs/domains/*.md` `## Workflows` section and
mapping every `W<n>` to a page and a variant; `index.html` links were checked mechanically (25 pages,
0 broken links; empty = PASS). What this instrument cannot see: whether a screen *feels* like a teacher
(brief §7 acceptance) — that is the owner's Do step.

## 1. Workflow → entry point → termination

| Domain | Workflow | Entry point (page#variant) | Terminates at | ✓ |
|---|---|---|---|---|
| tutoring-session | W1 enter + map | `student-session#tier0` / `#tier1` / `#tier1low` / `#resume` | "Check my steps" → W2; or "Just show me the answer" → W7 | ✓ |
| | W2 verify + locate | `student-session-steps#firstfail` | "What went wrong" → W3; `#allok` → W7 | ✓ |
| | W3 classify | `student-session-classify#tier0` / `#tier1` / `#tier1low` / `#tier1none` | Continue → W4; "none of these" → W4 generic | ✓ |
| | W4 hint | `student-session-hint#tier1hint` … `#tier3hint`, `#generic`, `#reworded`, `#notfound` | tree is finite ("last hint"); fix step → W2; answer → W7 | ✓ |
| | W5 hypothesis + probe | `student-session-hint#tier1hint` card → `student-session-probe#items` | `#pass` refuted → W4; `#fail` confirmed → W6; `#declined` unconfirmed → W4; `#unavailable` → W4 | ✓ |
| | W6 remediate + return | `student-session-remediation#explanation` / `#worked` / `#level2` | "Back to my problem at step 2" → W2 | ✓ |
| | W7 close + persist | `student-session-answer#answered` / `#resolved` / `#nosteps` / `#answeronly` / `#noanswer` / `#writefailed` / `#abandoned` | "Start another problem" → W1; History | ✓ (G1, G2, G9) |
| | W8 backtrack cap | `student-session-hint#capped` | resumes W4; recorded → parent `#deeper` | ✓ |
| verification | W1 warm up CAS | `student-session#casloading` / `#casdown` (status strip) | ready, or VERIFY_CAS_UNAVAILABLE with reload | ✓ |
| | W2 verify sequence | `student-session-steps` (all variants) | trace shown; parse failure stops scan (`#unread`); timeout (`#timeout`) | ✓ (G4) |
| | W3 solve | `student-session-answer` | answer, or `#noanswer` (unsupported / CAS down) | ✓ (G2, G5) |
| runtime-tiers | W1 detect capability | `settings-models#nano` / `#nanodownloadable` / `#nowebgpu` | capability shown; Tier 0 silently otherwise | ✓ |
| | W2 classify (Tier 1) | `student-session-classify#tier1` | student confirms, or `#tier1low` fallback | ✓ |
| | W3 map free text | `student-session#tier1` | pre-selection, or `#tier1low` menu stands | ✓ |
| | W4 adapt wording | `student-session-hint#reworded` | original on rejection (off in MVP, tier-Q4) | ✓ |
| | W5 fallback decision | every `#tier1low` variant; silent | Tier 0 behaviour; logged | ✓ |
| | W6 fallback download | `settings-models#fallbackoffer` → `#downloading` → `#nano`; `#insufficient` | finished, cancelled, or insufficient | ✓ |
| | W7 M4′ spike (offline) | `owner-spike-report#go` / `#nogo` | go/no-go verdict, thresholds fixed | ✓ |
| parent-view | W1 open | `parent` / `#empty` / `#unreadable` / `#storedown` | summary or empty state | ✓ (G10) |
| | W2 by course/strand | `parent` | one sentence per strand | ✓ |
| | W3 gap detail | `parent-gap` / `#deeper` / `#notingraph` | suggested action; back | ✓ (G11, G12) |
| | W4 trend | `parent-trend` / `#toofew` | prose, or "not enough sessions yet" | ✓ |
| | W5 clear history | `parent` → dialog → `#cleared` | empty state + confirmation banner | ✓ |
| platform | W1 first load | `unsupported#nowebgpu` / `#nostorage` / `#mobile`; `settings-storage` env table | unsupported page, or proceed with warnings | ✓ |
| | W2 asset update | `settings-storage#updateready` / `#fetchfail` / `#integrity` | applied at next launch, or previous manifest stays | ✓ (G16) |
| | W3 Pyodide load | status strip; `settings-storage#runtimefail` | cached, or retry | ✓ |
| | W4 store migration | `settings-storage` (proto-note only; unreadable records surface at `parent#unreadable`) | migrated, or old data kept readable | ✓ |
| | W5 offline | `settings-storage#offline`; `settings-data#offline` | full Tier 0 flow; telemetry buffered | ✓ |
| telemetry | W1 consent | `settings-data#off` → `#on` | state persisted; never modal | ✓ (G15) |
| | W2 capture | invisible by design; buffered count on `settings-data#on` | one buffered event | ✓ |
| | W3 send batch | `settings-data#on` / `#sendfail` / `#offline` | sent, or kept buffered to a cap | ✓ |
| | W4 aggregation (offline) | `owner-telemetry-report` / `#sparse` | hand-off to concept-graph, or nothing | ✓ |
| concept-graph | W1 L0 checker (offline) | `owner-graph-report#pass` / `#fail` / `#spinemismatch` | accepted / refused | ✓ |
| | W2 L1 tagging (offline) | `owner-graph-report#pass` | bundle published; disputed list | ✓ |
| | W3 prerequisite query | `student-session-hint` card / `#noprereq` / `#capped` | one candidate, or none within reach | ✓ (G19) |
| | W4 confidence update | `student-session-probe#pass` / `#fail` (logged); `owner-telemetry-report` | persisted | ✓ |
| learning-objects | W1 validate bundle (offline) | `owner-lo-report#pass` / `#fail` | accepted / refused whole | ✓ |
| | W2 serve hint | `student-session-hint`; `#notfound` | tier index recorded | ✓ |
| | W3 draw probe | `student-session-probe#items`; `#unavailable` | two items, or skip | ✓ |
| curriculum-spine | W1 extract (offline) | `owner-spine-report#extract` / `#fail` | course extracted / stopped | ✓ |
| | W2 cut bundle (offline) | `owner-spine-report#cut` / `#reversion` | bundle frozen / build failed | ✓ |
| | (runtime menu) | `student-browse`, `student-node`, `#linkoff` | topic chosen → W1 session | ✓ |
| content-generation | W1 batch (offline) | `owner-generation-report#edges` / `#objects` / `#budget` | runs persisted / halted at ceiling | ✓ |
| | W2 intersect (offline) | `owner-generation-report#edges` | IntersectionResult handed to graph | ✓ |
| | W3 synthetic set (offline) | `owner-spike-report` (input section) | set handed to runtime-tiers | ✓ |

Every user-visible error code in the ten docs appears at least once as a banner/row with its code
(mechanical grep across `*.html` for every backticked `UPPER_SNAKE` code in the ten docs: 40 of 40
present — 38 as user-visible states, `VERIFY_DOMAIN_UNDECIDABLE` and `SESSION_NODE_UNMAPPED` as
proto-note/banner on the steps and entry pages; a missing code = FAIL).

## 2. Route proposals (differ from the placeholders in the domain docs — owner ratifies)

| # | Proposal | Doc(s) to amend on Act |
|---|---|---|
| R1 | `/settings/models` replaces `/student/settings/models`; all three settings pages sit under `/settings` with one sub-nav | runtime-tiers |
| R2 | `/parent/graph` folds into `/parent`; `/parent/node/:nodeId` folds into `/parent/gap/:nodeId` | concept-graph, curriculum-spine |
| R3 | Remediation gets its own route `/student/session/remediation` (W6 has none) | tutoring-session |
| R4 | `/student/session` carries entry, trace and classify as states of one route, not three routes | tutoring-session (no change; confirmation) |
| R5 | Owner reports are local files/CLIs, not routes; `/owner/graph-report` in concept-graph becomes "L0 report file" | concept-graph |

## 3. Gaps found while building (owner call on each; proposed default in italics)

| # | Gap | Domain | Proposed default |
|---|---|---|---|
| G1 | Answer requested with zero steps — no outcome or diagnosis defined | tutoring-session W7 | *outcome `answered`; diagnosis text "nothing checked"; node recorded, no error type* |
| G2 | CAS unavailable ⇒ the answer cannot be produced either (W3 runs in the same worker); I3 wording | verification W3, tutoring-session | *honest terminal state "no answer right now" with reload; I3 reads "never withheld by policy", not "always computable"* |
| G3 | Every step follows but the last step is not the answer — no state | tutoring-session W2/W7 | *"Every step so far follows. Keep going, or see the answer."; outcome stays open* |
| G4 | Is a `VERIFY_TIMEOUT` step a FirstFailure? Error table says the rest of the trace stands; W2 step 4 says first non-`equivalent` | verification W2 | *not a failure; no classification; "check again"* |
| G5 | `VERIFY_UNSUPPORTED` raised by the solver ⇒ answer-only mode with no answer | verification W3 | *same terminal state as G2 with different wording* |
| G6 | May the student skip remediation after a confirmed probe? | tutoring-session W6 | *yes; the node still records `probed-fail`* |
| G7 | Parent view has no representation for an `unconfirmed` (declined) hypothesis | parent-view | *not shown, by design* |
| G8 | "Exactly one Remediation piece" vs. letting the student swap Explanation ↔ WorkedExample | tutoring-session W6 | *one swap allowed; counts as one remediation* |
| G9 | Abandoned attempt: when/where is the answer "shown at close"? | tutoring-session W7 | *from History only; nothing pops up* |
| G10 | The origin node (where the error happened) has no `NodeStatus`, so the course actually being worked on can render no line | parent-view | *add a sixth state `worked-on` (attempted, not probed) to `NodeStatus`* |
| G11 | Is a `remediated` node a closed gap, or open until a later probe passes? Trend's "gaps closed" depends on it | parent-view | *closed on remediation; re-opened by a later `probed-fail`* |
| G12 | Confidence wording threshold and phrases; multi-hop downstream wording | parent-view W3 | *≥ 0.7 "is needed for", else "may affect"; multi-hop uses the weakest edge on the path* |
| G15 | Consent surface needs a buffered-event count and last-batch state; telemetry names neither | telemetry W1 | *add both to the surface spec (read-only)* |
| G16 | `PLATFORM_ASSET_FETCH_FAILED` has no stated retry affordance | platform W2 | *"Check again" button; next launch also retries* |
| G17 | Actor table lets the student turn Tier 1 off, but no workflow owns the switch | runtime-tiers | *add W8 "toggle Tier 1"; persisted with `TierCapability`* |
| G19 | Node page "what this builds on": direct accepted prerequisites only, or the 2-level walk? | concept-graph UI | *direct accepted edges only* |
| G20 | Runtime error codes (`GRAPH_NO_PREREQUISITE`, `LO_HINT_NOT_FOUND`, `LO_PROBE_POOL_EMPTY`, `TIER_*`, device-side `TELEM_*`) have no owner-visible surface | cross-domain | *local log only; no report — confirm* |
| G21 | graph-Q1 weights per source tag and the "disputed floor" are not numeric anywhere | concept-graph | *forward to Phase 6 as contract parameters, not a Phase 4 item* |

(G13, G14, G18 from agent reports were prototype-side slips or duplicates and were fixed in place;
numbering is kept stable so the agents' notes still resolve.)

## 4. Fixed during Check

- Design system: `.dialog-backdrop[hidden]` was overridden by `display:flex`; fixed in `components.css`.
- Parent pages and history drifted from the shared mock (laws of logarithms shown as probed-fail; wrong
  nodes on 09-05/09-07); realigned to the one mock world.

## 5. Do — owner walk-through script (Plan step)

1. Open `index.html` → Walk-through A, in order. Judge against brief §7: *teacher not chatbot; probe feels
   like confirmation; a wrong hypothesis costs a minute and no trust.*
2. On each page press every variant button once. Anything that should exist and does not: add a row to §3.
3. Then the parent's three pages, then the three settings pages, then `unsupported`.
4. Owner reports: read the verdict line of each; confirm the six reports are the review surface you want
   for the offline pipeline (the alternative is plain text files).
5. Ratify or amend `docs/design-system/README.md` (4a) and §2 routes; decide each §3 gap or move it to
   `docs/DEFERRED.md` with the C6 template.

## 6. Act — pending owner decisions

Domain docs are amended only after the owner's Do/Act pass; the "confirmed in Phase 4" placeholders in
each doc's `## UI surfaces` are then replaced with the ratified routes, and each accepted gap default is
written into its workflow.
