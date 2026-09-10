# Epic 01 · Task 02b: L0-9 successor semantics — non-resident `next_courses[]` targets are legal

---
epic: 01
task: 02b
slug: l0-9-successor-semantics
kind: fix
risk: seam
depends_on: [01.2]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: correct the landed L0-9 implementation so that a `next_courses[]` entry naming a course **not resident in
the bundle** is legal data rather than a violation, keeping the cycle check exactly as it is; re-derive task
01.2's `valid/` fixture from `contracts/examples/` with no deviation; and add the regression guard that would
have caught the defect — `L0Checker.validate` reports `passed: true` over the repo's own
`contracts/examples/` directory.

Why this task exists: `Packages/Core/Sources/Core/Validation/L0Checker.swift:268` records an L0-9 violation for
every `next` target absent from `bundle.courses.courses`. Under that reading
`contracts/examples/courses.json:36-38,68-70` — the normative worked example of the same signed-off contract
set, whose two courses declare `next_courses` `["MPM2D"]` and `["MHF4U"]`, neither resident — fails its own
contract. A contract's worked example must satisfy that contract, so the implemented reading of
`contracts/graph-constraints.md:21` ("names existing courses") is the wrong one. Task 01.2 has landed, so the
correction ships here; task 01.2's spec is amended in place (amendment 01.02.1) to state the corrected rule,
and this task brings the code and fixtures into line with it.

**No contract text changes and no decision D1–D49 changes.** `contracts/graph-constraints.md` stands as
written; D47 is being conformed to, not amended. This task must not edit anything under `contracts/`.

Invariants in play:

- **I1** — the rule stays a deterministic structural check in Swift; no model decides anything.
- **I2** — `L0Checker` remains a pure Tier-0 mechanism with no model call and no network.
- **I6** — `violations` entries remain ids (course codes) only; no Ministry prose enters the report.
- **I8** — L0-9 is one of the L0 checks every accepted graph must pass; this task narrows it to the obligation
  ground truth actually imposes, and does not weaken the cycle clause.
- **I14** — every touched source file stays under `Packages/Core/`, imports `Foundation` only, and the existing
  recursive import-boundary test is unchanged. L0 continues to exist exactly once, in `Core`.

Acceptance criteria (each independently verifiable):

- AC1: `L0Checker.validate(bundleDir:)` over the repo's `contracts/examples/` directory, read unmodified,
  returns an `L0Report` with `passed == true`, `checks.count == 10`, and every `checks[i].violations == []`.
  Asserted on `passed` itself, not merely on the set of `checks[].id`.
- AC2: `checkCourseSuccession` records **no** violation for a `next_courses[]` entry naming a course absent
  from `bundle.courses.courses`. A bundle whose only unusual property is a non-resident successor reports
  `L0-9 passed: true`.
- AC3: the cycle clause is unchanged in behaviour: the `l0-9-next-courses-cycle/` fixture, whose two resident
  courses point at each other, still reports `L0-9 passed: false` with the cycle's course codes in
  `violations`, and `L0Checker.errorCode(forRuleId: "L0-9") == .graphL0Failed`.
- AC4: `Packages/Core/Tests/CoreTests/Fixtures/l0/valid/` is byte-identical to the seven bundle files of
  `contracts/examples/` (`manifest`, `regions`, `nodes`, `edges`, `courses`, `landmarks`, `sources`), with the
  `next_courses: []` deviation removed. Verifiable by diff; every other `Fixtures/l0/*` directory that copies
  `valid/`'s unmutated files is updated to match, so the "everything else byte-identical to `valid/`" property
  task 01.2 §4.5 states still holds.
- AC5: every case in task 01.2's §5 that existed before this task still passes — in particular T1 over
  `valid/` still reports `passed: true` with all ten checks green, now with the non-resident successors
  present in the fixture rather than blanked.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Core/Sources/Core/Validation/L0Checker.swift` — MODIFY. Delete the unknown-target violation loop in
  `checkCourseSuccession` (the `for next in coursesByCode[code]?.nextCourses ?? [] where coursesByCode[next] ==
  nil { violations.append(next) }` block at `:267-271`). Nothing else in the file changes.
- `Packages/Core/Tests/CoreTests/Fixtures/l0/**` — MODIFY. Restore `valid/courses.json`'s `next_courses` to the
  `contracts/examples/` values and propagate the restored file to every fixture directory that carries an
  unmutated copy of it; re-base `l0-9-next-courses-cycle/courses.json`'s mutation on the restored file.
- `Packages/Core/Tests/CoreTests/L0CheckerTests.swift` — MODIFY. Add the AC1 regression guard (task 01.2 §5
  T1b) and the AC2 assertion; update the L0-9 mutation case's expectations to AC3.

Out-of-scope (do not touch even if tempted):

- `contracts/**` — read-only ground truth. The contract text stands; this task changes the implementation that
  misread it. The regression guard **reads** `contracts/examples/` and writes nothing there.
- `Packages/Core/Sources/Core/Validation/L0Report.swift`, `GraphIndex.swift` — unchanged; the report shape and
  the index are correct as landed.
- Every other `checkL0_*` function inside `L0Checker.swift` — this task changes L0-9 only. Do not "tidy"
  adjacent rules (RULE 3).
- `Packages/Core/Sources/CoreCLI/**`, `Packages/Core/Package.swift`, `data/demo/**`, `pipeline/**`,
  `App/Sources/**`, `Packages/Rendering/**` — other tasks' files.
- The cycle DFS at `L0Checker.swift:277-303` — already correct. Its `guard coursesByCode[next] != nil else {
  continue }` at `:283` already terminates the walk on a non-resident target, so deleting the violation loop
  needs no compensating change anywhere in the traversal. Verify this by reading the function before editing;
  do not restructure it.

## §3 Inputs (verbatim — do not paraphrase)

- `contracts/graph-constraints.md:21` — the rule as written (unchanged by this task):
  > | L0-9 | Every course's `next_courses[]` names existing courses and contains no cycle. |
  > `GRAPH_L0_FAILED{L0-9}` | D47 succession is data |

- `contracts/schemas/courses.schema.json:142-145` — the machine-checkable constraint on a `next_courses[]`
  entry; note the absence of any residency requirement:
  > ```json
  > "items": {
  >   "type": "string",
  >   "pattern": "^[A-Z]{3}[1-4][A-Z]$"
  > }
  > ```

- `contracts/examples/courses.json:36-38` and `:68-70` — the normative worked example:
  > ```json
  >       "next_courses": [
  >         "MPM2D"
  >       ]
  > ```
  > ```json
  >       "next_courses": [
  >         "MHF4U"
  >       ]
  > ```

- `AMENDMENT-v2.7.md:25` (D47):
  > preferring the next course in the same stream per the Ministry's course-prerequisite chart (e.g. MPM2D →
  > MCR3U → MHF4U → MCV4U) [SOURCED: Ontario secondary mathematics prerequisite chart in the 2007 curriculum
  > document] … Course succession is data in the spine (`next_courses[]` per course), not logic.

- `docs/domains/expedition.md:112-114` (W8):
  > 2. If the marker is past the last unit of its course, extend from the course's terminal nodes along
  > downstream edges into the first `next_courses[]` entry whose nodes exist, then the next, then undergraduate
  > nodes; mark the segment `extension`.

- `Packages/Core/Sources/Core/Validation/L0Checker.swift:261-271` — the code to change (verbatim, as landed):
  ```swift
  private static func checkCourseSuccession(_ bundle: ContentBundle) -> L0Check {
      var violations: [String] = []
      let coursesByCode = Dictionary(
          uniqueKeysWithValues: bundle.courses.courses.map { ($0.courseCode, $0) })
      let sortedCodes = coursesByCode.keys.sorted()

      for code in sortedCodes {
          for next in coursesByCode[code]?.nextCourses ?? [] where coursesByCode[next] == nil {
              violations.append(next)
          }
      }
  ```

- `tasks/epic-01-task-02-l0-checker.md` heading `### 4.3 Packages/Core/Sources/Core/Validation/L0Checker.swift`
  — the corrected L0-9 clause and its four-part justification (amendment 01.02.1) is the binding requirement
  this task implements.

Test framework: Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`) — not XCTest, per
`Packages/Core/Tests/CoreTests/CoreTests.swift`.

## §4 Implementation outline

1. Read `checkCourseSuccession` in full. Confirm by reading — not by assuming — that the cycle DFS skips
   non-resident targets at `:283` (`guard coursesByCode[next] != nil else { continue }`). If it does not, stop
   and report: the scope of this task assumes it does.
2. Delete the unknown-target loop (`:267-271`). `violations` is then written only by the cycle branch. Leave
   `sortedCodes` in place — the DFS iterates it for determinism.
3. Restore `Fixtures/l0/valid/courses.json` from `contracts/examples/courses.json` byte-for-byte, and copy the
   restored file into every fixture directory whose `courses.json` is meant to be an unmutated copy of
   `valid/`'s. The fixture directories whose mutation *is* in `courses.json` (`l0-3a-uncovered-expectation/`,
   `l0-8-empty-unit/`, `l0-9-next-courses-cycle/`) are re-derived by re-applying their single documented
   mutation to the restored file, per task 01.2 §4.5's table.
4. Re-base the `l0-9-next-courses-cycle/` mutation: `MTH1W.next_courses` `["MPM2D"]` → `["MCR3U"]` and
   `MCR3U.next_courses` `["MHF4U"]` → `["MTH1W"]`, producing a 2-cycle between two resident courses.
5. Add the regression guard to `L0CheckerTests.swift`: resolve `contracts/examples/` from `#filePath` by the
   same walk `DecodeRoundTripTests` already uses to reach the repo root, call `validate(bundleDir:)` on it, and
   assert `passed == true` and every `violations == []`. Do not copy `contracts/examples/` into the test bundle
   — the guard is only load-bearing if it reads the live contract directory.
6. Smoke check: `( cd Packages/Core && swift build -c release --product core-cli )`.

## §5 Test plan (risk: seam — full plan)

- T1 happy path: `validate(bundleDir: .../Fixtures/l0/valid)` still returns `passed == true` with ten checks,
  every `violations == []` — now with `next_courses` `["MPM2D"]` / `["MHF4U"]` present in the fixture (AC4, AC5).
- T1b contract-example guard: `validate(bundleDir: <repo>/contracts/examples)` returns `passed == true` with
  every `violations == []` (AC1). Assert `passed` explicitly. Task 01.4's existing seam test asserts only the
  ten check **ids** over the same directory (`tasks/epic-01-task-04-core-cli-and-pipeline-seam.md` heading
  `## §5 Test plan`, its T1) — an id-only assertion is exactly what let this defect survive, so this case must
  assert the verdict, not the shape.
- T2 negative — invalid input rejected at the boundary: `l0-9-next-courses-cycle/` reports `L0-9 passed ==
  false` with non-empty `violations` naming the cycle's course codes, and the eleven other mutation fixtures
  report exactly the failures task 01.2 §5 T2 already fixes (AC3, AC5). A behaviour change in any rule other
  than L0-9 is a FAIL of this task.
- T3 error-taxonomy: `L0Checker.errorCode(forRuleId: "L0-9") == .graphL0Failed`, unchanged (AC3).
- T4 conformance: the corrected rule is checked against the four ground-truth citations in §3 — the schema's
  pattern-only item constraint, the worked example, D47's "data … not logic", and expedition W8's "whose nodes
  exist". This line records the mapping for the wrap-gate ledger; no separate test.
- T5 negative control for the regression guard — **both directions, proved by mutation and recorded in the PR
  description**:
  - re-add the deleted unknown-target loop in a scratch edit: T1 and T1b must both red. If they stay green the
    guard is vacuous and the task is not done.
  - delete the cycle branch in a scratch edit: T2's L0-9 case must red. If it stays green the cycle clause is
    no longer enforced and the fix has over-reached.
  Revert both scratch edits; neither ships.
- T6 idempotency / no-leak: `validate(bundle:)` remains pure — call it twice on the decoded `valid/` bundle and
  assert the two `L0Report` values are `Equatable`-equal. The run over `contracts/examples/` leaves that
  directory unmodified (assert the files' contents are unchanged after the call, or simply confirm the code
  path is read-only by inspection — `validate` never writes).

## §6 Decision defaults

- IF the implementer is tempted to keep a weakened residency check (for example, warning instead of failing)
  THEN do not: `L0Report`/`L0Check` have no warning channel (`{id, passed, violations}` only, fixed by
  `contracts/graph-constraints.md` § Report shape), and inventing one would change the contract's report shape.
  L0-4's advisory data lives in the separate `indegree` block precisely because the report has no third state.
- IF the implementer is tempted to validate that a `next_courses[]` code is well-formed (matches
  `^[A-Z]{3}[1-4][A-Z]$`) inside `Core` THEN do not: that is the schema's obligation, already enforced by
  `pipeline/tests/test_contracts.py::test_data_bundles_validate` per `contracts/data-model.md` § Enforcement.
  Duplicating it in `Core` adds a second source for one rule (RULE 2, I14's single-source principle).
- IF `contracts/examples/` cannot be resolved from the test's `#filePath` walk THEN stop and report rather than
  copying the example files into the test bundle: a guard that reads a copy cannot detect drift between the
  contract's example and the checker, which is the whole point of AC1.
- IF restoring `valid/` makes some other fixture's expectation change THEN that is a signal the fixture was
  built on the blanked `next_courses`, not on `contracts/examples/`; re-derive it per task 01.2 §4.5's table
  rather than adjusting the assertion to fit.
- Standing defaults: identifiers are stable lowercase kebab-case slugs, never parsed for meaning
  (`contracts/data-model.md` § Identifiers); no telemetry field is touched; no model call exists anywhere in
  this task's code (I2); no identifying field is added anywhere (I5).

## §7 Done definition

The task is done when ALL gates pass:

- `xcrun swift-format lint --strict --recursive --configuration .swift-format Packages App/Sources` — clean.
- `Core` build + test green: `( cd Packages/Core && swift build -c release --product core-cli )` and
  `( cd Packages/Core && xcodebuild test -quiet -scheme Core-Package -destination "$SIM"
  CODE_SIGNING_ALLOWED=NO )` (`scripts/gate.sh` gate 3).
- All cases in §5 (T1, T1b, T2–T6) pass, with T5's two mutation proofs recorded in the PR description.
- `diff -r` between `Packages/Core/Tests/CoreTests/Fixtures/l0/valid/` and the seven bundle files of
  `contracts/examples/` reports no difference (AC4).
- `contracts/**` is untouched: `git diff --name-only` names no path under `contracts/`.
- Conforms to every contract section cited in §3 and to every invariant listed in §1 (I1, I2, I6, I8, I14).
- `scripts/gate.sh` gates 1 and 3 green in full.
