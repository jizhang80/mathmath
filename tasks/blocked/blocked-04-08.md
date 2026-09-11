# BLOCKED: Epic 04, Task 08 — app-expedition-screens

**UTC time:** 2026-09-11T02:00:00Z (approx; see session log)

**Where it failed:** gate 3 (`Packages/Core`: `xcodebuild test -scheme Core-Package -destination "$SIM"
CODE_SIGNING_ALLOWED=NO`, `scripts/gate.sh:16-17`), after the code for this task's full §2 scope was written
exactly per the spec (§4, with the `DoorRunState`/`Equatable` corrections from
`tasks/arbitration/arbiter-04-doorrunstate-equatable.md` applied). Exit: `** TEST FAILED **`.

## What failed, and why

Implementing this task's mandatory acceptance criteria — specifically AC6/AC7 (rename
`HandOffDestination.unitExpedition(result: ComposeResult)` to `.doorBStarted(DoorBStartOutcome)`; add
`StartExpeditionActionButton`; rewire `UnitExpeditionActionButton` to call
`DoorFacade.startUnitExpedition` instead of `MapFacade.unitExpedition`) and AC7/AC9 (add `DoorRunHolder`,
`DoorBRunSnapshot`, the `fullScreenCover`, and the renamed `handOff` case in `AppShell.swift`) — necessarily
breaks two pre-existing `CoreTests` structural suites that are **outside this task's §2 file scope** and that
hard-code the exact shape this task's spec mandates replacing:

- `Packages/Core/Tests/CoreTests/AppShellStructuralTests.swift`
  - `handOffSwitchesOverExactlyThreeDestinationNames()` — asserts `AppShell.handOff`'s switch has exactly 2
    case clauses, one of them literally `case .diagnosis, .unitExpedition:`. This task's spec (AC7) mandates
    3 case clauses (`.included`, `.doorBStarted`, `.diagnosis`).
  - `diagnosisAndUnitExpeditionBranchCallsNoFurtherCoreFunction()` — locates the branch by the literal string
    `"case .diagnosis, .unitExpedition:"`, which no longer exists once AC7 is implemented.
  - `coreErrorTextCalledExactlyTwiceAcrossShell()` — asserts exactly 2 `CoreErrorText.text(for:` call sites
    across `AppShell.swift` + `RefusalView.swift`. This task's spec (§4.9) adds 2 more (the summary's
    write-failure resolution and `DoorBRunScreen.startAnother`'s error text), for a mandated total of 4.

- `Packages/Core/Tests/CoreTests/MapPanelsPickersHandOffStructuralTests.swift`
  - `handOffDestinationHasExactlyThreeCases()` — asserts the third case's literal text is
    `unitExpedition(result: ComposeResult)`. This task's spec (§2, AC6) mandates it read
    `doorBStarted(DoorBStartOutcome)`.
  - `mapActionsViewCallsFacadeExactlyOncePerButton()` (×4 failing variants) — asserts
    `MapActionsView.swift` contains exactly 3 `MapFacade.` call sites including `MapFacade.unitExpedition(`,
    and the literal string `handOff(.unitExpedition(result: result))`. This task's spec (§4.8) mandates
    `UnitExpeditionActionButton` call `DoorFacade.startUnitExpedition(` instead, dropping the
    `MapFacade.unitExpedition(` call site entirely, and adds a new `StartExpeditionActionButton` calling
    `DoorFacade.startExpedition(`.
  - `errorTextCallSiteMatchesRegistrySurfaceForExpNoFringe()` — locates the `EXP_NO_FRINGE` error-text call
    site by scanning `MapActionsView.swift` for a shape that assumes only `UnitExpeditionActionButton`
    exists; the new `StartExpeditionActionButton` (mandated by AC6/§4.8) changes that shape.
  - `exactlyOneStatePropertyAcrossAllFiles()` — asserts exactly one `@State` property exists across the six
    `App/Sources/MapUI` files, named `UnitExpeditionActionButton.errorText`. This task's spec (§4.8) mandates
    a second `@State private var errorText: String?` on the new `StartExpeditionActionButton`.

I implemented the full §2 scope exactly as §4 specifies (all 6 new `App/Sources/Doors/*.swift` files, the
`MapActionsView.swift` rewire, and the `AppShell.swift` `DoorRunHolder`/`DoorBRunScreen` addition), confirmed
`swift-format lint --strict` clean, then ran the full `scripts/gate.sh` per the dispatch instructions. Gate 3
failed with the 11 test failures listed above (re-run once, per Q2 — same 11 failures both times, confirming
this is not flaky).

## What the spec, the bundle, and the pre-dispatch note each said

- **The task spec** (`tasks/epic-04-task-08-app-expedition-screens.md`) explicitly mandates exactly the
  `HandOffDestination`/`AppShell` shape that breaks these two test files (§2, §4.8, §4.9, AC6, AC7, AC9). It
  says nothing about `AppShellStructuralTests.swift` or `MapPanelsPickersHandOffStructuralTests.swift` at all
  — neither in its §2 file scope (in-scope or out-of-scope lists) nor in its §5 test plan, nor in its §6
  decision defaults. Its own claim about existing tests (§5 C3 note, §7 Done definition) names only "the 03.9
  `AppSourcesBoundary` scan" and "03.12's simulator smoke" as suites this task must keep green — it never
  claims the 03.11/03.12 *structural* test suites (`AppShellStructuralTests.swift`,
  `MapPanelsPickersHandOffStructuralTests.swift`) stay green.
- **The orchestrator's dispatch message**, pre-dispatch check #6, states more broadly: "The existing 03.9
  `AppSourcesBoundary` scan and the 03.10–03.12 structural suites must stay green," and separately: "Run the
  FULL `scripts/gate.sh` and get it green before committing." These two instructions are in direct tension
  with the spec's own mandated code changes (AC6, AC7, AC9): implementing the spec's ACs as written
  necessarily flips 11 assertions red in exactly the two pre-existing structural suites the dispatch message
  names.
- **The context bundle** (`tasks/context/epic-04-task-08-context.md`) does not mention either test file.
- **The arbiter rulings** (`arbiter-04-predispatch.md`, `arbiter-04-doorrunstate-equatable.md`) do not mention
  either test file or this tension.
- **§2 file scope** (both the spec's and the dispatch message's) does not list
  `Packages/Core/Tests/CoreTests/AppShellStructuralTests.swift` or
  `Packages/Core/Tests/CoreTests/MapPanelsPickersHandOffStructuralTests.swift` as in-scope for this task, so I
  cannot update them without violating file-scope discipline (a hard rule) and the "do not pre-empt the
  tester" rule (comprehensive structural suites are the tester's responsibility, not the implementer's).

This is a genuine, foreseeable-in-hindsight gap in task planning across EPIC 03/04: nobody's task spec assigns
ownership of updating `AppShellStructuralTests.swift`'s and `MapPanelsPickersHandOffStructuralTests.swift`'s
now-obsolete hard-coded assertions (the exact `HandOffDestination` case list, the exact `MapActionsView.swift`
button/façade-call shape, the exact `@State` count) for the rename this task's own spec mandates. A grep of
`tasks/epic-04-task-10-app-sources-door-scan.md` (the next task touching `App/Sources`-scan test infrastructure)
finds no mention of either file either.

## What input would unblock this

One of:
1. A spec-arbiter ruling assigning ownership of the two stale assertions in `AppShellStructuralTests.swift`
   (`handOffSwitchesOverExactlyThreeDestinationNames`, `diagnosisAndUnitExpeditionBranchCallsNoFurtherCoreFunction`,
   `coreErrorTextCalledExactlyTwiceAcrossShell`) and the five in `MapPanelsPickersHandOffStructuralTests.swift`
   (`handOffDestinationHasExactlyThreeCases`, `mapActionsViewCallsFacadeExactlyOncePerButton` ×4 sub-cases,
   `errorTextCallSiteMatchesRegistrySurfaceForExpNoFringe`, `exactlyOneStatePropertyAcrossAllFiles`) — either
   widening this task's §2 file scope to include the two test files with the exact re-worded assertions, or
   deferring/quarantining them explicitly (e.g. `.disabled` with a citation) pending a follow-up task, or
   confirming this task should proceed and land with gate 3 red for these 11 pre-existing tests specifically
   (an explicit exception to "all gates green"), with the acceptance report noting it.
2. Confirmation that the dispatch message's pre-dispatch check #6 ("the 03.10–03.12 structural suites must
   stay green") is itself in error for this task and should be read narrower (matching the spec's own §5/§7
   claim, which names only the 03.9 boundary scan and 03.12's sim-smoke) — in which case the two stale
   structural suites are simply a known, accepted gate-3 regression for this task, and I need explicit
   authorization to commit with that regression, since "loop until all gates are green" and "the only failures
   you may fix-and-rerun are format/lint/typecheck failures caused by your own newly-written code" otherwise
   forbid it.

Working tree left clean (all product changes reverted; only the pre-existing untracked
`App/mathmath.xcodeproj/project.xcworkspace/` remains, per instruction, untouched).
