# Epic 04 · Task 04.11: Demo acceptance record template

---
epic: 04
task: 11
slug: demo-acceptance-record-template
kind: chore
risk: mechanical
depends_on: [04.6]
model: sonnet
---

> **Origin.** This task creates the blank acceptance-record template the EPIC 04b wrap (task 04.13) fills the
> agent half of, and the owner fills the device half of at physical-device verification (D29). It ships no
> code — one new Markdown file with per-tester blanks and a tagged checklist. No prior code output is
> consumed; the file is authored directly from DEMO-BRIEF §7/§8, their amendments, and the arbiter-04 § Q-C
> ruling.

## §1 Goal & acceptance criteria

Goal: create `docs/epics/demo-acceptance-record.md`, a blank template holding (a) per-tester (Tester A,
Tester B) rows for the seven acceptance observations of DEMO-BRIEF §7 as amended through v2.6, quoted
verbatim from their sources with "no numeric pass threshold" carried over, and (b) the DEMO-BRIEF §8
verification checklist as amended by AMENDMENT-v2.2 §B, de-duplicated, with every line tagged exactly one of
*simulator — agent* (naming the gate or instrument that evidences it) or *device — owner*, each with a blank
result cell. The template contains no filled data; task 04.13 fills only the agent-tagged lines.

Invariants in play:

- **I5** — testers are named only "Tester A" / "Tester B" throughout; no personal name, initial, or other
  identifier appears anywhere in the template. Satisfied by using only these two labels in every per-tester
  row.
- **I11** — no time estimate anywhere in the file (no duration figure for the demo, the testers, or any
  checklist line). Satisfied by the template carrying zero quantitative time claims; `scripts/check-no-time-
  estimates.sh` run against the new file is green.
- **D29** — physical-device verification is the owner's, at the wrap-gate; no agent task claims it. Satisfied
  by every device-only checklist line being tagged *device — owner* with its result cell left blank in this
  task, and by this task's own scope containing no device-verification claim.

Acceptance criteria (each independently verifiable):

- AC1: `docs/epics/demo-acceptance-record.md` exists and contains, verbatim, DEMO-BRIEF §7 items 1–5
  (`DEMO-BRIEF.md:95-99`), the amended item 6 (v2.1 §D, with "start marker" replaced by "course-progress
  marker" per `contracts/domain-glossary.md`'s glossary term), and the amended item 7 (v2.6 §D), each with a
  blank cell for Tester A and a blank cell for Tester B.
  Instrument: `grep -c` for each of the seven item texts plus two occurrences of "Tester A" / "Tester B" per
  item (see §5 T1).
- AC2: the file carries the preamble sentence "No numeric pass threshold" (`DEMO-BRIEF.md:101`, exact
  substring) verbatim in the §7 section header.
  Instrument: `grep -n "No numeric pass threshold" docs/epics/demo-acceptance-record.md`.
- AC3: the §8 checklist lists exactly the de-duplicated, amended set of lines — "L0 passes" (the one
  DEMO-BRIEF §8 line not restated by v2.2 §B) plus the five v2.2 §B replacement lines, with "one expedition
  and one diagnosis event completable by touch" split into its *simulator — agent* / *device — owner* pair
  per arbiter-04 § Q-C — and no other DEMO-BRIEF §8 line (the original browser-based lines 107 and 109 do not
  appear, since v2.2 §B replaces them).
  Instrument: manual line-count check against §4 step 3's fixed list; `grep -c "^- \*\*"` (or the template's
  actual list-item marker) on the §8 section equals the count fixed in §4 step 3.
- AC4: every §8 checklist line is tagged with exactly one of *simulator — agent* or *device — owner*, never
  both, never neither, and carries a blank result cell.
  Instrument: `grep -n` for each tag string, one occurrence per line (§5 T4).
- AC5: the *simulator — agent* tag on "one expedition and one diagnosis event completable by touch" names its
  instruments and states, verbatim, the four exclusions of arbiter-04 § Q-C (`tasks/arbitration/arbiter-04-
  predispatch.md:389-395`).
  Instrument: `grep -n` for each of the four exclusion sentences, byte-exact.
- AC6: "builds and runs on a physical iPhone" is tagged *device — owner*.
  Instrument: `grep -n -A1 "builds and runs on a physical iPhone"` shows the *device — owner* tag on the same
  or immediately following line.
- AC7: `scripts/check-no-time-estimates.sh docs/epics/demo-acceptance-record.md` exits 0.

## §2 File scope

In-scope (the implementer touches EXACTLY this file; nothing else):

- `docs/epics/demo-acceptance-record.md` — CREATE. Confirmed absent (`Glob docs/epics/demo-acceptance-
  record*` returns empty).

Out-of-scope (do not touch even if tempted):

- `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md` — the amended brief already specifies this
  template's contents at § 4 item 10; it is read, not edited, by this task.
- `tasks/arbitration/arbiter-04-predispatch.md` — the § Q-C ruling is read, not edited.
- Any file under `Packages/Core`, `App/Sources`, or `pipeline/` — this task ships no code.
- `scripts/check-no-time-estimates.sh`, `scripts/gate.sh` — read as instruments named in the template; not
  modified.
- Filling any result cell or the agent-tagged lines with an actual pass/fail value — that is task 04.13's
  scope, not this one's. This task ships a blank template only.

## §3 Inputs (verbatim — do not paraphrase)

DEMO-BRIEF §7 items 1–5 — `DEMO-BRIEF.md:95-99` (re-read and byte-verified in this run):

> 1. Did they click into the map before being told to?
> 2. Did they finish one expedition? Did they start a second unprompted?
> 3. Afterwards, can they say in their own words what a trail is?
> 4. Did the landmark make any node feel concrete (ask them to name which)?
> 5. When the diagnosis card appeared, did it read as help or as accusation?

DEMO-BRIEF §7 preamble and "no numeric pass threshold" — `DEMO-BRIEF.md:93, 101` (re-read and byte-verified):

> Owner runs the demo with the two target-age testers. Record, per tester:

> No numeric pass threshold. The output of the demo is these five observations plus whatever the testers say
> unprompted. That record decides whether the map form proceeds to M3 or is revised.

AMENDMENT-v2.1.md item 6 — `AMENDMENT-v2.1.md:48` (re-read and byte-verified in this run):

> §7 Acceptance → item 3 now testable for both testers (each has a trail). Add item 6: "Where did each tester
> place the start marker, and did Door A ever pull them upstream of it?"

The glossary term that replaces "start marker" in the quoted item 6 —
`contracts/domain-glossary.md § Map and graph (Door C)`, the Course-progress marker entry (re-read and
byte-verified in this run):

> - **Course-progress marker** ("we are here in class") — the student's chosen current unit (D45). Short form
>   in code: `marker`. *Banned:* "start marker" (v2.1 D28 name), "position", "cursor".

AMENDMENT-v2.6.md item 7 — `AMENDMENT-v2.6.md:40` (re-read and byte-verified in this run):

> §7 acceptance: add item 7 — "Did the tester move the class marker, and did the first expedition feel
> related to what they are doing in class?"

DEMO-BRIEF §8, original five lines — `DEMO-BRIEF.md:105-109` (re-read and byte-verified in this run):

> - `core/` validation passes on the shipped data; the L0 checks in §6 all pass.
> - Layout is deterministic: same data → same positions across reloads.
> - One full expedition and one diagnosis event can be completed by clicking, with no console errors.
> - Landmark `source_url` resolves and supports the description.
> - The demo loads and is operable on a phone browser (pan, zoom, tap a node, run an expedition).

AMENDMENT-v2.2.md §B, the §8 replacement clause — `AMENDMENT-v2.2.md:34` (re-read and byte-verified in this
run):

> Acceptance §7 unchanged (six observations). Verification §8: replace the browser items with: builds and
> runs on a physical iPhone; one expedition and one diagnosis event completable by touch; state survives app
> relaunch; layout deterministic across launches; landmark source URL resolves.

arbiter-04 § Q-C, the four exclusions and the split instruction — `tasks/arbitration/arbiter-04-
predispatch.md:387-403` (re-read and byte-verified in this run):

> **What it cannot claim** (the exclusion that must be stated verbatim in the 04b task specs and the
> acceptance report):
> 1. that any tap on a simulator actually fires its action: hit-testing, sheet and navigation presentation, and
>    keypad key → string binding at runtime;
> 2. that each Door screen is laid out so its controls are visible and reachable (e.g. continue and decline are
>    on screen);
> 3. that no runtime trap occurs along the Door screens after launch. The smoke only covers launch and relaunch;
> 4. that the sequence of screens a student sees matches the façade's screen values at runtime, rather than only
>    in `CoreTests`.
>
> So the epic-plan row 04 criterion ("one full expedition + one diagnosis completable by touch on the simulator
> (§8)") is **not claimed literally**. It is evidenced by logic, composition and static wiring.
>
> **The acceptance record must split the v2.2 §B line** "one expedition and one diagnosis event completable by
> touch" into two lines:
> - *simulator — agent*: logic, composition and wiring, naming the three instruments above and exclusions 1–4;
> - *device — owner*: the literal tap-through, D29.

The amended brief's own template spec — `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md:365-378`
(re-read and byte-verified in this run):

> 10. **Acceptance record template**: `docs/epics/demo-acceptance-record.md` holds:
>     - per-tester (A, B) blanks for DEMO-BRIEF §7 items 1–5, v2.1 §D item 6 and v2.6 §D item 7, quoted from
>       their sources, with "No numeric pass threshold" carried over;
>     - the §8 checklist as amended: the surviving DEMO-BRIEF §8 lines (L0 passes, deterministic layout,
>       landmark `source_url` resolves) plus v2.2 §B ("builds and runs on a physical iPhone; one expedition and
>       one diagnosis event completable by touch; state survives app relaunch; layout deterministic across
>       launches; landmark source URL resolves");
>     - the v2.2 §B clause "one expedition and one diagnosis event completable by touch" split into two lines:
>       *simulator — agent* (logic, composition and wiring, naming the instruments — the `Core` C1 façade tests,
>       the one-call-per-button source scan, the App build and EPIC 03's launch smoke — and exclusions 1–4 of §4
>       item 8), and *device — owner* (the literal tap-through, D29) (arbiter-04 § Q-C);
>     - on each line, its owner (*simulator — agent*, with the gate or instrument that evidences it, or *device —
>       owner*) and a blank result;
>     - the wrap's agent half filled in with instruments; the owner half left blank.

D29 — `CLAUDE.md` (re-read and byte-verified in this run):

> Gates: `scripts/gate.sh` — the four gates of `docs/tech-stack.md` §3 (swift-format + ruff; pyright strict;
> `Core` tests on the iOS simulator; App build on the simulator + pytest). `main` is protected: changes land
> only through a PR with both CI jobs green. **Physical-device verification is the owner's delivery
> verification at the wrap-gate; no agent task may claim it** (D29).

`docs/tech-stack.md`'s gate 3/4 text, source of the instrument names used in §4 below (re-read and
byte-verified in this run):

> 3. **Core:** `swift build -c release --product core-cli`; `xcodebuild test -scheme Core-Package` and
>    `-scheme Rendering` on the iOS simulator (D29 — the agent gate is the simulator, never a device).
> 4. **App + pipeline:** `xcodebuild build -scheme mathmath` on the simulator; `pytest`.

`docs/plans/epic-03-plan.md:117-119`, the EPIC 03 launch-smoke instrument (re-read and byte-verified in this
run):

> `scripts/sim-smoke.sh` (`xcrun simctl`) runs two scenarios, as the arbiter ruled for Q-G:
> 2. a seeded v1 file migrates to v2, validates with `jsonschema`, and survives a relaunch byte-identical.

## §4 Implementation outline

### 1. File header and layer note

Create `docs/epics/demo-acceptance-record.md` with a top-level heading, a one-line description that this is
the blank template for the EPIC 04 (Demo) acceptance record, and the following provenance line: the file
implements `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md` § 4 item 10, per the arbiter-04 § Q-C
ruling on the touch-completability split. State plainly: this file ships no code (layer ④ interaction's Demo
acceptance record, not a Core/App/pipeline artifact); it is filled by task 04.13 (agent half) and the owner
(device half) at the wrap-gate.

### 2. §7 section — per-tester observation rows

Write a "## Acceptance (DEMO-BRIEF §7, as amended through v2.6)" section. Open it with the preamble sentence
from §3 ("Owner runs the demo with the two target-age testers. Record, per tester:") and, after the seven
items, the exact substring "No numeric pass threshold" as part of the carried-over sentence from `DEMO-
BRIEF.md:101`.

List all seven items, each as its own row/entry with two blank cells labeled exactly "Tester A" and
"Tester B" (I5 — no other label, no name, no initial):

1. Did they click into the map before being told to?
2. Did they finish one expedition? Did they start a second unprompted?
3. Afterwards, can they say in their own words what a trail is?
4. Did the landmark make any node feel concrete (ask them to name which)?
5. When the diagnosis card appeared, did it read as help or as accusation?
6. Where did each tester place the course-progress marker, and did Door A ever pull them upstream of it?
7. Did the tester move the class marker, and did the first expedition feel related to what they are doing in
   class?

Item 6 uses "course-progress marker" (the glossary term, `contracts/domain-glossary.md § Map and graph`),
substituted for v2.1's now-banned "start marker" — this substitution is authorized by the glossary entry
quoted in §3, which names "start marker" as the banned v2.1 D28 synonym for the same concept. Item 7 is
quoted as amended (v2.6 uses "class marker" as a shorter synonym for the same course-progress marker; carry
the amendment's own wording unchanged, per the bundle's note that no further substitution is needed there).

Use a table or a list format with one row per item, each row carrying two blank cells (Tester A, Tester B).
Either markdown structure is acceptable as long as AC1's grep instrument (the seven item texts plus "Tester
A" / "Tester B" per item) passes.

### 3. §8 section — verification checklist, de-duplicated and tagged

Write a "## Verification (DEMO-BRIEF §8, as amended by AMENDMENT-v2.2 §B)" section. AMENDMENT-v2.2 §B
replaces DEMO-BRIEF §8's *browser* items (the original lines "One full expedition and one diagnosis event can
be completed by clicking, with no console errors" and "The demo loads and is operable on a phone browser
(pan, zoom, tap a node, run an expedition)") with its own five-item list. The one DEMO-BRIEF §8 line v2.2 §B
does not restate or replace is "`core/` validation passes on the shipped data; the L0 checks in §6 all pass"
— this is the sole surviving original line, stated here as "L0 passes on the shipped data (the L0 checks all
pass)". "Layout is deterministic" and "Landmark `source_url` resolves" both appear in v2.2 §B's own
replacement list, so they are NOT listed twice — one line each, sourced to v2.2 §B, not duplicated from the
original DEMO-BRIEF §8 lines 106/108.

The final checklist is exactly these lines, each tagged and each with one blank result cell:

1. **L0 passes on the shipped data (the L0 checks all pass).**
   Tag: *simulator — agent*.
   Instrument: `scripts/gate.sh` gate 3 (`Core` build + `xcodebuild test -scheme Core-Package` on the iOS
   simulator), which runs `core-cli`'s L0 validation over `data/demo`.
   Result: (blank).

2. **Builds and runs on a physical iPhone.**
   Tag: *device — owner*.
   Rationale: direct-install physical-device deployment (AMENDMENT-v2.4.md § 4, "direct install via Xcode")
   is outside the simulator's reach; D29 reserves this to the owner at the wrap-gate.
   Result: (blank).

3. **One expedition and one diagnosis event completable by touch.**
   Split into two lines per arbiter-04 § Q-C:
   - *simulator — agent*: evidenced by (i) the `Core` C1 façade tests (`xcodebuild test -scheme
     Core-Package`, gate 3) driving a full expedition and a full diagnosis event through the `Core` façade
     entry points on real `data/demo`; (ii) the one-call-per-button source scan of `App/Sources` Door B and
     Door A files (gate 4 scope, task 04.10); (iii) the App build on the simulator (gate 4); (iv) EPIC 03's
     `scripts/sim-smoke.sh` launch smoke. States, verbatim, the four exclusions this cannot claim (arbiter-04
     § Q-C):
     1. that any tap on a simulator actually fires its action: hit-testing, sheet and navigation
        presentation, and keypad key → string binding at runtime;
     2. that each Door screen is laid out so its controls are visible and reachable (e.g. continue and
        decline are on screen);
     3. that no runtime trap occurs along the Door screens after launch. The smoke only covers launch and
        relaunch;
     4. that the sequence of screens a student sees matches the façade's screen values at runtime, rather
        than only in `CoreTests`.
     Result: (blank).
   - *device — owner*: the literal tap-through on a physical device (D29).
     Result: (blank).

4. **State survives app relaunch.**
   Tag: *simulator — agent*.
   Instrument: `scripts/gate.sh` gate 4 (App build on simulator) together with EPIC 03's
   `scripts/sim-smoke.sh` relaunch scenario (seeded state migrates and survives relaunch byte-identical).
   Result: (blank).

5. **Layout deterministic across launches.**
   Tag: *simulator — agent*.
   Instrument: `scripts/gate.sh` gate 3 (`xcodebuild test -scheme Core-Package`), which includes the layout
   determinism test (same data → same positions across reloads).
   Result: (blank).

6. **Landmark `source_url` resolves.**
   Tag: *simulator — agent*.
   Instrument: `scripts/gate.sh` gate 3 (`Core` tests): a static validation test of `data/demo`'s landmark
   entries asserts every entry has a resolvable `source_url`, per I15.
   Result: (blank).

Note the checklist deliberately contains no separate "one expedition completable by touch" / "one diagnosis
event completable by touch" pair beyond item 3's single agent/device split above — the amended brief's own §4
item 10 names this as ONE v2.2 §B clause split into exactly two lines (agent, device), not four; do not
over-decompose it into separate expedition and diagnosis lines.

### 4. Footer — wrap responsibility

Add a closing note: the wrap task (04.13) fills only the *simulator — agent* result cells with the gate/test
outcome; the *device — owner* result cells stay blank in this task's output and remain blank until the owner
records the physical-device verification at the wrap-gate. This is a Q5 checkpoint by design (the record
decides whether the map form proceeds to M3 or is revised), not a pass/fail gate — no numeric threshold is
implied anywhere in this file.

### 5. Boundary / storage / model-call sections — not applicable

This task validates no external input, calls no model, and defines no storage shape; it authors static
Markdown. No schema, no error code, no confidence threshold applies.

### 6. Smoke check

`scripts/check-no-time-estimates.sh docs/epics/demo-acceptance-record.md` — must exit 0.

## §5 Test plan (mechanical risk)

- T1 smoke fidelity: `grep` each of the seven §7 item texts (verbatim, from §3/§4 step 2) appears exactly
  once in `docs/epics/demo-acceptance-record.md`, each accompanied by the literal strings "Tester A" and
  "Tester B" within its row/entry (not merely anywhere in the file — scoped to that item's own row).
  `grep -n "No numeric pass threshold" docs/epics/demo-acceptance-record.md` returns exactly one match.
- T2 negative — invalid input rejected at the boundary: N/A in the schema-validation sense (this task authors
  prose, not a document decoded against a schema). The applicable negative check: confirm the two superseded
  DEMO-BRIEF §8 browser-phrase lines do **not** appear — `! grep -q "no console errors"
  docs/epics/demo-acceptance-record.md` and `! grep -q "phone browser" docs/epics/demo-acceptance-record.md`
  must both succeed (exit 0, meaning absent), proving the §8 section is de-duplicated to the amended set, not
  the original DEMO-BRIEF wording.
- T3 error-taxonomy: N/A — no error code is introduced or referenced by this task (no code ships). Recorded
  explicitly as a decision, not an omission: `git diff --stat contracts/error-codes.json` is empty.

Additional mandatory checks (tagging discipline, since this is a shell the wrap task fills):

- Every §8 line carries exactly one of the two tag strings "simulator — agent" or "device — owner": for each
  of the six checklist items (item 3's split counting as two), `grep -c` for both tag strings combined on
  that item's block equals 1, never 0, never 2. This is derived from the two-tag registry stated in §4 step
  3 above — the allowlist is exactly `{simulator — agent, device — owner}`, not a hand-maintained separate
  list.
- "Builds and runs on a physical iPhone" and the *device — owner* half of "one expedition and one diagnosis
  event completable by touch" are both tagged *device — owner*: `grep -n -A2 "physical iPhone"` and the
  device-half block of item 3 each show the tag.
- The four arbiter-04 § Q-C exclusion sentences appear verbatim, scoped to the *simulator — agent* half of
  item 3's block only (not elsewhere in the file) — `grep -n -B2 -A10 "simulator — agent"` around item 3's
  block contains all four exclusion sentences byte-exact.
- Every result cell in both the §7 and §8 sections is blank (no pre-filled Tester A/B answer, no pre-filled
  agent result) — a manual read confirms no cell contains any text beyond the blank placeholder the
  implementer chooses (e.g. empty, `—`, or `TBD`-free placeholder; never the word "TODO"/"FIXME"/"XXX" per
  the hard rules).

## §6 Decision defaults

- IF the §8 checklist's line ordering is ambiguous THEN follow §4 step 3's fixed order (L0 passes; builds and
  runs on iPhone; expedition+diagnosis touch split; state survives relaunch; layout deterministic; landmark
  source_url resolves) — this is the order AMENDMENT-v2.2 §B's own sentence lists its five replacement items
  in, with "L0 passes" (the sole surviving original line) placed first since it is the only line not sourced
  to v2.2 §B. (Per `AMENDMENT-v2.2.md:34`, quoted in §3.)
- IF whether to represent the §7/§8 sections as Markdown tables or lists is unspecified THEN either is
  acceptable; the binding requirement is only that every quoted text, every "Tester A"/"Tester B" blank cell,
  every tag, and every blank result cell is present and greppable per §5's instruments. No contract mandates
  a table.
- IF the implementer is tempted to decompose "one expedition and one diagnosis event completable by touch"
  into four lines (an agent+device pair for expedition, a separate agent+device pair for diagnosis) THEN they
  must not: the amended brief's § 4 item 10 (quoted in §3) states the v2.2 §B clause is split "into two
  lines," and the arbiter-04 ruling (quoted in §3) states the same — the agent half's instrument list already
  names both the expedition and the diagnosis façade tests together, satisfying both without a fourth line.
  (Per `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md:372-375` and `tasks/arbitration/arbiter-04-
  predispatch.md:400-403`, both quoted in §3.)
- IF a blank-cell placeholder convention is needed (empty string vs. an explicit marker) THEN use an empty
  table cell or a plain em-dash "—"; never the literal word "TODO", "FIXME", "XXX", or any numeric
  placeholder that could be mistaken for a filled result (I11 — no quantitative claim, filled or otherwise,
  belongs in this task's output).
- IF a quantitative-sounding word appears unavoidably in quoted source text (e.g. "≈ 5 items" is not present
  in any §7/§8 source text used here, so this does not arise) THEN no action is needed; §3's quoted blocks
  contain no time-duration figure, confirmed by direct re-read in this run.

Standing defaults: identifiers and timestamps — not applicable (no schema, no persisted state shape in this
task). Model calls — not applicable (no model is invoked). Telemetry — not applicable (this file is static
documentation, not a telemetry payload). No identifying field anywhere — enforced via I5 (Tester A / Tester B
only). Nodes carrying `paraphrase`, never verbatim Ministry text — not applicable (no node content is
authored here).

## §7 Done definition

The task is done when ALL gates pass:

- `git diff --stat` shows exactly one new file: `docs/epics/demo-acceptance-record.md`.
- format + lint: N/A for Markdown (no `swift-format`/`ruff` target covers this path); `scripts/gate.sh`
  continues to pass end-to-end, confirming no accidental breakage.
- typecheck: N/A (no Swift or Python file is touched).
- `Core` build + test green — unaffected by this task; run once to confirm no accidental breakage.
- App build green + `pytest` — unaffected by this task; run once to confirm no accidental breakage.
- `scripts/check-no-time-estimates.sh docs/epics/demo-acceptance-record.md` exits 0.
- all checks of §5 (T1–T3 plus the tagging-discipline checks) pass as described.
- conforms to every contract/source section cited in §3 and §4, and to every invariant listed in §1.
