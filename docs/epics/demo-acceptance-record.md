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
Result: —

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

Result: —

**3b. *device — owner***

The literal tap-through on a physical device (D29).
Result: —

### 4. State survives app relaunch

Tag: *simulator — agent*.
Instrument: `scripts/gate.sh` gate 4 (App build on simulator) together with EPIC 03's `scripts/sim-smoke.sh`
relaunch scenario (seeded state migrates and survives relaunch byte-identical).
Result: —

### 5. Layout deterministic across launches

Tag: *simulator — agent*.
Instrument: `scripts/gate.sh` gate 3 (`xcodebuild test -scheme Core-Package`), which includes the layout
determinism test (same data → same positions across reloads).
Result: —

### 6. Landmark `source_url` resolves

Tag: *simulator — agent*.
Instrument: `scripts/gate.sh` gate 3 (`Core` tests): a static validation test of `data/demo`'s landmark
entries asserts every entry has a resolvable `source_url`, per I15.
Result: —

## Wrap responsibility

The wrap task (04.13) fills only the *simulator — agent* result cells above with the gate/test outcome. The
*device — owner* result cells stay blank in this task's output and remain blank until the owner records the
physical-device verification at the wrap-gate. This is a Q5 checkpoint by design (the record decides whether
the map form proceeds to M3 or is revised), not a pass/fail gate — no numeric threshold is implied anywhere in
this file.
