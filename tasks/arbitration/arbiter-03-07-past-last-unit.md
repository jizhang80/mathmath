# Arbitration: task 03.7, marker past the last unit (Q4)

**Date:** 2026-09-10
**Trigger:** `task-writer` ↔ `task-reviewer` did not converge on
`tasks/epic-03-task-07-map-actions-facade-launch.md` (2 BLOCK cycles).
**Outputs:** the new task `tasks/epic-02-task-05b-fix-set-marker-past-last-unit.md` and a rewritten 03.7 spec.

## Findings

| # | Claim | Verification | Classification |
|---|---|---|---|
| 1 | The contract requires `set_marker` with `past_last_unit` to write the course's last unit as `unit_id`. | `contracts/interaction-contract.md:66-67` (§ 3 Marker and trail, v0.9.1): "The marker is past the course's last unit iff `marker.past_last_unit == true`, whichever unit `unit_id` names; setting it writes the course's last unit as `unit_id`." `contracts/data-model.md:139-141`: "`unit_id` then names the course's last unit at the time it was set and must still name a unit of the course." | VALID |
| 2 | The landed `MarkerTrail.setMarker` does not enforce it. | `Packages/Core/Sources/Core/State/MarkerTrailGeneration.swift:94`: `let marker = Marker(courseCode: courseCode, unitId: unitId, pastLastUnit: pastLastUnit)`. There is no lookup of `units.last`. The only other `MarkerTrail.setMarker` reference in `Sources` is a doc comment (`Expedition.swift:31`). | VALID |
| 3 | The 03.7 Source line claiming "as `MarkerTrail.setMarker` already does" is false. | It is contradicted by #2. It was an orchestrator edit, and it is withdrawn. | VALID |
| 4 | 03.7 AC8 does not assert `unit_id == last unit`, and §4.4 passes `unitId` through. | The prior 03.7 AC8 only asserted `pastLastUnit == true`. §4.4 calls `MarkerTrail.setMarker(… unitId: unitId …)`. | VALID. Resolved by the fix task plus the rewritten AC8. §4.4's pass-through is kept by design. |
| 5 | Did 02.5 require the rule? | `tasks/epic-02-task-05-marker-trail-reconciliation.md:181-182` quotes the sentence verbatim as binding (future v0.9.1 text). Its §4 outline at `:752-760` builds the marker from `unitId`. Its AC3 (`:88-92`) exercises only `pastLastUnit: false`. No 02.5 AC or test covers `setMarker(…, pastLastUnit: true)`. | The spec was internally inconsistent (quoted the rule, did not implement it). The cause is a code defect, not a contract gap. |

## Ruling

**(a) Where the rule lives:** in `MarkerTrail.setMarker`, as the single source. The reasons:

- `CLAUDE.md`: "Anything the pipeline and the app must agree on is implemented **once, in `Core`**".
- `docs/domains/map.md` § W5 step 2: "Hand the unit id to **expedition** … which owns the change".
- `docs/domains/expedition.md` § W6 ("set the marker") puts the marker write in expedition's function.

If callers computed it instead, the rule would be duplicated across 03.7, EPIC 04 and any future caller. No
reason to prefer that was found. The alternative is rejected.

**(b) Fix task:** `tasks/epic-02-task-05b-fix-set-marker-past-last-unit.md`. It is named after the task it
corrects (02.5), not 02.11, which is the unrelated diagnosis machine.

- It lands on `epic-02b-door-a-core-merge` after 02.11 and before the 02b wrap (02.13).
- File scope: `MarkerTrailGeneration.swift` (the `setMarker` body only) plus a new
  `MarkerTrailSetMarkerPastLastUnitTests.swift`. This is disjoint from 02.11 and 02.12, both of which mark
  that file out of scope.
- Risk tier: seam. Commit subject: `fix(core): setMarker writes the course's last unit when past_last_unit is true`.
- If the course is not in the bundle, the caller's `unitId` is kept and no new error is thrown. W7's
  off-trail rule covers that marker, so no new error code is invented.

**Existing tests checked, none needs updating:**

- `MarkerTrailGenerationTests.swift:87-97,315-321` and `MarkerTrailFringeSeamTests.swift:34-36` call
  `setMarker` only with `pastLastUnit: false`.
- `MarkerTrailGenerationTests.swift:102,129,297`, `MarkerTrailGenerationNegativeControlTests.swift:194`,
  `StateMergeTests.swift:184,194` and `StateMergeBoundaryTests.swift:98` construct `Marker` directly and never
  call `setMarker`.
- `generateTrail`'s output does not read `marker.unitId` (`MarkerTrailGeneration.swift:69-74`), and neither
  does `compose`'s past-last-unit window (`Expedition.swift:166-168`). So trail and fringe behaviour are
  unchanged.

**R-7 classification** for the 02b acceptance report's `fix:` table:

| Commit | Cause | Corrects task | Risk tier | Kind |
|---|---|---|---|---|
| `fix(core): setMarker writes the course's last unit when past_last_unit is true` | `logic` | 02.5 | `seam` | rework |

It is not `contract-gap`: the contract text existed and was quoted in 02.5's own spec.

**(c) 03.7 rewrite:** these sections changed:

- **Front matter:** `depends_on` gains `02.5b`.
- **Branch note:** a new "Past-last-unit precondition" paragraph. It tells the implementer to BLOCK if 02.5b
  has not landed, and never to add a local workaround.
- **§1:** the I14 bullet notes that the rule is not re-implemented here. AC8 is rewritten with an in-course
  move, a past-the-last-unit case from a non-last unit (`MTH1W.u2` → persisted `MTH1W.u4`, asserted on the
  returned `MapState`, on the re-read file and on relaunch), a negative control and a non-vacuity
  precondition.
- **§2:** a note that the `MarkerTrailGeneration.swift` change is 02.5b's.
- **§3:**
  - The § 3 Source line's false claim is removed and replaced with the 02.5b dependency.
  - The heading is corrected to `## 3. Marker and trail (D45, D47)`.
  - Two quotes are added: data-model § StudentState `past_last_unit` and expedition W6.
  - The map W5 binding gains a note on step 2.
  - This arbitration is cited among the arbiter rulings.
  - The prior-signature comment on `setMarker` now states the post-02.5b behaviour.
  - The fixture data now includes MTH1W's units.
- **§4:** the §4.4 `setMarker` doc comment and a closing note say that `unitId` passes through to the single
  source. §4.6 is updated to match. The code is unchanged.
- **§5:**
  - T4 gains an AC8 conformance bullet.
  - A "real composition" bullet is added.
  - T5 gains AC8's two negative controls.
  - T6's relaunch bullet now covers both AC8 cases.
- **§6:** a new decision default: the façade does not substitute the last unit itself.
- **§7:** 02.5b's suite is added to the unmodified-green list, and data-model is added to the contract list.

## Follow-ups for the orchestrator (outside `tasks/*` write authority)

- `docs/plans/epic-02-plan.md` lists 02b as 02.9–02.13. Dispatch 02.5b on the 02b branch before 02.13, and
  have 02.13's acceptance report include it in the R-7 table above.
