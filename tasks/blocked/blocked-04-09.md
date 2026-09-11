# BLOCKED: epic-04 task-09 (app-diagnosis-screens)

**Time (UTC):** 2026-09-11T06:48:41Z

**Where it failed:** Gate 3 (`swift test`/`xcodebuild test -scheme Core-Package`), run after implementing the
full spec (§4.2–§4.6, exactly as written) and the §4.11 lockstep structural-guard updates to
`AppShellStructuralTests.swift` and `MapPanelsPickersHandOffStructuralTests.swift`.

Command:

```
cd Packages/Core && xcodebuild test -quiet -scheme Core-Package -destination "$(scripts/pick-simulator.sh)" CODE_SIGNING_ALLOWED=NO
```

Exit: test failure (not build failure). Relevant tail of output:

```
Failing tests:
	DoorExpeditionScreensStructuralTests.doorBPhaseHasExactlyTwoCases()

** TEST FAILED **
```

## Root cause

`Packages/Core/Tests/CoreTests/DoorExpeditionScreensStructuralTests.swift` (04.8's own comprehensive tester
suite, out of this task's §2 file scope and explicitly listed as untouchable in the orchestrator's
pre-dispatch check #6) contains:

```swift
// Packages/Core/Tests/CoreTests/DoorExpeditionScreensStructuralTests.swift:331-343
@Test("I3: DoorBPhase declares exactly the two expected cases, .screen and .answerCard")
func doorBPhaseHasExactlyTwoCases() throws {
    let source = try Self.readShell()
    guard let body = Self.balancedBraceBlock(after: "enum DoorBPhase: Equatable {", in: source) else {
        Issue.record("could not locate DoorBPhase's body")
        return
    }
    let cases = body.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { $0.hasPrefix("case ") }
    #expect(cases.count == 2, "expected exactly 2 DoorBPhase cases, found: \(cases)")
    #expect(cases.contains { $0.hasPrefix("case screen(") })
    #expect(cases.contains { $0.hasPrefix("case answerCard(") })
}

@Test("negative control: a planted third DoorBPhase case is caught")
func plantedThirdDoorBPhaseCaseIsCaught() { ... asserts a third case IS an error ... }
```

This pins `DoorBPhase` (`App/Sources/Shell/AppShell.swift`) to exactly two cases — `.screen` and
`.answerCard` — with an explicit negative control proving a third case must be rejected.

But `tasks/epic-04-task-09-app-diagnosis-screens.md` §4.6 / AC6 mandates adding a **third** `DoorBPhase` case:

```swift
enum DoorBPhase: Equatable {
    case screen(DoorBScreen)
    case answerCard(DoorBAnswerAdvance)
    case diagnosisAnswerCard(DoorAProbeAnswerAdvance)
}
```

AC6 (spec, verbatim): "The new `.diagnosisAnswerCard(let advance)` `DoorBPhase` case (added to the existing
enum) renders 04.8's `ExpeditionAnswerCardView(content: advance.answerCard)` with its continue control calling
`continueAfterProbeAnswer`." This is not optional — it is the only mechanism §4.6's code uses to show the
probe-item answer card (mirroring 04.8's own `.answerCard` mechanism for expedition items), and AC7's
`continueAfterProbeAnswer` call site is reachable only through it.

Implementing the spec exactly as written therefore makes `DoorExpeditionScreensStructuralTests
.doorBPhaseHasExactlyTwoCases()` fail — by design, since that test's own negative control
(`plantedThirdDoorBPhaseCaseIsCaught`) proves a third case is meant to be caught, not permitted.

## What the spec / bundle / contracts each said

- **Spec (`tasks/epic-04-task-09-app-diagnosis-screens.md`) §4.6, AC6, AC7:** mandates the third `DoorBPhase`
  case verbatim, with `@ViewBuilder` switch and call-site code shown in full. Silent on
  `DoorExpeditionScreensStructuralTests.swift`'s conflicting shape guard — the spec's own §2 "out-of-scope"
  list does not mention that file at all (it names `App/Sources/Doors/ExpeditionItemView.swift` etc. as 04.8's
  files to leave alone, but the *test* file pinning `DoorBPhase`'s case count is not named anywhere in §2 or
  §3).
- **Orchestrator dispatch message, pre-dispatch check #6 (this session's own instructions):** "do not edit
  `DoorExpeditionScreensStructuralTests.swift` (04.8's tester file). If one of its assertions pins a shape your
  spec changes, report BLOCK with the exact assertion; do not edit it." — this is exactly that situation,
  named and pre-anticipated.
- **`tasks/arbitration/arbiter-04-08-structural-suite-ownership.md` §5:** governs only
  `AppShellStructuralTests.swift` and `MapPanelsPickersHandOffStructuralTests.swift` (the two files this
  task's §2 lists as MODIFY targets, and its §5 exactly matches this task's §4.11). It says nothing about
  `DoorExpeditionScreensStructuralTests.swift`, which is 04.8's own comprehensive/tester-authored suite, not a
  lockstep structural guard this task owns.
- **Contracts:** silent — this is a test-suite ownership conflict, not a contract question.

## What input would unblock this

A ruling (Q5/spec-arbiter territory, since it touches a locked prior task's shipped test file) on one of:
1. `DoorExpeditionScreensStructuralTests.doorBPhaseHasExactlyTwoCases()` and its negative control
   `plantedThirdDoorBPhaseCaseIsCaught()` are amended (by the tester/task owner of that suite, in a separate
   change) to expect three cases instead of two, matching 04.9's AC6; or
2. The spec is amended to add `DoorExpeditionScreensStructuralTests.swift` to this task's §2 in-scope MODIFY
   list (with an exact, narrow instruction analogous to §4.11, naming precisely which lines to change), so a
   future implementer may touch it under an explicit mandate; or
3. A ruling that `.diagnosisAnswerCard` should be represented without extending `DoorBPhase`'s case count (e.g.
   folding the probe answer-card content into the existing `.answerCard(DoorBAnswerAdvance)` payload, or a
   different mechanism) — but no such alternative is described anywhere in the spec, bundle, or `Core`'s
   shipped types (`DoorBAnswerAdvance` and `DoorAProbeAnswerAdvance` are distinct, unrelated `Core` types per
   04.3/04.8's own signatures), so this would itself require a spec rewrite, not an implementer's guess.

No code was left in the working tree; `git status --short` shows only the pre-existing untracked
`App/mathmath.xcodeproj/project.xcworkspace/`, unchanged.
