# Arbiter rulings — EPIC 03 pre-dispatch (Q4)

**Date:** 2026-09-10
**Brief:** `docs/epics/epic-03-app-map-shell.md` § 9 Open questions
**Trigger:** pre-dispatch Q4 routing by the brief itself (Q-A, Q-B, Q-C, Q-F); the technical defaults Q-D, Q-E,
Q-G and Q-H were submitted for confirmation.
**Result:** no ESCALATE-Q5. No locked decision D1–D49 and no invariant changes meaning. Two contract artefacts
are owed: `interaction-contract.md` v0.9.2 (Q-B) and one additive `error-codes.json` entry (Q-C). Three brief
defaults are **corrected**: Q-E (a fresh state cannot exist before a course is chosen), Q-G (CI does not run
`scripts/gate.sh`, and the smoke as the brief words it cannot produce a state file) and Q-A (the second
`reconcileMarker` branch).

## Summary table

| Q | Ruling | Lands in (brief § 8 numbering) |
|---|---|---|
| Q-A | **Option (a), CONFIRMED with a precision.** On the load path no text is shown, and the student-message decision is made in `Core`, not the App. The registered text's own path (dragging) is **not reachable in the Demo**. No registry change. | 3 (reconciliation outcome), 6 (App displays nothing) |
| Q-B | **CONFIRMED.** Unit list only, no drag. A contract change **is** needed, because the finalization item lives in the contract. It is a patch bump to v0.9.2. Exact text below. A `docs/domains/map.md` W5 edit and a DEFERRED entry go with it. | 1 |
| Q-C | **New code, CONFIRMED.** `PLATFORM_SNAPSHOT_REFUSED`, student surface, exact registry entry and domain row below. Reuse and a non-registry screen are both rejected. | 1 (registration), 2 (`CoreError` case + launch mapping), 6 (screen) |
| Q-D | **CONFIRMED.** The Include queue is held in memory only, by the `Core` façade. Precision: a fogged node that is neither on the fringe nor upstream offers no action. | 5 |
| Q-E | **CORRECTED.** No `StudentState` exists before the first course selection. The schema and the Swift type both require `marker`. So launch with no file yields a "course selection needed" outcome, and selecting a course creates the first state. Brief § 4 AC 3's first bullet is re-worded below. | 2/3 (launch outcome), 5 (selection façade), 6 (picker as first screen) |
| Q-F | **CONFIRMED, consistent with I14 and D33.** Precise boundary below. No App test target is needed. Not a Q5. | 2, 3, 4, 5 (Core); 6–8 (App) |
| Q-G | **CORRECTED.** `xcrun simctl` is allowed. CI inlines its steps and never calls `scripts/gate.sh`, so the smoke must be added to **both** `scripts/gate.sh` gate 4 and `.github/workflows/ci.yml`. The App writes nothing until a course is chosen, so the smoke **seeds** a version-1 state file rather than waiting for one to appear. | 6 |
| Q-H | **CONFIRMED.** No hash verification of the embedded snapshot in EPIC 03. The wrap records the missing EPIC 01 deferral as a new DEFERRED entry. | wrap |

---

## Q-A — `MAP_MARKER_OFF_TRAIL` on the load path (DEFERRED D-12)

**Ruling.** Option (a), with three precisions.

1. **No student text on the W7 load path.** The map opens at the default marker. `Core`'s launch outcome
   carries the reconciliation code as internal diagnostics. The list of messages the App must display is
   computed **in `Core`** and is empty for this code on this path. The App shows what `Core` hands it and never
   branches on a code itself (I14: "the render layer never computes state").
2. **The second `reconcileMarker` branch.** When no course in `syllabi[]` resolves in the bundle,
   `reconcileMarker` returns the **unchanged** stored marker with `.mapMarkerOffTrail`. So there is no default
   marker to open the map on. The launch outcome is then "course selection needed" (Q-E), with no student text
   either. The brief does not mention this branch.
3. **No write on load.** Reconciliation changes the in-memory state only. The file keeps its stored marker until
   the next state-changing action writes the whole document. This matches expedition W7's rule that the state
   is loaded, not rewritten, and the brief's "writes … after every state-changing action".

**Is the registered text's "original path" reachable in the Demo?** **No.** The registered path is the drag
path: the map error row is "Marker dropped outside a unit boundary of the selected course | Marker snaps back",
and W5 says a drag "snaps to the nearest unit boundary, else `MAP_MARKER_OFF_TRAIL` and stays". Under Q-B no
drag exists. The unit-list picker can only produce (course in `syllabi[]`, unit of that course in the bundle,
optionally `past_last_unit`), which is never off-trail under interaction-contract § 3. The course picker (Q-E)
sets `syllabi` and the default marker together, so it cannot produce an off-trail marker either. Consequence: in
the Demo, `MAP_MARKER_OFF_TRAIL`'s `user_text` is **never shown**. The code remains registered, unchanged, for
the drag path should that ever be built (see Q-B's DEFERRED entry).

**Registry change:** none. Option (b), a dedicated "marker was reset" code, is rejected for now: the load path is
reachable in the Demo only if `data/demo` unit ids change between builds on one install. The revisit trigger
stays EPIC 10 (content refresh can change unit ids).

**Test obligation (task 3).** Over a state whose marker names `MCR3U.u9`, which is absent from `data/demo`:
- the outcome's marker equals `defaultMarker`;
- mastery is byte-equal to the input;
- the student-message list is **empty**;
- the internal diagnostics contain `MAP_MARKER_OFF_TRAIL`.

Negative control: the same state with a valid unit produces no code. The unresolvable-course variant (syllabi
`["MHF4U"]`, absent from `data/demo`) yields "course selection needed".

**Citations.**
- `contracts/error-codes.json`, code `MAP_MARKER_OFF_TRAIL`: `"surface": "student"`, `"user_text": "The marker
  stays where it was; pick a unit from the list."` (line 11).
- `contracts/interaction-contract.md` § 3 Marker and trail: "A marker whose `course_code` is not in `syllabi[]`,
  or whose `unit_id` is not a unit of that course in the bundle, is off the trail (`MAP_MARKER_OFF_TRAIL`,
  default marker) regardless of `past_last_unit`."
- `contracts/error-codes.md` § Rules: "Internal codes never reach a student surface; a `student` code always has a
  next action in its text." Nothing in the rules requires every raised `student` code to be displayed.
- `docs/domains/map.md` § W5 and § Errors produced (row `MAP_MARKER_OFF_TRAIL`).
- `docs/domains/expedition.md` § W7 — Resume after relaunch.
- `tasks/arbitration/arbiter-02-predispatch.md` § Q-D (caveat owed to EPIC 03).
- `docs/DEFERRED.md` § D-12.
- Subordinate note: `reconcileMarker` in `Packages/Core/Sources/Core/State/MarkerTrailGeneration.swift` (lines
  113–128); both branches were read.

**Wrap action.** Close D-12 in `docs/DEFERRED.md` citing this ruling. Its revisit trigger moves to "EPIC 10: a
content refresh can change unit ids".

---

## Q-B — Marker from the unit list only (finalization item 1)

**Ruling.** CONFIRMED. The Demo sets the marker only from the unit list, with "past the last unit" as the final
entry. No drag gesture is built. D45 names the unit list as the mechanism ("The student marks "we are here" from
the course's unit list"). Drag appears only in `docs/domains/map.md` § W5, which describes it as "the same action".
Dropping it changes no D-number. Not a Q5.

**Is a contract change actually needed?** **Yes.** Interaction-contract § "Finalization owed by the Demo EPIC"
lists "The unit-boundary snap for dragging the marker" as owed, and that list is contract text. Closing the item
means editing the contract, and that is a versioned change. § 3's behaviour is unchanged: `set_marker(course,
unit)` already takes a unit, never a position. So the change is a **patch** bump (v0.9.1 → v0.9.2), which records
the resolution. Leaving the item open until EPIC 04's v1.0.0 would leave EPIC 03 shipping against an unresolved
contract item.

**Exact normative text** (applied by task 1, a `contract(interaction-contract)` commit):

1. Header line: `**Contract version:** v0.9.2 (discovery zone — finalized just-in-time by the Demo EPIC)`, and
   append to the Source sentence: `; v0.9.2 resolves the marker-drag finalization item (arbiter Q-B,
   \`tasks/arbitration/arbiter-03-predispatch.md\`)`.
2. § 3 Marker and trail — append a bullet:
   > - The marker is set only by choosing an entry from the selected course's unit list: one entry per unit in
   >   unit order, then a final "past the last unit" entry (`past_last_unit: true`). No gesture moves the marker;
   >   there is no drag and no snap. A unit-list choice is never off the trail.
3. § Finalization owed by the Demo EPIC — replace the paragraph with:
   > The timing of the answer card; whether the summary shows region tint deltas. Bump to v1.0.0 on wrap.
   > (Resolved in v0.9.2: the marker is set from the unit list only — § 3; no drag.)

**Cascade (same task, `docs/*` edits authorized for a contract task):**
- `docs/domains/map.md` § W5 step 1: replace "Dragging the marker along the trail is the same action: it snaps
  to the nearest unit boundary, else `MAP_MARKER_OFF_TRAIL` and stays." with "The marker is set from this list
  only; there is no drag (interaction-contract v0.9.2 § 3)."
- `docs/domains/map.md` § Errors produced, row `MAP_MARKER_OFF_TRAIL`: "When" becomes "A stored marker names a
  course not in `syllabi[]` or a unit absent from the bundle (load, expedition W7)", and "User sees" becomes
  "Nothing on the load path — the map opens at the default marker (arbiter-03 Q-A)". The registry entry is
  unchanged. The code string stays in the doc, so `test_error_registry_matches_domain_docs` remains green.
- Add a `docs/DEFERRED.md` entry "Marker drag with unit-boundary snap", following the C6 template. Revisit
  trigger: Demo observations (`DEMO-BRIEF.md` § 7 Acceptance). Hypothesis: none.

**Citations.**
- `contracts/interaction-contract.md` § 3 Marker and trail and § Finalization owed by the Demo EPIC.
- `AMENDMENT-v2.6.md`, D45 (line 23) and § DEMO-BRIEF deltas "§3.3: … chosen from a short unit list" (line 38).
- `docs/domains/map.md` § W5.

---

## Q-C — The embedded snapshot itself is refused

**Ruling.** Register **one new additive code**. The two alternatives are rejected:
- **Reuse** `PLATFORM_BUNDLE_INTEGRITY_FAILED` → rejected. Its text, "still using the installed version", is
  false here. Changing that text would be a versioned change to a code whose W1/W2 path makes it true again at
  EPIC 10.
- **A fixed non-registry screen** → rejected. It invents a student-facing error surface outside the registry
  (RULE 5: "Never invent a pattern a contract already defines").

Platform § W1 covers "a failure falls back to the snapshot" but has **no row** for the snapshot itself failing.
The new code fills exactly that gap.

**Exact registry entry** (`contracts/error-codes.json`, `codes[]`, placed after `PLATFORM_BUNDLE_INTEGRITY_FAILED`):

```json
{"code": "PLATFORM_SNAPSHOT_REFUSED", "recoverable": false, "surface": "student", "user_text": "The map could not be loaded from this copy of the app; reinstall the app to fix it."},
```

The entry follows each registry rule:
- The prefix `PLATFORM` is already in the registry's fixed prefix set.
- `surface = student` ⇔ `user_text` non-null, which the test at `test_contracts.py` line 151 asserts.
- The text names a situation, not the student, carries no score, and gives a next action ("reinstall the app").
- `recoverable: false`, because nothing inside the running build recovers; the remedy is a new build or a
  reinstall.
- No version bump is needed (error-codes.md header: "Additive registration (a new code with its domain doc row)
  is allowed without a version bump").

**Exact domain row** (`docs/domains/platform.md` § Errors produced, after `PLATFORM_BUNDLE_INTEGRITY_FAILED`):

```
| `PLATFORM_SNAPSHOT_REFUSED` | The offline snapshot shipped in the build fails a load-time check (manifest completeness, format major, L0) and no other set is installed | "The map could not be loaded from this copy of the app; reinstall the app to fix it." No map is rendered | No — needs a new build |
```

Also amend platform § W1 step 1 by appending: "If the snapshot itself fails, `PLATFORM_SNAPSHOT_REFUSED` and no
map is rendered."

**Code shape.**
- `CoreError` gains `case platformSnapshotRefused = "PLATFORM_SNAPSHOT_REFUSED"`. This is additive, and the EPIC
  01 precedent is `platformBundleIntegrityFailed`.
- The existing `ErrorRegistryTests` ⊆-registry check covers the new case with no change.
- The `Core` launch entry point raises this code whenever the snapshot is the only set and is refused. It carries
  the underlying code (`PLATFORM_BUNDLE_INTEGRITY_FAILED`, `GRAPH_L0_FAILED` with rule ids, or a `MAP_*`
  validation code) as internal detail, and the internal detail is never shown.
- Brief § 4 AC 2 then asserts **both**: the student-surface code `PLATFORM_SNAPSHOT_REFUSED`, and the underlying
  internal code the brief lists for each corruption.

**Ordering constraint.** The registry entry, the platform row and the `CoreError` case are coupled.
`test_error_registry_matches_domain_docs` fails if the registry and the domain docs disagree, and
`ErrorRegistryTests` fails if the Swift case precedes the registry entry. So the registry entry and the platform
row land in **task 1**, the same contract task as Q-B (a separate `contract(error-codes)` commit), before task 2
adds the `CoreError` case. With this, the § 8 count stays at 8 and no 03a/03b split is forced by Q-C.

**Reachability** (brief's claim, verified as true). In a gated build the path is unreachable, because brief § 4
AC 9 validates the embedded bytes byte-identical to `data/demo`. The code exists so the fail-closed screen has
honest text.

**Citations.**
- `contracts/error-codes.md` § Rules and header note.
- `contracts/error-codes.json`, `PLATFORM_BUNDLE_INTEGRITY_FAILED` (line 49).
- `docs/domains/platform.md` § W1 — Launch and § Errors produced.
- `pipeline/tests/test_contracts.py` `test_error_registry_matches_domain_docs` (lines 143–159).
- `Packages/Core/Sources/Core/CoreError.swift`.

---

## Q-D — The Include queue

**Ruling.** CONFIRMED. The queue is one in-memory node id held by the `Core` façade value (Q-F), passed to the
next `Expedition.compose(queuedNodeId:)` and not persisted. `StudentState` has a closed key set with no queue
field, so persisting it would be a data-model BUMP.

Precisions for task 5:
- A later Include **replaces** the queued id; map Q5 allows "one node".
- The id is consumed by the next `compose` call whether or not it was still on the fringe; `compose` already
  ignores an off-fringe queued id.
- An Include on a node upstream of the marker returns a typed "ignored, upstream of the marker" outcome with **no
  student text** and no new code, because it is unreachable from the panel (map W2 step 2 offers "Check me here"
  there).
- **Gap in the brief, closed here:** map W2 names three action cases. A fogged node that is neither on the fringe
  nor upstream of the marker (downstream, beyond the current and next unit) matches none of them, so it **offers
  no action**. Its panel still shows "under fog". Brief § 4 AC 6 gains that case.

**Citations.**
- `contracts/data-model.md` § StudentState (key list) and the rule "Every object schema sets
  `additionalProperties: false` — a new field is a versioned change".
- `contracts/schemas/student-state.schema.json` top-level `additionalProperties: false` (line 224).
- `contracts/interaction-contract.md` § 2 Expedition: "map-queued node first (map Q5, if on the fringe)".
- `docs/domains/map.md` § W2 and § Open questions Q5.
- Subordinate note: `Expedition.compose` in `Packages/Core/Sources/Core/State/Expedition.swift` (lines 41, 56).

---

## Q-E — Course selection on a fresh install

**Ruling.** CORRECTED. The brief's picker default stands, but its premise, "a fresh state has no `syllabi[]`",
does not describe a state that can exist. `marker` is a **required** key with required `course_code` and
`unit_id`, both pattern-constrained, and the Swift type declares it non-optional. So **no valid `StudentState`
can be built before a course is chosen.** The fix:

- **Launch outcome.** The `Core` launch entry returns one of three outcomes:
  - `ready(bundle, state, viewModel, messages)`;
  - `courseSelectionNeeded(bundle, messages)`, when there is no state file, the file is unreadable
    (`PLATFORM_STATE_UNREADABLE` in `messages`, file kept byte-for-byte), or no stored course resolves (Q-A
    precision 2);
  - `refused(code)`, the Q-C path.
- **First state.** The course picker is the first screen for `courseSelectionNeeded`. Choosing a course calls
  a `Core` façade function that builds the first state and persists it, then derives the view model:
  - `schema_version` 2 and `format_version_seen` = the bundle's `format_version`;
  - `syllabi = [course]` and `marker = defaultMarker(syllabi:bundle:)`;
  - `trail` from `generateTrail`, `nodes` empty (every node `fog`), both logs empty;
  - `install_day` = injected today, and `consent_on = true` (I5: telemetry "on by default").
- **Changing course later.** The same picker calls the same façade, replacing `syllabi` and the marker together
  (never an off-trail result, Q-A). Mastery is kept.
- **Re-worded brief § 4 AC 3, first bullet:** "No file → `courseSelectionNeeded`; no file is written. Choosing a
  course yields a state with `schema_version` 2, `install_day` = the injected today, `syllabi` = [course], the
  default marker, every node absent (`fog`), and it is persisted."
- **Also affected:** AC 3's "unreadable → a fresh state is used" bullet. The "fresh state" is reached through
  the picker. platform W3's "a fresh state is used" is honoured once the student picks a course. This is the
  only way to build a schema-valid fresh state, so it is a spec realisation, not a Q5.
- Multi-syllabus selection is not built (D47 allows it, and the shape needs no change).

**Citations.**
- `contracts/schemas/student-state.schema.json`: top-level `required` includes `"marker"` (line 216); `marker`
  `required: ["course_code", "unit_id"]` (lines 37–40).
- `Packages/Core/Sources/Core/Model/StudentState.swift:14` (`public let marker: Marker`).
- `contracts/data-model.md` § StudentState.
- `AMENDMENT-v2.6.md` § DEMO-BRIEF deltas: "§3.1: initial camera on the tester's selected course trail (MTH1W
  or MCR3U)" (line 37).
- `docs/domains/platform.md` § W3.
- `CLAUDE.md` I5.

---

## Q-F — Test home: platform code in `Core`

**Ruling.** CONFIRMED. The brief's option 1 is consistent with I14 and D33. The owner needs to do nothing, and no
Q5 arises.

**Why it is consistent.**
- D33 / I14 restrict `Core` to **imports** (Foundation only) and forbid **rendering**. File IO is neither:
  `FileManager`, `Data.write(to:options: .atomic)` and `FileManager.replaceItemAt` are Foundation. `BundleIO`
  already reads files in `Core` today.
- The platform domain's own I14 clause asks for exactly this separation: it "reads and writes `StudentState` as
  an opaque `Codable` value from `Core` … defines no state shape and no transition".
- `docs/tech-stack.md` § 2 lists "persistence/sync/bundle loading (platform)" under `App/Sources`. But that line
  opens with "Ownership by domain (a spec's §2 file scope is authoritative)", so a spec that places the
  Foundation-only parts in `Core` does not contradict it.
- The map domain requires the view model in `Core` ("`MapViewModel` derivation lives in `Core`").

**The boundary, precisely.**

`Core` holds (all Foundation-only, value-typed, and testable in `CoreTests` against temp directories):
1. **The launch entry point.** Input: a caller-supplied snapshot directory URL, state-file URL and `today`.
   Steps: `BundleIO.read` → format-major check → L0 `validate` → state read, migrate and reconcile → the Q-E
   outcome.
2. **The persistence store.**
   - Encode and decode through `CoreCoding`; the 1 → 2 identity migration.
   - Atomic whole-document write to a caller-supplied URL.
   - Keep the pre-migration file until the migrated one is written.
   - Preserve an unreadable file byte-for-byte.
   - Errors: `PLATFORM_STATE_UNREADABLE` and `PLATFORM_STATE_WRITE_FAILED` join `CoreError` additively.
3. **`MapViewModel`: plain structs.** `Equatable`, `Sendable`, with fields of `Double`, `String`, `Bool`, ids
   and enums only.
   - Positions, the focus frame and label thresholds are in **bundle coordinate space** or as a plain zoom
     scale `Double`. The label set for a zoom level is a `Core` function of that scale (map Q4).
   - No `CGFloat`, `CGPoint`, `Color`, `Path`, font, `@Observable` / `Observation`, `Combine`, or any
     screen-pixel quantity.
4. **The façade.** Each entry point takes values and returns (new value, `[CoreEvent]`) or throws a
   `CoreError`.
   - The persist-after-every-state-changing-action sequencing lives here too: a `Core` session type whose
     actions write to the injected URL. That way a missed write is caught by a `CoreTests` test, not left in
     untestable App code.
   - The list of student messages to display (Q-A, Q-C, Q-E) is computed here, as registry codes.

`App/Sources` holds only what needs SwiftUI/UIKit or the OS environment:
- views, `Canvas` drawing, and mapping bundle coordinates to screen through the ephemeral pan/zoom transform;
- gesture handling and sheet-presentation flags;
- one `@Observable` holder that stores the current `Core` session value and **replaces** it with each façade
  result, never deriving from it;
- resolving the Application Support URL and the embedded-snapshot URL, and reading the device calendar into a
  `CalendarDay` (via its public `init?(iso:)`);
- handing a `source_url` / `official_url` to the system, and showing a `student` code's registered `user_text`.

The App must not construct a `StudentState`, call `MarkerTrail`, `Expedition`, `MasteryTransitions` or L0
directly, branch on a `CoreError` to decide visibility, or read `data/`. The brief's new `App/Sources` source
scan (§ 3 I14 line) enforces this, with a planted negative control.

**Embedding the snapshot** (for the planner, task 2). The App target is a file-system-synchronized group, and the
pbxproj is never edited. So the only agent-available way to embed `data/demo` is a **copy under `App/Sources`**
that the synchronized group picks up as resources. The brief's byte-identity test (a `CoreTests` test comparing
that copy with `data/demo`, empty set = FAIL) is therefore mandatory, not optional. The spec must name the copy's
path and state that a regenerating script, not a hand edit, keeps it in sync.

**Citations.**
- `CLAUDE.md` I14.
- `docs/tech-stack.md` § 1 (row "App project": "Agents add files under `App/Sources` and `Packages/Core`
  **without editing the pbxproj**"; row "Persistence": "state types in `Core`") and § 2 (ownership line).
- `docs/domains/platform.md` § Invariants enforced here (I14).
- `docs/domains/map.md` § Core entities (`MapViewModel`) and § Invariants enforced here (I14).

---

## Q-G — Simulator smoke in the gate

**Ruling.** CORRECTED, in two points. The rest is confirmed.

- **Tool: allowed.** `xcrun simctl` is part of the pinned Xcode 26.6 toolchain and is already used by the gate
  through `scripts/pick-simulator.sh`. The smoke validates the state file with `jsonschema`, already a locked
  pipeline dev dependency (`pipeline/pyproject.toml` line 21) used by `test_contracts.py`, invoked as
  `uv run --project pipeline python …`. No new tool is introduced.
- **Correction 1: CI does not run `gate.sh`.** `.github/workflows/ci.yml` inlines each step, and its `swift` job
  ends at the App build with no `uv` setup. "Invoked from gate 4 … so CI runs it" is therefore false. Task 6
  must:
  - add the smoke to `scripts/gate.sh` gate 4, after the App build;
  - add an `astral-sh/setup-uv@v6` step (`version: "0.12.12"`, the same pin as the `python` job) plus a smoke
    step after "App build on the simulator" in the `swift` job of `ci.yml`.

  `docs/tech-stack.md` § 3 requires "CI runs the same steps". `.github/workflows/ci.yml` joins task 6's § 2 file
  scope with the one-line role "CI mirror of gate 4's smoke step".
- **Correction 2: the smoke's assertions.** Under Q-E the App writes no state until a course is tapped, and
  `simctl` cannot tap. So "the state file appears" cannot be observed without a test hook in shipping code, and a
  launch-argument hook is **not** permitted. The smoke instead runs two scenarios:
  1. **Fresh install.** Install, launch, and assert the process is alive after a settle interval. Assert **no**
     state file exists in the container's Application Support: nothing is written before a course is chosen.
  2. **Seeded relaunch.**
     - Terminate the App and seed a version-1 state file into the container's Application Support. The seed is
       a copy of `contracts/examples/student-state.json` with `schema_version` set to 1 and every `remediated`
       key removed, which makes it a valid v1 document (data-model: "a version-1 document is a valid version-2
       document with every `remediated` absent").
     - Launch and assert: the process is alive; the file now has `schema_version` 2 and validates against
       `student-state.schema.json`; and no pre-migration file remains once the migrated one is written.
     - Terminate and relaunch, then assert the process is alive and the file is byte-identical to the one
       before relaunch. Launch writes nothing, per Q-A precision 3.

  The seed's unknown node ids (`matrix-multiplication`) also exercise W7's "kept in the file but ignored".
  Every assertion names its instrument (`simctl get_app_container ca.mathmath.app data`, `pgrep`/`simctl
  spawn … launchctl list`, the jsonschema validator). Empty checks are FAIL: a missing container or a missing
  file fails the smoke.
- **Where to write the seed.** The migrated file lives where the App resolves it. The App's state-file location
  (a fixed file name under Application Support) is therefore a named constant in the task 6 spec, shared by the
  App and the smoke.
- **Revisit trigger** unchanged: CI simulator-boot flakes. Fallback: the wrap's runbook command, with no weakened
  assertion.
- **D-13.** Adding `scripts/` and `ci.yml` changes counts as D-13's trigger, "the next tooling … change". Task 6
  first **re-measures** `App/mathmath.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/`, records the
  measurement in DEFERRED D-13 at wrap, and **never stages** that directory. Any ignore rule is a separate
  owner-visible change and is not part of task 6.

**Citations.**
- `docs/tech-stack.md` § 1 and § 3 Gates.
- `scripts/gate.sh` (gate 4 at lines 21–23); `scripts/pick-simulator.sh` (line 7, `xcrun simctl list`).
- `.github/workflows/ci.yml` (`swift` job, lines 13–37).
- `contracts/data-model.md` § StudentState (migration sentence).
- `docs/DEFERRED.md` § D-13.
- The bundle id `ca.mathmath.app` was read, not edited, from `App/mathmath.xcodeproj/project.pbxproj` (lines
  217, 245).

---

## Q-H — Snapshot `sha256` verification

**Ruling.** CONFIRMED. EPIC 03 enforces manifest completeness, the format major and L0 at load, and does not
verify hashes on the embedded snapshot. The reasons:
- `docs/domains/platform.md` § AssetVersion says the hash is "checked on fetch".
- W1's "verify hashes; a failure falls back to the snapshot" applies to an installed hosted set. The snapshot is
  the fallback and ships inside the signed build.
- Every `sha256` in `data/demo/manifest.json` is the all-zero placeholder, so there is nothing to verify.
- A hash check in `Core` would need CryptoKit, which D33 forbids.

**Wrap action.** Add the missing EPIC 01 deferral as the next `docs/DEFERRED.md` entry, in the C6 template:
- **Observed:** `docs/plans/epic-01-task-plan.md` planner note 2 deferred "hash *verification at load*" to EPIC
  03. EPIC 03 ruled it belongs to hosted-bundle fetch (this ruling). The `data/demo` manifest hashes are all-zero
  placeholders.
- **Configuration:** Demo, where the embedded snapshot is the only bundle and there is no network.
- **Revisit trigger:** EPIC 10 hosted bundles (platform W2).
- **Hypothesis (unverified):** none.

**Citations.**
- `docs/domains/platform.md` § Core entities (AssetVersion) and § W1.
- `docs/plans/epic-01-task-plan.md` note 2 (lines 40–44).
- `data/demo/manifest.json` (the `sha256` fields, lines 24–49).
- `docs/DEFERRED.md` (entries D-1 … D-13; no hash entry).

---

## Consequences for the planner

1. **Task 1** carries two contract commits: `interaction-contract.md` v0.9.2, plus the `map.md` W5/error-row
   edits and the drag DEFERRED entry (Q-B); and the `error-codes.json` `PLATFORM_SNAPSHOT_REFUSED` entry plus
   its `platform.md` row and W1 sentence (Q-C). Both are additive. The count stays at 8.
2. **Brief § 4 edits** to carry into the task specs:
   - AC 2 asserts `PLATFORM_SNAPSHOT_REFUSED` plus the underlying internal code.
   - AC 3's first bullet is re-worded (Q-E).
   - AC 4: no student message, and no write on load (Q-A).
   - AC 6 gains the "fogged, off-fringe, not upstream → no action" case (Q-D).
   - The artifact line's smoke assertions follow Q-G, correction 2.
3. **Task 6** file scope adds `.github/workflows/ci.yml` (Q-G).
4. **Dependencies unchanged.** `DiagnosisRun.open` / `DiagnosisTrigger.mapCheckHere` are **absent** from
   `Packages/Core/Sources` today (grep: 0 hits for `DiagnosisRun`). EPIC 02b must be wrapped first, as the brief
   says.
