# Task 03.1 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: contract-interaction-marker-unit-list
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 03
- Task: 1
- Slug: contract-interaction-marker-unit-list
- Summary: Contract task to finalize interaction-contract v0.9.1 → v0.9.2 by resolving arbiter Q-B (marker set only from unit list, no drag gesture); lands the map.md W5 edit and its error row, and a DEFERRED entry for drag, per the arbiter ruling in `tasks/arbitration/arbiter-03-predispatch.md` § Q-B.
- Invariants in play: I1, I2, I3, I5, I6, I8, I14, I15 (applied through contract and domain rules below).

## §B. Applicable contract rules (verbatim)

### contracts/interaction-contract.md — version line

> **Contract version:** v0.9.1 (discovery zone — finalized just-in-time by the Demo EPIC) · Source: brief v2
> §7, D23, D27, D44–D48, v2.7 §3; `map.md`, `expedition.md`, `diagnosis.md`; v0.9.1 adds the numeric
> normalisation rule (expedition Q4), the `remediated(p)` predicate and its two ripples (arbiter Q-A,
> `tasks/arbitration/arbiter-02-predispatch.md`), the `past_last_unit` marker text (arbiter Q-F), and the
> probe "available" definition (arbiter Q-G)

Source: `contracts/interaction-contract.md:3–7`

Binds this task: this is the current version this task bumps to v0.9.2; the ruling appears in arbiter-03-predispatch.md Q-B.

### contracts/interaction-contract.md — § 3 Marker and trail

> ## 3. Marker and trail (D45, D47)
>
> - `set_marker(course, unit)` → regenerate trail → recompute fringe. Marker default = first unit of the
>   selected course. Nodes upstream of the marker keep their mastery.
>   The marker is past the course's last unit iff `marker.past_last_unit == true`, whichever unit `unit_id`
>   names; setting it writes the course's last unit as `unit_id`. While past the last unit, the
>   `marker.unit ∪ next(marker.unit)` window of §2 `compose` is the nodes of the `extension` segment (empty
>   when there is none). Nodes of the course are then upstream of the marker. A marker whose `course_code` is
>   not in `syllabi[]`, or whose `unit_id` is not a unit of that course in the bundle, is off the trail
>   (`MAP_MARKER_OFF_TRAIL`, default marker) regardless of `past_last_unit`.
> - `generate_trail`: course segments in unit order; if the marker is past the course's last unit, an
>   `extension` segment along downstream edges preferring `next_courses[]`, then undergraduate nodes; every
>   segment a path (L0-T) else `EXP_TRAIL_INVALID` and the previous trail stands.

Source: `contracts/interaction-contract.md:62–74`

Binds this task: § 3 behavior stands unchanged; the arbiter ruling appends a bullet to this section per Q-B exact text.

### contracts/interaction-contract.md — § Finalization owed by the Demo EPIC

> ## Finalization owed by the Demo EPIC
> The unit-boundary snap for dragging the marker; the timing of the answer card; whether the summary shows
> region tint deltas. Bump to v1.0.0 on wrap.

Source: `contracts/interaction-contract.md:117–119`

Binds this task: this section is replaced by the arbiter ruling (Q-B exact normative text, lines 109–111 of arbiter-03-predispatch.md).

### contracts/README.md — § Lock-first rule

> ## Lock-first rule
>
> `data-model`, `graph-constraints`, `content-policy`, `telemetry`, `domain-glossary`, `runtime-tiers` and
> `deployment-model` **lock before any dependent EPIC starts** — retrofitting them corrupts shipped data, the
> graph, or the compliance position. Discovery-zone contracts stay open and are finalized just-in-time. A
> change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every conforming
> EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

Source: `contracts/README.md:38–44`

Binds this task: `interaction-contract` is discovery-zone, so this task's version bump to v0.9.2 is a finalize-just-in-time change with commit scope `contract(interaction-contract)`.

### contracts/README.md — enforcement ladder, interaction-contract row

> | [`interaction-contract.md`](interaction-contract.md) | discovery — finalize just-in-time (Demo EPIC) | runtime contract test: state-machine property tests in `CoreTests` (EPIC-time) | the three doors as state machines: expedition, diagnosis, marker/trail |

Source: `contracts/README.md:19`

Binds this task: the contract change (v0.9.2) is enforced by runtime property tests in `CoreTests`, authored later in EPIC 03 (task 03.7 onwards). This task lands the contract text only.

---

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/map.md — § W5 — Set the course-progress marker (current text to be changed)

> ### W5 — Set the course-progress marker
> **Pre:** a course trail segment is selected. **Steps:** 1. Show the course's **unit list** (curriculum-spine
> `Unit`s, D45) with the current one highlighted; the student picks "we are here in class". Dragging the
> marker along the trail is the same action: it snaps to the nearest unit boundary, else
> `MAP_MARKER_OFF_TRAIL` and stays. 2. Hand the unit id to **expedition** (`map.marker_moved`), which owns the
> change, regenerates the trail (D47 — past the last unit the trail extends, drawn dashed) and recomputes the
> fringe (D45/D48). 3. Re-derive fog: nodes upstream of the marker are fog with an "upstream of your class"
> note, never cleared. **Post:** marker persisted by expedition; `map.marker_moved` emitted (a D40 event).

Source: `docs/domains/map.md:88–95`

Current state to replace per arbiter ruling Q-B (arbiter-03-predispatch.md lines 114–116).

### docs/domains/map.md — § Errors produced, row `MAP_MARKER_OFF_TRAIL` (current text to be changed)

> | `MAP_MARKER_OFF_TRAIL` | Marker dropped outside a unit boundary of the selected course | Marker snaps back | Yes |

Source: `docs/domains/map.md:126`

Current state to replace per arbiter ruling Q-B (arbiter-03-predispatch.md lines 117–120).

---

## §D. Prior task outputs this task depends on

None — no prior outputs consumed. This is a contract-first task (interaction-contract v0.9.1 is the input; v0.9.2 is the output for downstream EPIC 03 tasks to conform to).

---

## §E. Negative facts (confirmed ABSENT)

- No prior `docs/domains/map.md` W5 step text includes "past the last unit" entry definition — confirmed by the section read (lines 88–95), which describes drag without the unit-list entry mechanism. Source: `docs/domains/map.md:88–95` read 2026-09-10.
- No existing DEFERRED entry for marker drag — confirmed by the full `docs/DEFERRED.md` read (entries D-1 … D-13, lines 1–147); D-13 is the last entry. Source: Grep query `"Marker drag"` returned 0 hits in `docs/DEFERRED.md`.
- No version-bump precedent for interaction-contract shown in the contract file itself — the header cites prior arbiter rulings (Q-F, Q-G from EPIC 02), confirming this is a discovery-zone contract. Source: `contracts/interaction-contract.md:1–7` read 2026-09-10.

---

## §F. File scope

Files this task creates or modifies:

- MODIFY `contracts/interaction-contract.md:1–3` — header and version line; append a Source line; update § 3 and replace § Finalization owed per arbiter Q-B ruling.
- MODIFY `docs/domains/map.md:88–95` — replace W5 step 1 per arbiter Q-B ruling (lines 114–116 of arbiter-03-predispatch.md).
- MODIFY `docs/domains/map.md:126` — replace error row `MAP_MARKER_OFF_TRAIL` "When" and "User sees" columns per arbiter Q-B ruling (lines 117–120 of arbiter-03-predispatch.md).
- MODIFY `docs/DEFERRED.md` — append one new entry (D-14, following C6 template) for marker drag with unit-boundary snap, per arbiter Q-B ruling (lines 121–122 of arbiter-03-predispatch.md).

---

## §G. Stack constraints relevant here

- **Contract versioning:** interaction-contract is discovery-zone; this task's v0.9.1 → v0.9.2 bump records the resolution of one finalization item (marker drag → no drag in Demo). Source: `contracts/README.md:38–44` (lock-first rule; discovery-zone applies).
- **Exact normative text for contract header append:** `; v0.9.2 resolves the marker-drag finalization item (arbiter Q-B, \`tasks/arbitration/arbiter-03-predispatch.md\`)`. Source: `tasks/arbitration/arbiter-03-predispatch.md:102–104`, lines 102–104 exact text.
- **Exact normative text for § 3 append:** new bullet to § 3 Marker and trail: 
  > - The marker is set only by choosing an entry from the selected course's unit list: one entry per unit in
  >   unit order, then a final "past the last unit" entry (`past_last_unit: true`). No gesture moves the marker;
  >   there is no drag and no snap.  A unit-list choice is never off the trail.
  
  Source: `tasks/arbitration/arbiter-03-predispatch.md:106–108` (arbiter Q-B exact normative text).
- **Exact normative text for § Finalization owed replacement:**
  > The timing of the answer card; whether the summary shows region tint deltas. Bump to v1.0.0 on wrap.
  > (Resolved in v0.9.2: the marker is set from the unit list only — § 3; no drag.)
  
  Source: `tasks/arbitration/arbiter-03-predispatch.md:109–111` (arbiter Q-B exact normative text).
- **Exact normative text for map.md W5 step 1 replacement:** "The marker is set from this list only; there is no drag (interaction-contract v0.9.2 § 3)." Source: `tasks/arbitration/arbiter-03-predispatch.md:114–116` (arbiter Q-B cascade).
- **Exact normative text for map.md error row:** "When" becomes "A stored marker names a course not in `syllabi[]` or a unit absent from the bundle (load, expedition W7)"; "User sees" becomes "Nothing on the load path — the map opens at the default marker (arbiter-03 Q-A)". Source: `tasks/arbitration/arbiter-03-predispatch.md:117–120` (arbiter Q-B cascade).
- **Exact DEFERRED entry name:** "Marker drag with unit-boundary snap", following C6 template. Revisit trigger: "Demo observations (`DEMO-BRIEF.md` § 7 Acceptance)". Hypothesis: "none". Source: `tasks/arbitration/arbiter-03-predispatch.md:121–122` (arbiter Q-B cascade).
- **Related decisions locked:** D45 (course-progress marker from unit list, AMENDMENT-v2.6.md line 23); D47 (trail extension rule, AMENDMENT-v2.7.md lines 23–25, with `next_courses[]` preference per [SOURCED: Ontario secondary mathematics prerequisite chart in the 2007 curriculum document]). These are ground truth; this task records their resolution in the contract only.

---

## Quote audit report

All blocks re-read and byte-verified 2026-09-10:
- `contracts/interaction-contract.md:3–7` (version line) — ✓ exact match
- `contracts/interaction-contract.md:62–74` (§ 3 Marker and trail) — ✓ exact match
- `contracts/interaction-contract.md:117–119` (§ Finalization owed) — ✓ exact match
- `contracts/README.md:38–44` (lock-first rule) — ✓ exact match
- `contracts/README.md:19` (enforcement ladder row) — ✓ exact match
- `docs/domains/map.md:88–95` (W5) — ✓ exact match
- `docs/domains/map.md:126` (error row) — ✓ exact match
- `tasks/arbitration/arbiter-03-predispatch.md:102–104` (v0.9.2 header append) — ✓ exact match
- `tasks/arbitration/arbiter-03-predispatch.md:106–108` (§ 3 append) — ✓ exact match
- `tasks/arbitration/arbiter-03-predispatch.md:109–111` (§ Finalization replacement) — ✓ exact match
- `tasks/arbitration/arbiter-03-predispatch.md:114–116` (W5 step 1 replacement) — ✓ exact match
- `tasks/arbitration/arbiter-03-predispatch.md:117–120` (error row changes) — ✓ exact match
- `tasks/arbitration/arbiter-03-predispatch.md:121–122` (DEFERRED entry spec) — ✓ exact match

All citations verified. No blocks corrected. Bundle complete.
