# Epic 03 · Task 01: Contract v0.9.2 — marker set only from the unit list (arbiter Q-B)

---
epic: 03
task: 01
slug: contract-interaction-marker-unit-list
kind: feat
risk: seam
depends_on: [none]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: bump `contracts/interaction-contract.md` from v0.9.1 to v0.9.2, closing the "unit-boundary snap for
dragging the marker" finalization item by recording arbiter ruling Q-B
(`tasks/arbitration/arbiter-03-predispatch.md`): in the Demo the marker is set **only** by choosing an entry
from the selected course's unit list — one entry per unit in unit order, then a final "past the last unit"
entry — with no drag gesture and no snap. This is one contract commit plus its two mandatory cascade edits,
authorized by the same ruling: `docs/domains/map.md` § W5 step 1 and its `MAP_MARKER_OFF_TRAIL` error row are
brought into agreement with the new contract text, and one `docs/DEFERRED.md` entry records the dropped drag
mechanism. This is a documentation-only, code-free change: no schema, no `Core` type, no pipeline module, no
`data/demo` file, and no `contracts/error-codes.json` entry is touched (`PLATFORM_SNAPSHOT_REFUSED`, arbiter
Q-C, is task 03.2's separate commit).

Invariants in play:

- **I1** — not engaged: this task adds no item-checking rule. Recorded so its absence is a decision, not a
  gap.
- **I2** — not engaged: this task adds no model-calling path.
- **I3** — untouched: no answer-visibility text is touched by this task's edits.
- **I5** — not engaged: no telemetry field, no identifier is added or changed.
- **I6** — not engaged: no Ministry text, no `paraphrase` field is touched.
- **I8** — not engaged: § 3's L0-T trail-path behaviour is unchanged; the new bullet only narrows *how* a
  marker value is produced (unit-list choice, never a dragged position), never what makes a trail valid.
- **I14** — the new § 3 bullet keeps `set_marker(course, unit)`'s existing shape (a unit id in, never a
  screen position); this task writes contract text only, no second implementation anywhere.
- **I15** — not engaged: no landmark field is touched.

Acceptance criteria (each independently verifiable):

- AC1: `contracts/interaction-contract.md`'s `Contract version` line reads `v0.9.2`, and the Source sentence
  is appended (not replaced) with the v0.9.2 resolution clause naming arbiter Q-B, per §4 step 1 below.
  Instrument: `rg -n "Contract version" contracts/interaction-contract.md`.
- AC2: § 3 Marker and trail carries a new, third bullet — after the existing `set_marker` and `generate_trail`
  bullets — stating the marker is set only from the course's unit list, with a final "past the last unit"
  entry, no drag, no snap, and a unit-list choice never off the trail; the bullet text is byte-identical to
  `tasks/arbitration/arbiter-03-predispatch.md:106-108`. Instrument: `rg -n "set only by choosing an entry"
  contracts/interaction-contract.md`.
- AC3: § Finalization owed by the Demo EPIC no longer lists "the unit-boundary snap for dragging the marker";
  the remaining two items (answer-card timing, summary region tint deltas) stay, and a new sentence records
  the v0.9.2 resolution, byte-identical to `tasks/arbitration/arbiter-03-predispatch.md:109-111`. Instrument:
  `rg -n "unit-boundary snap" contracts/interaction-contract.md` returns no match; `rg -n "Resolved in v0.9.2"
  contracts/interaction-contract.md` returns one match.
- AC4: `docs/domains/map.md` § W5 step 1 no longer describes a drag gesture; the sentence "Dragging the
  marker along the trail is the same action: it snaps to the nearest unit boundary, else
  `MAP_MARKER_OFF_TRAIL` and stays." is replaced by "The marker is set from this list only; there is no drag
  (interaction-contract v0.9.2 § 3)." with no other change to the W5 paragraph. Instrument: `rg -n "there is
  no drag \(interaction-contract v0.9.2" docs/domains/map.md`.
- AC5: `docs/domains/map.md` § Errors produced, row `MAP_MARKER_OFF_TRAIL`, has its "When" and "User sees"
  columns replaced per the ruling; the code string and "Recoverable" column (`Yes`) are unchanged, so
  `test_error_registry_matches_domain_docs` still finds the code. Instrument: `rg -n "A stored marker names a
  course not in" docs/domains/map.md`.
- AC6: `docs/DEFERRED.md` carries one new entry, `D-14 — Marker drag with unit-boundary snap`, following the
  file's own C6 entry template (`Observed` / `Configuration` / `Revisit trigger` / `Hypothesis (unverified)`),
  appended after the current last entry (`D-13`), with `Revisit trigger` reading "Demo observations
  (`DEMO-BRIEF.md` § 7 Acceptance)" and `Hypothesis (unverified)` reading "none". Instrument: `rg -n "### D-14"
  docs/DEFERRED.md`.
- AC7: `git diff --stat` touches exactly three files: `contracts/interaction-contract.md`,
  `docs/domains/map.md`, `docs/DEFERRED.md`.

## §2 File scope

In-scope (the implementer touches EXACTLY these three files; nothing else):

- `contracts/interaction-contract.md` — MODIFY. Version line append, § 3 new bullet, § Finalization owed
  paragraph replacement (§4 steps 1–3 below).
- `docs/domains/map.md` — MODIFY. § W5 step 1 sentence replacement and § Errors produced `MAP_MARKER_OFF_TRAIL`
  row replacement only (§4 steps 4–5 below). No other line in this file changes.
- `docs/DEFERRED.md` — MODIFY. Append one new entry, `D-14`, after the current last entry (§4 step 6 below).
  No existing entry's text changes.

Out-of-scope (do not touch even if tempted):

- `contracts/error-codes.json` and `docs/domains/platform.md` — arbiter Q-C's `PLATFORM_SNAPSHOT_REFUSED`
  registration is a separate commit, task 03.2's file scope, not this task's.
- `Packages/Core/**` — no `Core` code exists for this ruling; nothing here is implemented yet.
- `data/demo/**` — no data edit.
- `docs/DEFERRED.md` entries `D-1`…`D-13` — read-only precedent for the C6 template; none of their text
  changes.
- `docs/epics/epic-03-app-map-shell.md` — the brief itself is amended by the arbiter ruling for later tasks'
  purposes, but this task's scope is limited to the three files above; it does not edit the brief.
- `pipeline/**` — this task has no executable surface; nothing under `pipeline/` changes or is tested by it.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/README.md` — heading `## Lock-first rule`:
  > `data-model`, `graph-constraints`, `content-policy`, `telemetry`, `domain-glossary`, `runtime-tiers` and
  > `deployment-model` **lock before any dependent EPIC starts** — retrofitting them corrupts shipped data, the
  > graph, or the compliance position. Discovery-zone contracts stay open and are finalized just-in-time. A
  > change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every conforming
  > EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

  Note: `interaction-contract.md` is listed in `contracts/README.md`'s `## The set` table as "discovery —
  finalize just-in-time (Demo EPIC)", not among the seven LOCK-FIRST contracts. This task nonetheless follows
  the same versioning discipline (bump `Contract version`, scope the commit `contract(interaction-contract)`)
  because the file carries its own `Contract version` line and the change closes one of the three items its
  own § Finalization owed lists as owed by the Demo EPIC.

- `contracts/README.md` — heading `## The set`, the `interaction-contract.md` row:
  > | [`interaction-contract.md`](interaction-contract.md) | discovery — finalize just-in-time (Demo EPIC) |
  > runtime contract test: state-machine property tests in `CoreTests` (EPIC-time) | the three doors as state
  > machines: expedition, diagnosis, marker/trail |

  Binds this task: the contract change is enforced later by runtime property tests in `CoreTests`, authored in
  EPIC 03 tasks 03.6 onward. This task lands the contract text only.

Arbiter ruling, verbatim, authorizing this task's three edits and its two cascades
(`tasks/arbitration/arbiter-03-predispatch.md` § Q-B):

- Header/version line append (`arbiter-03-predispatch.md:102-104`):
  > 1. Header line: `**Contract version:** v0.9.2 (discovery zone — finalized just-in-time by the Demo EPIC)`,
  >    and append to the Source sentence: `; v0.9.2 resolves the marker-drag finalization item (arbiter Q-B,
  >    \`tasks/arbitration/arbiter-03-predispatch.md\`)`.

- § 3 new bullet (`arbiter-03-predispatch.md:106-108`):
  > 2. § 3 Marker and trail — append a bullet:
  >    > - The marker is set only by choosing an entry from the selected course's unit list: one entry per unit
  >    >   in unit order, then a final "past the last unit" entry (`past_last_unit: true`). No gesture moves the
  >    >   marker; there is no drag and no snap. A unit-list choice is never off the trail.

- § Finalization owed replacement (`arbiter-03-predispatch.md:109-111`):
  > 3. § Finalization owed by the Demo EPIC — replace the paragraph with:
  >    > The timing of the answer card; whether the summary shows region tint deltas. Bump to v1.0.0 on wrap.
  >    > (Resolved in v0.9.2: the marker is set from the unit list only — § 3; no drag.)

- `docs/domains/map.md` § W5 cascade (`arbiter-03-predispatch.md:114-116`):
  > `docs/domains/map.md` § W5 step 1: replace "Dragging the marker along the trail is the same action: it
  > snaps to the nearest unit boundary, else `MAP_MARKER_OFF_TRAIL` and stays." with "The marker is set from
  > this list only; there is no drag (interaction-contract v0.9.2 § 3)."

- `docs/domains/map.md` error-row cascade (`arbiter-03-predispatch.md:117-120`):
  > `docs/domains/map.md` § Errors produced, row `MAP_MARKER_OFF_TRAIL`: "When" becomes "A stored marker names
  > a course not in `syllabi[]` or a unit absent from the bundle (load, expedition W7)", and "User sees"
  > becomes "Nothing on the load path — the map opens at the default marker (arbiter-03 Q-A)". The registry
  > entry is unchanged. The code string stays in the doc, so `test_error_registry_matches_domain_docs` remains
  > green.

- `docs/DEFERRED.md` entry cascade (`arbiter-03-predispatch.md:121-122`):
  > Add a `docs/DEFERRED.md` entry "Marker drag with unit-boundary snap", following the C6 template. Revisit
  > trigger: Demo observations (`DEMO-BRIEF.md` § 7 Acceptance). Hypothesis: none.

Prior contract text this task edits in place (from `contracts/interaction-contract.md`, current v0.9.1, read
directly and quoted verbatim so every diff below is unambiguous):

- Version line (`contracts/interaction-contract.md:3-7`):
  ```
  **Contract version:** v0.9.1 (discovery zone — finalized just-in-time by the Demo EPIC) · Source: brief v2
  §7, D23, D27, D44–D48, v2.7 §3; `map.md`, `expedition.md`, `diagnosis.md`; v0.9.1 adds the numeric
  normalisation rule (expedition Q4), the `remediated(p)` predicate and its two ripples (arbiter Q-A,
  `tasks/arbitration/arbiter-02-predispatch.md`), the `past_last_unit` marker text (arbiter Q-F), and the
  probe "available" definition (arbiter Q-G)
  ```

- § 3 Marker and trail, full section (`contracts/interaction-contract.md:62-74`):
  ```
  ## 3. Marker and trail (D45, D47)

  - `set_marker(course, unit)` → regenerate trail → recompute fringe. Marker default = first unit of the
    selected course. Nodes upstream of the marker keep their mastery.
    The marker is past the course's last unit iff `marker.past_last_unit == true`, whichever unit `unit_id`
    names; setting it writes the course's last unit as `unit_id`. While past the last unit, the
    `marker.unit ∪ next(marker.unit)` window of §2 `compose` is the nodes of the `extension` segment (empty
    when there is none). Nodes of the course are then upstream of the marker. A marker whose `course_code` is
    not in `syllabi[]`, or whose `unit_id` is not a unit of that course in the bundle, is off the trail
    (`MAP_MARKER_OFF_TRAIL`, default marker) regardless of `past_last_unit`.
  - `generate_trail`: course segments in unit order; if the marker is past the course's last unit, an
    `extension` segment along downstream edges preferring `next_courses[]`, then undergraduate nodes; every
    segment a path (L0-T) else `EXP_TRAIL_INVALID` and the previous trail stands.
  ```

- § Finalization owed by the Demo EPIC, full section (`contracts/interaction-contract.md:117-119`):
  ```
  ## Finalization owed by the Demo EPIC
  The unit-boundary snap for dragging the marker; the timing of the answer card; whether the summary shows
  region tint deltas. Bump to v1.0.0 on wrap.
  ```

Prior domain-doc text this task edits in place (from `docs/domains/map.md`, read directly and quoted
verbatim):

- § W5, full section (`docs/domains/map.md:88-95`):
  ```
  ### W5 — Set the course-progress marker
  **Pre:** a course trail segment is selected. **Steps:** 1. Show the course's **unit list** (curriculum-spine
  `Unit`s, D45) with the current one highlighted; the student picks "we are here in class". Dragging the
  marker along the trail is the same action: it snaps to the nearest unit boundary, else
  `MAP_MARKER_OFF_TRAIL` and stays. 2. Hand the unit id to **expedition** (`map.marker_moved`), which owns the
  change, regenerates the trail (D47 — past the last unit the trail extends, drawn dashed) and recomputes the
  fringe (D45/D48). 3. Re-derive fog: nodes upstream of the marker are fog with an "upstream of your class"
  note, never cleared. **Post:** marker persisted by expedition; `map.marker_moved` emitted (a D40 event).
  ```

- § Errors produced, row `MAP_MARKER_OFF_TRAIL` (`docs/domains/map.md:126`):
  ```
  | `MAP_MARKER_OFF_TRAIL` | Marker dropped outside a unit boundary of the selected course | Marker snaps back | Yes |
  ```

`docs/DEFERRED.md`'s own C6 entry template (`docs/DEFERRED.md:9-15`):
```
### D-n — <item>
**Observed:** what was actually measured or decided, and where that is recorded.
**Configuration:** the environment/config under which that observation holds.
**Revisit trigger:** the condition that brings this item back.
**Hypothesis (unverified):** any diagnosis or proposed remedy — or "none".
```

`docs/DEFERRED.md`'s last entry, confirmed to be `D-13` at time of writing (`docs/DEFERRED.md:135`):
```
### D-13 — Untracked SwiftPM artefact under the Xcode project's embedded workspace
```
The next free id is `D-14`. If a concurrently-landed task has already claimed `D-14` by the time this task is
implemented, re-read `docs/DEFERRED.md` and take the next free id instead — the entry's content does not
depend on its number.

## §4 Implementation outline

This is a documentation-only contract edit. There is no boundary schema, no error code, no storage/asset
access and no model-calling path in this task (§1 records I1–I3, I5, I6, I15 as not engaged). The six ordered
edits below are applied in place.

1. **`contracts/interaction-contract.md` — version line.** Change `v0.9.1` to `v0.9.2` in the header
   (`**Contract version:** v0.9.2 …`), and append to the end of the existing Source sentence (after
   `probe "available" definition (arbiter Q-G)`, with no period before the append — match the existing
   sentence's punctuation style, which has none at its current end):
   ```
   ; v0.9.2 resolves the marker-drag finalization item (arbiter Q-B,
   `tasks/arbitration/arbiter-03-predispatch.md`)
   ```
   Resulting full version line block:
   ```
   **Contract version:** v0.9.2 (discovery zone — finalized just-in-time by the Demo EPIC) · Source: brief v2
   §7, D23, D27, D44–D48, v2.7 §3; `map.md`, `expedition.md`, `diagnosis.md`; v0.9.1 adds the numeric
   normalisation rule (expedition Q4), the `remediated(p)` predicate and its two ripples (arbiter Q-A,
   `tasks/arbitration/arbiter-02-predispatch.md`), the `past_last_unit` marker text (arbiter Q-F), and the
   probe "available" definition (arbiter Q-G); v0.9.2 resolves the marker-drag finalization item (arbiter Q-B,
   `tasks/arbitration/arbiter-03-predispatch.md`)
   ```
   The `v0.9.1 adds …` clause is history and stays untouched — only the header's version number and the
   sentence's tail change.

2. **`contracts/interaction-contract.md` § 3 — new bullet.** Append this as a **third** bullet to § 3 Marker
   and trail, immediately after the `generate_trail` bullet quoted in §3 above (its own list item, same
   indentation as the other two bullets):
   ```
   - The marker is set only by choosing an entry from the selected course's unit list: one entry per unit in
     unit order, then a final "past the last unit" entry (`past_last_unit: true`). No gesture moves the marker;
     there is no drag and no snap. A unit-list choice is never off the trail.
   ```

3. **`contracts/interaction-contract.md` § Finalization owed.** Replace the section quoted in §3 above with:
   ```
   ## Finalization owed by the Demo EPIC
   The timing of the answer card; whether the summary shows region tint deltas. Bump to v1.0.0 on wrap.
   (Resolved in v0.9.2: the marker is set from the unit list only — § 3; no drag.)
   ```

4. **`docs/domains/map.md` § W5 step 1.** Replace the sentence "Dragging the marker along the trail is the
   same action: it snaps to the nearest unit boundary, else `MAP_MARKER_OFF_TRAIL` and stays." with "The
   marker is set from this list only; there is no drag (interaction-contract v0.9.2 § 3)." No other sentence
   in the W5 paragraph changes. Resulting full section:
   ```
   ### W5 — Set the course-progress marker
   **Pre:** a course trail segment is selected. **Steps:** 1. Show the course's **unit list** (curriculum-spine
   `Unit`s, D45) with the current one highlighted; the student picks "we are here in class". The marker is set
   from this list only; there is no drag (interaction-contract v0.9.2 § 3). 2. Hand the unit id to
   **expedition** (`map.marker_moved`), which owns the change, regenerates the trail (D47 — past the last unit
   the trail extends, drawn dashed) and recomputes the fringe (D45/D48). 3. Re-derive fog: nodes upstream of the
   marker are fog with an "upstream of your class" note, never cleared. **Post:** marker persisted by
   expedition; `map.marker_moved` emitted (a D40 event).
   ```

5. **`docs/domains/map.md` § Errors produced, `MAP_MARKER_OFF_TRAIL` row.** Replace the row quoted in §3 above
   with:
   ```
   | `MAP_MARKER_OFF_TRAIL` | A stored marker names a course not in `syllabi[]` or a unit absent from the bundle (load, expedition W7) | Nothing on the load path — the map opens at the default marker (arbiter-03 Q-A) | Yes |
   ```
   The code string (`MAP_MARKER_OFF_TRAIL`) and the "Recoverable" column (`Yes`) are unchanged; only "When" and
   "User sees" change.

6. **`docs/DEFERRED.md` — new entry.** Append, after the current last entry (`D-13`, confirmed above; take the
   next free id if that has changed by implementation time), a blank line then:
   ```
   ### D-14 — Marker drag with unit-boundary snap

   **Observed:** `interaction-contract.md` v0.9.1 listed "the unit-boundary snap for dragging the marker" as a
   finalization item owed by the Demo EPIC. Arbiter ruling Q-B (`tasks/arbitration/arbiter-03-predispatch.md`)
   resolved it for the Demo: the marker is set only by choosing an entry from the selected course's unit list,
   with a final "past the last unit" entry; no drag gesture is built, and `docs/domains/map.md` § W5 no longer
   describes a drag path.
   **Configuration:** `interaction-contract.md` v0.9.2 § 3; the Demo's marker picker (EPIC 03 task 03.11) is a
   unit-list picker only, with no drag gesture.
   **Revisit trigger:** Demo observations (`DEMO-BRIEF.md` § 7 Acceptance).
   **Hypothesis (unverified):** none.
   ```
   Follow the file's existing separator convention between entries: a single blank line before the
   `### D-14` heading, with no `---` rule. The file's only `---` (line 25 at time of writing) separates the intro
   block from `### D-1`; no `---` precedes D-2 through D-13. (Orchestrator correction after review.)

7. **Commit.** One commit, `contract(interaction-contract): marker set only from the unit list, no drag
   (v0.9.2)`, touching exactly the three files of §2. The PR description names the ruling this task carries
   out (arbiter Q-B, `tasks/arbitration/arbiter-03-predispatch.md`) and the two cascade edits it authorizes.

8. **Smoke check.** `rg -n "Contract version|set only by choosing an entry|Resolved in v0.9.2|there is no drag
   \(interaction-contract v0.9.2|A stored marker names a course not in|### D-14|unit-boundary snap"
   contracts/interaction-contract.md docs/domains/map.md docs/DEFERRED.md` — must show every new/changed
   string present in its target file, and `unit-boundary snap for dragging` absent from
   `contracts/interaction-contract.md`. `git diff --stat` shows exactly three files changed.

## §5 Test plan (seam risk — full plan)

This task ships no code, so its "tests" are the verifiable textual assertions below — the cheapest rung that
actually holds prose contract and domain-doc text (`contracts/README.md` § Enforcement ladder: "type system →
static analysis / lint → schema / config check → runtime contract test"; a grep-based content assertion is
the lint rung). The rule's *behavioural* conformance (the unit-list picker offering no drag, a unit-list
choice never off-trail) is proven at the runtime-contract-test rung by EPIC 03 tasks 03.6 onward
(`MapViewModel`, the façade), which this task's text is normative input to, not the instrument for.

- **T1 happy path.** Run the smoke check of §4 step 8. Every one of the seven grepped strings is present
  exactly where §4 places it (verified by a full read of all three files after edit, not just the grep match
  count); `unit-boundary snap for dragging` has zero matches anywhere in `contracts/interaction-contract.md`.
- **T2 negative — invalid input rejected at the boundary.** Not applicable in the schema/code sense (this task
  validates no runtime input). The equivalent negative check for prose text: confirm the *old* text each edit
  replaces no longer appears unmodified — `rg -n "Dragging the marker along the trail is the same action"
  docs/domains/map.md` returns no match; `rg -n "Marker dropped outside a unit boundary of the selected
  course \| Marker snaps back" docs/domains/map.md` returns no match; `rg -n "The unit-boundary snap for
  dragging the marker; the timing" contracts/interaction-contract.md` returns no match. A diff that leaves the
  old text duplicated alongside the new one is a FAIL.
- **T3 error-taxonomy.** Nothing to assert: this task registers no error code in `contracts/error-codes.md` /
  `error-codes.json` and touches no registry entry. `MAP_MARKER_OFF_TRAIL`'s registered `user_text` in
  `contracts/error-codes.json` is unchanged (the ruling's own text: "The registry entry is unchanged"); only
  the domain-doc row's descriptive columns change. Recorded explicitly so the omission is a decision, not a
  gap.
- **T4 conformance per §B.1 / cited contract and invariants.** Re-read all three edited files top to bottom
  and confirm: (a) each of the six edits in §4 appears verbatim as specified, with no adjacent text altered;
  (b) the version line names the v0.9.2 resolution and arbiter Q-B (AC1); (c) § 3's new bullet is
  byte-identical to `tasks/arbitration/arbiter-03-predispatch.md:106-108` (AC2); (d) § Finalization owed is
  byte-identical to `tasks/arbitration/arbiter-03-predispatch.md:109-111` (AC3); (e) the W5 and error-row
  edits read grammatically as continuous prose after replacement, with no orphaned clause; (f) the DEFERRED
  entry follows the C6 template with all four fields present and non-empty; (g) I8 holds — § 3's L0-T
  trail-path text is untouched by this task's diff.
- **T5 negative control for every regression guard.** The regression guard this task installs is the grep set
  of §4 step 8. Its negative control: temporarily revert one edit (e.g. re-insert "Dragging the marker along
  the trail is the same action: it snaps to the nearest unit boundary, else `MAP_MARKER_OFF_TRAIL` and stays."
  into `docs/domains/map.md` § W5) and confirm the smoke check of §4 step 8 fails (the "there is no drag"
  grep no longer matches at that location, or the T2 negative check now matches the old text). Perform this
  once per edit during review, not as a committed test file (there is no test harness for `contracts/*.md` or
  `docs/*.md` prose in this repository today — confirmed absent by the precedent task
  `tasks/epic-02-task-01-contract-interaction-numeric-normalisation.md` § T5, which records the same finding
  for `contracts/interaction-contract.md`; `docs/domains/map.md` and `docs/DEFERRED.md` have no dedicated test
  either, since `pipeline/tests/test_contracts.py`'s `test_error_registry_matches_domain_docs` only checks
  that the `MAP_MARKER_OFF_TRAIL` **code string** still appears in `docs/domains/map.md`, which this task's
  edit preserves — AC5).
- **T6 idempotency / no-leak.** Re-applying the same six edits to the post-edit files is a no-op (each target
  string, once present, is not matched again by its own insertion instruction — every insertion in §4 targets
  a string from the *pre*-edit files, quoted in §3, which no longer exists post-edit; `docs/DEFERRED.md`'s
  entry insertion targets "after the current last entry", and `D-14` is itself the new last entry, so a
  second application would append `D-15` with identical content rather than duplicating `D-14` — flagged here
  so the implementer does not run the edit twice). No side file is touched; `git diff --stat` after the commit
  shows exactly three files.

## §6 Decision defaults

- IF the version-line append should replace the entire Source sentence (as the EPIC 02 precedent did for its
  own v0.9.0 → v0.9.1 bump) rather than append to it THEN it must append: the arbiter ruling's own instruction
  is "append to the Source sentence" (`arbiter-03-predispatch.md:103-104`), and the `v0.9.1 adds …` clause
  is a still-true historical record of what v0.9.1 added, not a stale value to overwrite.
- IF § 3's new bullet should be merged into the existing `set_marker` bullet (since both describe how the
  marker is set) THEN it must not: the ruling's own instruction is "append **a bullet**" to § 3
  (`arbiter-03-predispatch.md:105`), i.e. a new, third list item, not a sentence folded into `set_marker`.
- IF the W5 replacement sentence should also mention the "past the last unit" entry (since § 3's new bullet
  does) THEN it must not: the ruling's cascade text for W5 is exactly "The marker is set from this list only;
  there is no drag (interaction-contract v0.9.2 § 3)." (`arbiter-03-predispatch.md:115-116`) — W5 already
  describes the unit-list mechanism in its own first sentence ("Show the course's **unit list** … the student
  picks 'we are here in class'"), so the replacement only needs to state the no-drag fact and point to the
  contract for detail.
- IF the `MAP_MARKER_OFF_TRAIL` error row's "Recoverable" column should change from `Yes` to something else,
  given the "User sees" text now describes a silent load-path outcome THEN it must not change: the ruling's
  cascade text names only "When" and "User sees" as changing ("The registry entry is unchanged" —
  `arbiter-03-predispatch.md:119`), and the registry's own `recoverable` field for this code is untouched by
  this task (out of scope, §2).
- IF `docs/DEFERRED.md`'s new entry should be numbered something other than `D-14` because a concurrent task
  has already claimed it by the time this task runs THEN take the next free id by re-reading the file — the
  entry's content (name, Observed, Configuration, Revisit trigger, Hypothesis) does not depend on its number,
  per §3's note on `D-13` being "the last entry at time of writing" and the planner's own framing ("EPIC 03's
  03.8 and 03.13 add more later, so take the next free id at implementation time").
- IF this task should also close `docs/DEFERRED.md`'s existing `D-12` entry (`MAP_MARKER_OFF_TRAIL` user text
  vs. the load-time marker fallback), since this task's error-row edit touches the same code THEN it must not:
  arbiter ruling Q-A (not Q-B) governs `D-12`'s closure, and the arbiter's own "Wrap action" for Q-A assigns
  that to the EPIC 03b wrap (task 03.13, per `docs/plans/epic-03-plan.md` § 03.13 "Close D-12 with the Q-A
  ruling"), not this task. This task's error-row edit is authorized by Q-B's
  cascade only, and leaves `D-12` as read-only precedent (§2 out-of-scope).

Standing defaults: identifiers and timestamps are unaffected by this task (no schema, no field). No model
call exists in this task, so no confidence threshold or Tier-0 fallback applies (I2 not engaged). Telemetry
is unaffected. No field anywhere is added that could identify a person, device or session — this task adds
prose only, no field. Ministry text is not touched; no `paraphrase` field exists in any file this task edits.

## §7 Done definition

The task is done when ALL gates pass:

- `scripts/gate.sh` green end-to-end (unaffected by a docs-only change, but run in full per standing practice
  — no gate in `scripts/gate.sh` reads `contracts/interaction-contract.md`, `docs/domains/map.md` or
  `docs/DEFERRED.md`, so this is a regression check that the change introduced no stray edit elsewhere)
- `git diff --stat` shows exactly three files changed: `contracts/interaction-contract.md`,
  `docs/domains/map.md`, `docs/DEFERRED.md`
- the smoke check and T1/T2/T5 checks of §5 pass
- `Contract version` reads `v0.9.2` and the commit is scoped `contract(interaction-contract)`
- conforms to every contract section cited in §3 and §4, and to every invariant listed in §1
