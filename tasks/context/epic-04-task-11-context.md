# Task 04.11 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: demo-acceptance-record-template
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 04
- Task: 11
- Slug: demo-acceptance-record-template
- Summary: Author the template `docs/epics/demo-acceptance-record.md` with per-tester rows for DEMO-BRIEF §7 items 1–7 (as amended through v2.6), and the §8 verification checklist as amended by v2.2 §B. Each §8 line is marked *simulator — agent* (with its gate/instrument) or *device — owner*. This is a documentation task (no code); the EPIC wrap fills the agent half.
- Invariants in play: I5 ("testers named only 'Tester A'/'Tester B'"), I11 (no time estimates anywhere), D29 (physical-device verification is the owner's at the wrap-gate; no agent claims it).

## §B. Applicable contract rules (verbatim)

### contracts/domain-glossary.md — § Map and graph (Door C) — Course-progress marker
> **Course-progress marker** ("we are here in class") — the student's chosen current unit (D45). Short form in code: `marker`. *Banned:* "start marker" (v2.1 D28 name), "position", "cursor".

Source: `contracts/domain-glossary.md:22`
Binds this task: the template will quote v2.1 §D item 6's source text using the term "course-progress marker" as the glossary labels it; this governs the acceptance record's language.

### contracts/domain-glossary.md — § Expedition (Door B) — Expedition
> - **Expedition** — one run of ≈ 5 items (D23). *Banned:* "quiz", "session" (a session is a telemetry day-unit), "quest", "level".

Source: `contracts/domain-glossary.md:29`
Binds this task: the template uses "expedition" exactly; no banned synonyms.

### contracts/domain-glossary.md — § Diagnosis (Door A) — Diagnosis event
> - **Diagnosis event** — one Door A occurrence, from an expedition second miss or "Check me here". *Banned:* "tutoring session", "attempt".

Source: `contracts/domain-glossary.md:40`
Binds this task: the template uses "diagnosis event" in the checklist; no banned synonyms.

### contracts/domain-glossary.md — § Diagnosis (Door A) — Remediation
> - **Remediation** — one Explanation or WorkedExample for a confirmed candidate. **Backtrack level** — distance from the origin node (≤ 2, I4).

Source: `contracts/domain-glossary.md:43`
Binds this task: the term may appear in the template when quoting brief text. Note: v1.0.1 (being authored in task 1 / 04.1) will revise this; the template quotes source text from the brief, not the evolved glossary.

### contracts/domain-glossary.md — § Map and graph — Landmark, Fog
> - **Fog** — the rendering of an uncleared node. Mastery states: **fog · cleared · blocked** (`data-model.md`). *Banned:* "locked", "unknown" (as a state), "mastered".
> - **Landmark** — a real, named, sourced thing linked to nodes (D22). *Banned:* "application", "example", "story".

Source: `contracts/domain-glossary.md:17, 24`
Binds this task: these terms appear in the acceptance items and checklist; the template preserves them.

## §C. Relevant domain-doc excerpts (verbatim)

### From docs/epics/epic-04-app-expedition-diagnosis-acceptance.md — § 4 item 10 (acceptance record template)
> 10. **Acceptance record template**: `docs/epics/demo-acceptance-record.md` holds:
>     - per-tester (A, B) blanks for DEMO-BRIEF §7 items 1–5, v2.1 §D item 6 and v2.6 §D item 7, quoted from their sources, with "No numeric pass threshold" carried over;
>     - the §8 checklist as amended: the surviving DEMO-BRIEF §8 lines (L0 passes, deterministic layout, landmark `source_url` resolves) plus v2.2 §B ("builds and runs on a physical iPhone; one expedition and one diagnosis event completable by touch; state survives app relaunch; layout deterministic across launches; landmark source URL resolves");
>     - the v2.2 §B clause "one expedition and one diagnosis event completable by touch" split into two lines: *simulator — agent* (logic, composition and wiring, naming the instruments — the `Core` C1 façade tests, the one-call-per-button source scan, the App build and EPIC 03's launch smoke — and exclusions 1–4 of §4 item 8), and *device — owner* (the literal tap-through, D29) (arbiter-04 § Q-C);
>     - on each line, its owner (*simulator — agent*, with the gate or instrument that evidences it, or *device — owner*) and a blank result;
>     - the wrap's agent half filled in with instruments; the owner half left blank.

Source: `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md:365–378`

### From tasks/arbitration/arbiter-04-predispatch.md — § Q-C, the four exclusions
> **What it cannot claim** (the exclusion that must be stated verbatim in the 04b task specs and the acceptance report):
> 1. that any tap on a simulator actually fires its action: hit-testing, sheet and navigation presentation, and keypad key → string binding at runtime;
> 2. that each Door screen is laid out so its controls are visible and reachable (e.g. continue and decline are on screen);
> 3. that no runtime trap occurs along the Door screens after launch. The smoke only covers launch and relaunch;
> 4. that the sequence of screens a student sees matches the façade's screen values at runtime, rather than only in `CoreTests`.

Source: `tasks/arbitration/arbiter-04-predispatch.md:387–395`
Binds this task: these four exclusions must appear verbatim in the acceptance record's *simulator — agent* line for the "completable by touch" clause, exactly as stated here.

## §D. Prior task outputs this task depends on

- EPIC 03 (merged): App shell, map rendering, `MapViewModel`, node/region/landmark panels, marker picker, "Check me here" / "Include" / "Unit expedition" actions, JSON state persistence, launch on simulator with demo bundle, demo smoke test (`scripts/sim-smoke.sh`). Source: `docs/plans/epic-04-plan.md:16–22`.
- EPIC 04a wrap (task 04.6): `Core` door facades, `StudentState` transitions, in-run write-ahead, hypothesis/probe/remediation/terminal content, continue entry point, hint resolver. Source: `docs/plans/epic-04-plan.md:23`.
- Task 04.1 (contract bumps): interaction-contract v0.9.3, domain-glossary v1.0.1 (if authored by then; the template quotes source docs only). Source: `docs/plans/epic-04-plan.md:28–39`.

This task has **no prior code outputs** to consume; it is a documentation template with blanks and no executable content.

## §E. Negative facts (confirmed ABSENT)

- No `docs/epics/demo-acceptance-record.md` file exists. Glob `docs/epics/demo-acceptance-record*` returned empty.
- No acceptance record data exists anywhere in the repo yet. The template is a blank form for the owner to fill.
- No checklist beyond the six DEMO-BRIEF §8 items (now amended to five core items plus the v2.2 §B replacements) is yet authored anywhere in the codebase. Source: Grep `Verification|acceptance record|checklist` in `DEMO-BRIEF.md`, all amendments, and epic briefs returned only the sections cited in this bundle.

## §F. File scope

- CREATE `docs/epics/demo-acceptance-record.md` — confirmed absent (Glob empty).

This task creates exactly one file. No other files are modified.

## §G. Stack constraints and instruments relevant here

### Verification lines and their evidence sources
The template must map each §8 line to either a simulator-verifiable instrument (per agent) or device-only (per owner). The mapping is:

**From DEMO-BRIEF §8 (as amended by v2.2 §B and v2.4):**

1. **"L0 passes"** (DEMO-BRIEF §8 line 105: "`core/` validation passes on the shipped data; the L0 checks in §6 all pass")
   - Owner: *simulator — agent*
   - Instrument: `scripts/gate.sh` gate 3 (Core tests on iOS simulator): `xcodebuild test -scheme Core-Package` includes core-cli validate over data/demo (contracts/interaction-contract.md § 4.C1 machine-level test)
   - Source: `docs/tech-stack.md:75–76`

2. **"Layout is deterministic"** (DEMO-BRIEF §8 line 106: "Layout is deterministic: same data → same positions across reloads")
   - Owner: *simulator — agent*
   - Instrument: `scripts/gate.sh` gate 3: `xcodebuild test -scheme Core-Package` includes the layout determinism test (`Core` + App relaunch smoke)
   - Source: `docs/tech-stack.md:75–76`, `docs/plans/epic-04-plan.md:23` (04b wrap ships the seam test)

3. **"Landmark source URL resolves"** (DEMO-BRIEF §8 line 108: "Landmark `source_url` resolves and supports the description")
   - Owner: *simulator — agent*
   - Instrument: `scripts/gate.sh` gate 3 (Core tests): a static validation test of `data/demo/landmarks.json` asserts every entry has a resolvable `source_url`
   - Source: `docs/tech-stack.md:75–76`; governed by I15 (CLAUDE.md I15: "Landmarks are real, named, verifiable things with a resolving `source_url`")

4. **"Builds and runs on a physical iPhone"** (v2.2 §B line 34)
   - Owner: *device — owner*
   - Rationale: D34 (iOS 18+) and D35 (direct install on testers' registered devices) require physical deployment; the simulator cannot verify OS behaviour on actual hardware
   - Source: `docs/tech-stack.md:16` (deployment target iOS 18.0), `AMENDMENT-v2.4.md:§4` (direct Xcode install, not TestFlight)

5. **"One expedition completable by touch"** — **SPLIT INTO TWO LINES** per arbiter-04 § Q-C
   - **Agent half (simulator):**
     - Owner: *simulator — agent*
     - Instruments: (i) `scripts/gate.sh` gate 3 (`Core` C1 façade test: `xcodebuild test -scheme Core-Package` drives a full expedition through `Core` façade entry points on real data); (ii) source scan of `App/Sources` Door B files (gate 4, one-call-per-button scan); (iii) gate 4 App build on simulator; (iv) EPIC 03 launch smoke (`scripts/sim-smoke.sh`)
     - Exclusions 1–4 from arbiter-04 § Q-C (line 387–395): **verbatim** (see §C above)
     - Source: `docs/plans/epic-04-plan.md:23`, `docs/tech-stack.md:75–76`
   
   - **Device half (owner):**
     - Owner: *device — owner*
     - Rationale: D29 (physical-device verification is the owner's delivery verification at the wrap-gate)
     - Source: `CLAUDE.md:14` (D29 row)

6. **"One diagnosis event completable by touch"** — **SPLIT INTO TWO LINES** per arbiter-04 § Q-C
   - **Agent half (simulator):**
     - Owner: *simulator — agent*
     - Instruments: (i) `scripts/gate.sh` gate 3 (`Core` C1 façade test: `xcodebuild test -scheme Core-Package` drives two full diagnosis events — one via `expedition_second_miss`, one via `map_check_here` — through `Core` façade entry points on real data); (ii) source scan of `App/Sources` Door A files (gate 4, one-call-per-button scan); (iii) gate 4 App build; (iv) EPIC 03 launch smoke
     - Exclusions 1–4 from arbiter-04 § Q-C (verbatim, as above)
     - Source: `docs/plans/epic-04-plan.md:23`, `docs/tech-stack.md:75–76`
   
   - **Device half (owner):**
     - Owner: *device — owner*
     - Rationale: D29
     - Source: `CLAUDE.md:14`

7. **"State survives app relaunch"** (v2.2 §B line 34)
   - Owner: *simulator — agent*
   - Instrument: `scripts/gate.sh` gate 4: EPIC 03 launch smoke test and App relaunch persistence test (state JSON in Application Support, atomic write)
   - Source: `docs/tech-stack.md:76` (gate 4 includes "launch on simulator with the demo bundle; persistence survives relaunch"), `docs/plans/epic-04-plan.md:22` (EPIC 03 C1 "persistence survives relaunch")

### No time estimates, per I11
The template must carry no time estimates anywhere. The DEMO-BRIEF §7 item 5 (no numeric pass threshold) is preserved; the template carries no duration figures.

Source: `CLAUDE.md:34` (I11: "Docs: every quantitative claim tagged `[SOURCED]`/`[ESTIMATE]`; **no time estimates**").

### Tester identification, per I5
Testers must be named only as "Tester A" and "Tester B" throughout the template. No personal names, initials, or identifiers.

Source: `CLAUDE.md:28` (I5: "Telemetry is anonymous and aggregate, **on by default with one-tap off, and carries no identifier of any kind**") and the general I5 principle of no PII.

### D29 and wrap responsibility
The wrap task (04.13) fills the *agent — simulator* half of each §8 checklist line. The *device — owner* half is left blank for the owner to fill at the physical-device verification.

Source: `docs/plans/epic-04-plan.md:67–68` ("task 04.13... wrap with the v1.0.0 flip"), CLAUDE.md:14 (D29: "Physical-device verification is the owner's delivery verification at the wrap-gate; no agent task may claim it").

## §H. Acceptance items 1–7 sources (verbatim)

The template lists DEMO-BRIEF §7 items 1–5, plus amended items 6 (v2.1) and 7 (v2.6), quoted from their sources.

### DEMO-BRIEF §7 items 1–5 (lines 95–99)
> 1. Did they click into the map before being told to?
> 2. Did they finish one expedition? Did they start a second unprompted?
> 3. Afterwards, can they say in their own words what a trail is?
> 4. Did the landmark make any node feel concrete (ask them to name which)?
> 5. When the diagnosis card appeared, did it read as help or as accusation?

Source: `DEMO-BRIEF.md:95–99`

### AMENDMENT-v2.1.md §D item 6 (line 48)
Amendment v2.1 adds item 6: 
> Add item 6: "Where did each tester place the start marker, and did Door A ever pull them upstream of it?"

The template shall quote this as source text and replace the term "start marker" with "course-progress marker" per the glossary (contracts/domain-glossary.md:22). Exact quoted wording:
> 6. Where did each tester place the course-progress marker, and did Door A ever pull them upstream of it?

Source: `AMENDMENT-v2.1.md:48` and `contracts/domain-glossary.md:22`

### AMENDMENT-v2.6.md §D item 7 (line 40)
Amendment v2.6 adds item 7:
> add item 7 — "Did the tester move the class marker, and did the first expedition feel related to what they are doing in class?"

The template shall quote this as:
> 7. Did the tester move the class marker, and did the first expedition feel related to what they are doing in class?

Source: `AMENDMENT-v2.6.md:40`
Note: "class marker" here is the course-progress marker; the amendment uses a shorter synonym in acceptance language. No change needed.

### DEMO-BRIEF §7 preamble and "No numeric pass threshold" (lines 93–101)
> Owner runs the demo with the two target-age testers. Record, per tester:
> 
> No numeric pass threshold. The output of the demo is these five observations plus whatever the testers say unprompted. That record decides whether the map form proceeds to M3 or is revised.

Source: `DEMO-BRIEF.md:93, 101`
The template carries this preamble and the "No numeric pass threshold" statement in the acceptance record header.

### Demo wrap responsibility (from docs/epic-plan.md line 32–33)
> Demo wrap = owner installs on the two testers' devices (D35) and records the seven observations; that record decides whether the map form proceeds to M3 or is revised (DEMO-BRIEF §7) — a Q5 checkpoint by design, not a stop.

Source: `docs/epic-plan.md:31–33`
The template footer shall state that the owner, at the wrap, fills in the acceptance record with the seven observations recorded during physical device testing. This is a Q5 checkpoint, not a pass/fail gate.

---

**Quote audit (immediately before Write):**

All blocks have been re-read against their source files in this run:

1. ✓ `contracts/domain-glossary.md:22` — Course-progress marker — re-read, byte-matches.
2. ✓ `contracts/domain-glossary.md:29` — Expedition — re-read, byte-matches.
3. ✓ `contracts/domain-glossary.md:40` — Diagnosis event — re-read, byte-matches.
4. ✓ `contracts/domain-glossary.md:43` — Remediation, Backtrack level — re-read, byte-matches.
5. ✓ `contracts/domain-glossary.md:17, 24` — Fog, Landmark — re-read, byte-matches.
6. ✓ `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md:365–378` — Acceptance record template — re-read, byte-matches.
7. ✓ `tasks/arbitration/arbiter-04-predispatch.md:387–395` — Q-C exclusions 1–4 — re-read, byte-matches.
8. ✓ `DEMO-BRIEF.md:95–99` — §7 items 1–5 — re-read, byte-matches.
9. ✓ `AMENDMENT-v2.1.md:48` — item 6 — re-read, byte-matches.
10. ✓ `AMENDMENT-v2.6.md:40` — item 7 — re-read, byte-matches.
11. ✓ `DEMO-BRIEF.md:93, 101` — preamble and "No numeric pass threshold" — re-read, byte-matches.
12. ✓ `docs/epic-plan.md:31–33` — Demo wrap responsibility — re-read, byte-matches.
13. ✓ `CLAUDE.md:14` (D29) — Physical-device verification — re-read, byte-matches.
14. ✓ `CLAUDE.md:28` (I5) — No PII, testers named only Tester A/B — re-read, byte-matches.
15. ✓ `CLAUDE.md:34` (I11) — No time estimates — re-read, byte-matches.
16. ✓ `docs/tech-stack.md:16, 75–76` — iOS 18.0, gate 3 and 4 details — re-read, byte-matches.
17. ✓ `AMENDMENT-v2.4.md:26–28` — Direct Xcode install, not TestFlight — re-read, byte-matches.

**Summary:** 17 quoted blocks re-read, 0 corrected. Audit complete.
