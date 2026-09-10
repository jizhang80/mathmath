# Epic 02 · Task 05b: `MarkerTrail.setMarker` writes the course's last unit when `pastLastUnit == true`

---
epic: 02
task: 05b
slug: fix-set-marker-past-last-unit
kind: fix
risk: seam
depends_on: [02.5]
model: sonnet
---

> **Origin.** Q4 arbitration `tasks/arbitration/arbiter-03-07-past-last-unit.md`. Task 02.5 (landed in EPIC
> 02a) quoted the binding rule in its own §3 but its §4 outline built the `Marker` straight from the caller's
> `unitId`, and none of its acceptance criteria exercised `setMarker(…, pastLastUnit: true)`. The rule is
> therefore enforced nowhere in `Core`. This task lands the one-line correction **once, in `Core`**
> (`CLAUDE.md`: "Anything the pipeline and the app must agree on is implemented once, in `Core`"), so every
> caller (task 03.7's `MapFacade.setMarker`, EPIC 04's App) is correct by construction.
>
> **Branch.** Runs on `epic-02b-door-a-core-merge`, after task 02.11's commits and before the 02b wrap
> (02.13). Its file scope is disjoint from 02.11 (`Diagnosis/*`) and 02.12 (`State/StateMerge*`), both of
> which list `MarkerTrailGeneration.swift` as out-of-scope. Commit subject:
> `fix(core): setMarker writes the course's last unit when past_last_unit is true`.
>
> **R-7 classification (for the 02b acceptance report's `fix:`-commit table):** cause `logic`; corrects task
> 02.5, risk tier `seam`. Rework, not new output. The contract was unambiguous at the time 02.5 was written (it
> quotes the sentence verbatim at its §3), so the cause is not `contract-gap`. The defect is a code path
> that does not implement a stated rule.

## §1 Goal & acceptance criteria

Goal: when `MarkerTrail.setMarker` is called with `pastLastUnit: true`, the returned `SetMarkerResult.marker`
has `unitId` equal to the **last unit** (`units.last`) of the named course in the bundle, whatever `unitId`
the caller passed. With `pastLastUnit: false`, the behaviour is unchanged. Trail generation, warnings and
events are unchanged in every case.

Invariants in play:

- **I2**: no model call. Tier 0 only.
- **I5**: no field is added. `Marker` keeps `{courseCode, unitId, pastLastUnit}`.
- **I7**: the last unit comes from the bundle's own `courses[].units[]` order. No course is special-cased.
- **I8**: `generateTrail` is not edited. Its trail output does not depend on `marker.unitId` (it reads only
  `marker.courseCode` and `marker.pastLastUnit`, `MarkerTrailGeneration.swift:69-74`), so the L0-T result is
  unchanged.
- **I14**: `MarkerTrailGeneration.swift` still imports only Foundation. `setMarker` stays a pure value
  transformation.

Acceptance criteria (instrument: Swift Testing `#expect` in the new test file, run by `xcodebuild test
-scheme Core-Package` on the simulator; each excludes physical-device behaviour):

- AC1 (the fix, MTH1W): `MarkerTrail.setMarker(courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: true,
  syllabi: ["MTH1W"], bundle: <real data/demo>)` returns `.marker == Marker(courseCode: "MTH1W", unitId:
  "MTH1W.u4", pastLastUnit: true)`. The test first asserts, from the loaded bundle, that the MTH1W course's
  `units.last?.unitId == "MTH1W.u4"` and that `"MTH1W.u4" != "MTH1W.u2"`. This precondition keeps the
  assertion from being vacuous (empty=FAIL: a missing MTH1W course fails the test).
- AC2 (the fix, MCR3U): the same call with `courseCode: "MCR3U", unitId: "MCR3U.u1", pastLastUnit: true,
  syllabi: ["MCR3U"]` returns `.marker.unitId == "MCR3U.u3"` and `.marker.pastLastUnit == true`. The same
  precondition applies: MCR3U's `units.last?.unitId == "MCR3U.u3"`.
- AC3 (idempotent on the last unit): `setMarker(courseCode: "MTH1W", unitId: "MTH1W.u4", pastLastUnit: true,
  …)` returns `.marker == Marker(courseCode: "MTH1W", unitId: "MTH1W.u4", pastLastUnit: true)`.
- AC4 (negative control, the flag gates the substitution): `setMarker(courseCode: "MTH1W", unitId:
  "MTH1W.u2", pastLastUnit: false, …)` returns `.marker == Marker(courseCode: "MTH1W", unitId: "MTH1W.u2",
  pastLastUnit: false)`. An implementation that always substituted the last unit fails this test.
- AC5 (trail, warnings and events unchanged):
  - On real `data/demo`, AC1's result has `.trail == MarkerTrail.generateTrail(syllabi: ["MTH1W"], marker:
    Marker(courseCode: "MTH1W", unitId: "MTH1W.u2", pastLastUnit: true), bundle:).trail`. Its `.warnings` are
    equal to that report's `.warnings`. Its `.events == [.expeditionMarkerChanged, .expeditionTrailGenerated]`.
  - On the `Fixtures/trail/extension-positive` bundle, `setMarker(courseCode: "MTH1W", unitId: "MTH1W.u2",
    pastLastUnit: true, syllabi: ["MTH1W"], bundle:)` returns `.marker.unitId == "MTH1W.u4"`. Its `.trail`
    equals `generateTrail` over the same bundle with `Marker(courseCode: "MTH1W", unitId: "MTH1W.u2",
    pastLastUnit: true)`, and its last segment has `kind == .extension` and `courseCode == "MPM2D"`. This
    checks that the extension is still built.
- AC6 (seam: set, then relaunch reconciliation): for AC1's result,
  `MarkerTrail.reconcileMarker(result.marker, syllabi: ["MTH1W"], bundle:)` returns `.code == nil` and
  `.marker == result.marker`. The persisted form is on the trail, per interaction-contract § 3: "must still
  name a unit of the course" (data-model).
- AC7 (unresolvable course, no new throw): `setMarker(courseCode: "ZZZ9Z", unitId: "ZZZ9Z.u1",
  pastLastUnit: true, syllabi: ["MTH1W"], bundle: <real data/demo>)` does not throw and returns
  `.marker == Marker(courseCode: "ZZZ9Z", unitId: "ZZZ9Z.u1", pastLastUnit: true)`. The caller's `unitId` is
  kept (§6). W7's `reconcileMarker` classifies this marker as off-trail when it loads (existing 02.5 behaviour,
  not re-tested here).
- AC8 (error taxonomy unchanged): `setMarker(courseCode: "TST1X", unitId: "TST1X.u1", pastLastUnit: true,
  syllabi: ["TST1X"], bundle: <Fixtures/trail/unit-cycle>)` throws exactly `CoreError.expTrailInvalid`, whose
  `rawValue == "EXP_TRAIL_INVALID"`.
- AC9 (existing suites unmodified and green): `MarkerTrailGenerationTests`, `MarkerTrailFringeSeamTests`,
  `StateMergeTests` and `StateMergeBoundaryTests` pass without editing any of their files (§5 lists why).

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/State/MarkerTrailGeneration.swift`: MODIFY `MarkerTrail.setMarker` only
  (body plus its doc comment, currently lines 87–99). No other function, type or helper changes.
- `Packages/Core/Tests/CoreTests/MarkerTrailSetMarkerPastLastUnitTests.swift`: CREATE. AC1–AC8.

Out-of-scope (do not touch):

- `Packages/Core/Tests/CoreTests/MarkerTrailGenerationTests.swift` and `MarkerTrailFringeSeamTests.swift`
  (02.5's and 02.6's files). Neither asserts the old behaviour (§5, "Existing tests checked").
- `Packages/Core/Sources/Core/State/Expedition.swift`: `scopeWindow` already reads `marker.pastLastUnit`
  first (`Expedition.swift:166-168`), so the window does not depend on `unitId` while past the last unit.
- `Packages/Core/Sources/Core/Diagnosis/**` and `State/StateMerge*.swift`: 02.11's and 02.12's files.
- `Packages/Core/Sources/Core/Model/**`, `CoreError.swift`, `Events/CoreEvent.swift`: no new type, case or
  field.
- `contracts/**`, `docs/**`, `data/demo/**`, and fixtures: read-only. This task needs no contract change. It
  conforms code to an existing contract sentence.

## §3 Inputs (verbatim — do not paraphrase)

- `contracts/interaction-contract.md`, heading `## 3. Marker and trail (D45, D47)` (v0.9.1, lines 64–71):
  > - `set_marker(course, unit)` → regenerate trail → recompute fringe. Marker default = first unit of the
  >   selected course. Nodes upstream of the marker keep their mastery.
  >   The marker is past the course's last unit iff `marker.past_last_unit == true`, whichever unit `unit_id`
  >   names; setting it writes the course's last unit as `unit_id`. While past the last unit, the
  >   `marker.unit ∪ next(marker.unit)` window of §2 `compose` is the nodes of the `extension` segment (empty
  >   when there is none). Nodes of the course are then upstream of the marker. A marker whose `course_code` is
  >   not in `syllabi[]`, or whose `unit_id` is not a unit of that course in the bundle, is off the trail
  >   (`MAP_MARKER_OFF_TRAIL`, default marker) regardless of `past_last_unit`.

- `contracts/data-model.md`, heading `### StudentState (student-state.schema.json)` (lines 139–141):
  > `past_last_unit` (boolean, optional; absent = false): `true` means the marker has been moved past the
  > course's last unit (v2.7 §4). `unit_id` then names the course's last unit at the time it was set and must
  > still name a unit of the course.

- `docs/domains/expedition.md`, heading `### W6 — Set the course-progress marker` (lines 105–108):
  > **Pre:** `map.marker_moved` with a unit of the selected course. **Steps:** set the marker; regenerate the
  > Trail (W8); recompute the Fringe; nodes newly upstream keep whatever mastery they had (a cleared node stays
  > cleared). **Post:** persisted; `expedition.marker_changed` emitted → map, telemetry (D40).

- `AMENDMENT-v2.7.md`, heading `## 4. D47 — trail extension rule.` (line 25, first sentence):
  > When the course-progress marker is moved past the course's last unit, the trail extends from the course's
  > terminal nodes along downstream prerequisite edges, preferring the next course in the same stream per the
  > Ministry's course-prerequisite chart …

- The code being corrected, `Packages/Core/Sources/Core/State/MarkerTrailGeneration.swift:87-99` (as landed):
  ```swift
  /// W6. Builds the new `Marker` from the given course/unit/`pastLastUnit`, then calls
  /// `generateTrail(syllabi:marker:bundle:)` with it. Throws (and returns nothing) if trail generation
  /// throws — per §6's decision default, the caller's previously-held marker AND trail both stay
  /// untouched on failure (this function does not partially apply the marker change).
  public static func setMarker(
      courseCode: String, unitId: String, pastLastUnit: Bool, syllabi: [String], bundle: ContentBundle
  ) throws -> SetMarkerResult {
      let marker = Marker(courseCode: courseCode, unitId: unitId, pastLastUnit: pastLastUnit)
      let report = try generateTrail(syllabi: syllabi, marker: marker, bundle: bundle)
      return SetMarkerResult(
          marker: marker, trail: report.trail, warnings: report.warnings,
          events: [.expeditionMarkerChanged, .expeditionTrailGenerated])
  }
  ```

- The existing course lookup pattern in the same file, `defaultMarker` (`MarkerTrailGeneration.swift:103-111`):
  ```swift
  guard let course = bundle.courses.courses.first(where: { $0.courseCode == courseCode }),
      let firstUnit = course.units.first
  else { continue }
  return Marker(courseCode: courseCode, unitId: firstUnit.unitId, pastLastUnit: false)
  ```

- Fixture facts, re-read in this run: in `data/demo/courses.json`, MTH1W's `units[]` are `MTH1W.u1…u4` in
  order (lines 99, 108, 116, 125) and MCR3U's `units[]` are `MCR3U.u1…u3` (lines 223, 232, 242).
  `Packages/Core/Tests/CoreTests/Fixtures/trail/extension-positive/courses.json` lists MTH1W units `u1…u4`
  (line 125 is `MTH1W.u4`).
- Test framework: Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`, `#expect(throws:)`),
  with `@testable import Core`. Locate fixtures the same way `MarkerTrailGenerationTests.swift:14-34` does
  (a `#filePath`-relative `testsDir`, `data/demo` via four `deletingLastPathComponent()`, and
  `BundleIO.read(from:)`).

## §4 Implementation outline

Replace lines 87–99 of `MarkerTrailGeneration.swift` with:

```swift
    /// W6. Builds the new `Marker` from the given course/unit/`pastLastUnit`, then calls
    /// `generateTrail(syllabi:marker:bundle:)` with it. When `pastLastUnit` is `true`, the marker's
    /// `unitId` is the course's last unit in `bundle` whatever `unitId` the caller passed
    /// (`contracts/interaction-contract.md` § 3: "setting it writes the course's last unit as
    /// `unit_id`"); if the course is absent from `bundle` or has no units, the caller's `unitId` is kept
    /// and W7's `reconcileMarker` classifies the marker. Throws (and returns nothing) if trail generation
    /// throws — the caller's previously-held marker AND trail both stay untouched on failure (this
    /// function does not partially apply the marker change).
    public static func setMarker(
        courseCode: String, unitId: String, pastLastUnit: Bool, syllabi: [String], bundle: ContentBundle
    ) throws -> SetMarkerResult {
        var resolvedUnitId = unitId
        if pastLastUnit,
            let lastUnit = bundle.courses.courses.first(where: { $0.courseCode == courseCode })?.units.last
        {
            resolvedUnitId = lastUnit.unitId
        }
        let marker = Marker(courseCode: courseCode, unitId: resolvedUnitId, pastLastUnit: pastLastUnit)
        let report = try generateTrail(syllabi: syllabi, marker: marker, bundle: bundle)
        return SetMarkerResult(
            marker: marker, trail: report.trail, warnings: report.warnings,
            events: [.expeditionMarkerChanged, .expeditionTrailGenerated])
    }
```

- Boundary validation: `courseCode` and `unitId` are looked up without force-unwrapping. No new throw path.
- Error codes: only the existing `CoreError.expTrailInvalid`, propagated from `generateTrail`.
- Model-calling paths: none.
- Smoke check: `( cd Packages/Core && swift build -c release --product core-cli )` is green.

## §5 Test plan (risk: seam — full plan)

All tests go in `MarkerTrailSetMarkerPastLastUnitTests.swift`, `@Suite("MarkerTrail.setMarker past the last
unit (interaction-contract § 3)")`.

- **T1 happy path:** AC1 (MTH1W u2 → u4), AC2 (MCR3U u1 → u3), AC3 (last unit stays the last unit).
- **T2 negative:**
  - AC4: with `pastLastUnit: false`, `unitId` passes through.
  - AC7: an unresolvable course keeps the caller's `unitId`, with no throw.
- **T3 error taxonomy:** AC8 (`EXP_TRAIL_INVALID` still propagates when `pastLastUnit: true`).
- **T4 conformance (B.1, interaction-contract § 3 and data-model § StudentState):** AC6 checks that the set
  marker reconciles on the trail (`code == nil`). AC5 checks that the `generateTrail` output is unchanged,
  including the extension segment on the `extension-positive` fixture.
- **Real composition (seam):** AC6 composes the real `setMarker` with the real `reconcileMarker`, which is
  the set → persist → relaunch path task 03.7 relies on. AC5's fixture case composes the real `setMarker` with
  the real `generateTrail` extension builder. Nothing is stubbed.
- **T5 negative control for the regression guard:** AC4 is the control for AC1–AC3, and it fails an
  "always substitute" implementation. AC1's and AC2's preconditions (`units.last != passed unitId`) fail the
  test if the fixture ever made the AC vacuous. Without the fix, AC1 fails on the landed code (the returned
  `unitId` is `"MTH1W.u2"`), which shows the guard is load-bearing.
- **T6 idempotency:** two AC1 calls over two freshly loaded bundles return `==` `SetMarkerResult`s.

**Existing tests checked (none asserts the old behaviour; none is edited):**

- `MarkerTrailGenerationTests.swift:87-97` (AC3) and `:315-321` (T6) call `setMarker` only with
  `pastLastUnit: false`. Unaffected.
- `MarkerTrailFringeSeamTests.swift:34-36` calls `setMarker` with `pastLastUnit: false`. Unaffected.
- `MarkerTrailGenerationTests.swift:102`, `:129` and `:297` build `Marker(…, "MTH1W.u4", pastLastUnit: true)`
  directly for `generateTrail`, not through `setMarker`. `MTH1W.u4` is already the last unit. Unaffected.
- `MarkerTrailGenerationNegativeControlTests.swift:194`, `StateMergeBoundaryTests.swift:98`, and
  `StateMergeTests.swift:184,194` construct `Marker` values directly and never call `setMarker`. Unaffected.
  (`StateMergeTests.swift:194`'s `MTH1W.u1` with `pastLastUnit: true` is a merge-ranking input, which
  data-model § StudentState merge ranks by the flag first. It is not a `setMarker` output.)

## §6 Decision defaults

- IF `courseCode` does not resolve in `bundle`, or resolves to a course with an empty `units[]`, while
  `pastLastUnit == true`, THEN keep the caller's `unitId` and do not throw. The contract names no
  `set_marker` error for this case, and it already defines what happens to such a marker: "off the trail
  (`MAP_MARKER_OFF_TRAIL`, default marker) regardless of `past_last_unit`" (interaction-contract § 3), which
  02.5's `reconcileMarker` implements at load. No new error code is invented.
- IF `pastLastUnit == false`, THEN `Marker.pastLastUnit` is stored as `false` (not `nil`), as before. This
  task changes only `unitId`.
- IF a reviewer asks to add these cases to 02.5's `MarkerTrailGenerationTests.swift`, THEN they go in a new
  file instead. That keeps the fix commit surgical and leaves the landed suite byte-unchanged (AC9).

## §7 Done definition

- format + lint clean: `xcrun swift-format lint --strict --recursive --configuration .swift-format Packages
  App/Sources`.
- `Core` build and tests green: `( cd Packages/Core && swift build -c release --product core-cli )`, and
  `( cd Packages/Core && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO )`
  (`scripts/gate.sh:16-18`). This includes AC1–AC8 and every existing suite listed in AC9.
- `coreImportBoundary()` and `ErrorRegistryTests` stay green, unmodified.
- `scripts/gate.sh` is green in full.
- One commit, subject `fix(core): setMarker writes the course's last unit when past_last_unit is true`.
- Conforms to `contracts/interaction-contract.md` § 3 and `contracts/data-model.md` § StudentState
  (`past_last_unit` paragraph).
