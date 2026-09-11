# Demo acceptance record (blank template)

This is the blank template for the EPIC 04 (Demo) acceptance record. It implements
`docs/epics/epic-04-app-expedition-diagnosis-acceptance.md` § 4 item 10, per the arbiter-04 § Q-C ruling on the
touch-completability split.

This file ships no code — it is layer ④ interaction's Demo acceptance record, not a `Core`/App/pipeline
artifact. Task 04.13 (the EPIC 04b wrap) fills only the *simulator — agent* result cells below, with the
gate/test outcome. The *device — owner* result cells stay blank in this task's output and remain blank until
the owner records the physical-device verification at the wrap-gate.

## Acceptance (DEMO-BRIEF §7, as amended through v2.6)

Owner runs the demo with the two target-age testers. Record, per tester:

1. Did they click into the map before being told to?
   - Tester A: —
   - Tester B: —
2. Did they finish one expedition? Did they start a second unprompted?
   - Tester A: —
   - Tester B: —
3. Afterwards, can they say in their own words what a trail is?
   - Tester A: —
   - Tester B: —
4. Did the landmark make any node feel concrete (ask them to name which)?
   - Tester A: —
   - Tester B: —
5. When the diagnosis card appeared, did it read as help or as accusation?
   - Tester A: —
   - Tester B: —
6. Where did each tester place the course-progress marker, and did Door A ever pull them upstream of it?
   - Tester A: —
   - Tester B: —
7. Did the tester move the class marker, and did the first expedition feel related to what they are doing in
   class?
   - Tester A: —
   - Tester B: —

No numeric pass threshold. The output of the demo is these five observations plus whatever the testers say
unprompted. That record decides whether the map form proceeds to M3 or is revised.

## Verification (DEMO-BRIEF §8, as amended by AMENDMENT-v2.2 §B)

Each line below carries exactly one tag — *simulator — agent* (naming the gate or instrument that evidences
it) or *device — owner* — and a blank result cell.

### 1. L0 passes on the shipped data (the L0 checks all pass)

Tag: *simulator — agent*.
Instrument: `scripts/gate.sh` gate 3 (`Core` build + `xcodebuild test -scheme Core-Package` on the iOS
simulator), which runs `core-cli`'s L0 validation over `data/demo`.
Result: PASS (simulator, agent), at `9a92440`, the final product tree. Gate 3 is green, and `core-cli validate data/demo` returns `passed: true` with all 10 L0 checks.

### 2. Builds and runs on a physical iPhone
Tag: *device — owner*.
Rationale: direct-install physical-device deployment (AMENDMENT-v2.4.md § 4, "direct install via Xcode") is
outside the simulator's reach; D29 reserves this to the owner at the wrap-gate.
Result: —

### 3. One expedition and one diagnosis event completable by touch

Split into two lines per arbiter-04 § Q-C.

**3a. *simulator — agent***

Evidenced by (i) the `Core` C1 façade tests (`xcodebuild test -scheme Core-Package`, gate 3) driving a full
expedition and a full diagnosis event through the `Core` façade entry points on real `data/demo`; (ii) the
one-call-per-button source scan of `App/Sources` Door B and Door A files (gate 4 scope, task 04.10); (iii) the
App build on the simulator (gate 4); (iv) EPIC 03's `scripts/sim-smoke.sh` launch smoke.

States, verbatim, the four exclusions this cannot claim (arbiter-04 § Q-C):

1. that any tap on a simulator actually fires its action: hit-testing, sheet and navigation presentation, and
   keypad key → string binding at runtime;
2. that each Door screen is laid out so its controls are visible and reachable (e.g. continue and decline are
   on screen);
3. that no runtime trap occurs along the Door screens after launch. The smoke only covers launch and relaunch;
4. that the sequence of screens a student sees matches the façade's screen values at runtime, rather than only
   in `CoreTests`.

Result: PASS for what this line can evidence (simulator, agent), at `9a92440`, the final product tree. The evidence is: (i) the C1 façade tests on real `data/demo` in gate 3. `DoorFacadeSeamTests` AC13 runs a full expedition with a first miss and a retry, checking the write-ahead after every state-changing call and the event order. AC14 covers (a) expedition second miss, then capped, then resumed; (b) check-here declined, giving unconfirmed; and (c) check-here with both answers correct, giving refuted. `DoorFacadeConformanceTests` confirms by source scan that these tests reach `Core` only through `DoorFacade.*`. (ii) The one-entry-per-function source scan of the `App/Sources` Door files (04.10, `688b421` / `1401890`) passes over the real tree. Its limitation, that it does not trace a `Button` closure into its method, is recorded together with a negative control. (iii) The App build on the simulator (gate 4) is green. (iv) The `scripts/sim-smoke.sh` launch passes. The four exclusions stated above apply in full: this makes no tap, layout, runtime-trap or runtime screen-order claim.

**3b. *device — owner***

The literal tap-through on a physical device (D29).
Result: —

### 4. State survives app relaunch

Tag: *simulator — agent*.
Instrument: `scripts/gate.sh` gate 4 (App build on simulator) together with EPIC 03's `scripts/sim-smoke.sh`
relaunch scenario (seeded state migrates and survives relaunch byte-identical).
Result: PASS (simulator, agent), at `9a92440`, the final product tree. Gate 4 `scripts/sim-smoke.sh` scenario 2 passed: seeded v1 state migrates to v2, validates against `student-state.schema.json`, and survives terminate + relaunch byte-identical.

### 5. Layout deterministic across launches

Tag: *simulator — agent*.
Instrument: `scripts/gate.sh` gate 3 (`xcodebuild test -scheme Core-Package`), which includes the layout
determinism test (same data → same positions across reloads).
Result: PASS (simulator, agent), at `9a92440`, the final product tree. Gate 3 `LayoutTests` "layout is deterministic for the same seed" and `LayoutRegressionTests` passed.

### 6. Landmark `source_url` resolves

Tag: *simulator — agent*.
Instrument (corrected at the 04b wrap): `scripts/gate.sh` gate 3 checks presence and https well-formedness only.
L0-10 does no network resolution in `Core` (`L0CheckerContractTests.swift:290`), and
`BundleLoaderConformanceTests.swift:108` refuses a landmark missing `source_url` (I15). Live resolution is gate 4:
`pipeline/tests/test_demo_bundle.py::test_landmark_source_url_resolves`, a real HTTPS fetch asserting that the page contains
the landmark's `source_title`; it skips only on `TransportInconclusive`.
Result: PASS (simulator, agent), at `9a92440`, the final product tree. A live fetch of `https://laws-lois.justice.gc.ca/eng/acts/I-15/` (landmark `canadian-mortgage-compounding`) returned a page containing "Interest Act": the test passed and was not skipped at `787f23b` on 2026-09-11. Final wrap gate: passed again in the final full gate at `9a92440` (pytest 190 passed, 0 skipped).

## Wrap responsibility

The wrap task (04.13) fills only the *simulator — agent* result cells above with the gate/test outcome. The
*device — owner* result cells stay blank in this task's output and remain blank until the owner records the
physical-device verification at the wrap-gate. This is a Q5 checkpoint by design (the record decides whether
the map form proceeds to M3 or is revised), not a pass/fail gate — no numeric threshold is implied anywhere in
this file.
