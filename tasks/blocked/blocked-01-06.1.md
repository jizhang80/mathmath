# BLOCKED — task 01.6.1 (contract-v1-1-probe-check)

**Time (UTC):** 2026-09-10T02:36:31Z

## Where it failed

`tasks/epic-01-task-06.1-contract-v1-1-probe-check.md` §7 Done definition, gate:
`Core` tests green on the iOS simulator (gate 3). Command run (`scripts/gate.sh` step 3, and directly):

```
cd Packages/Core && xcodebuild test -quiet -scheme Core-Package -destination "$SIM" CODE_SIGNING_ALLOWED=NO
```

Exit: non-zero. 20 pre-existing `L0CheckerTests` / `L0CheckerContractTests` fail — none touched by this
task's changes to `Model/Nodes.swift` or `Model/Landmarks.swift` logic, all failing on the same root cause.

## Root cause (verified by direct read and by running the suite)

`Packages/Core/Sources/Core/Model/Landmarks.swift` gains, per the spec's §4 step 7 (verbatim):

> `Packages/Core/Sources/Core/Model/Landmarks.swift` — add `public let sourceTitle: String` after `name`.
> It is non-optional for the same reason `sourceUrl` is … the schema requires it, so decode fails without
> it, and I15's verifiability is structural.

Every fixture under `Packages/Core/Tests/CoreTests/Fixtures/l0/**/landmarks.json` (all ten `l0-*` rule
fixtures, `valid/`, `manifest-version-mismatch/`, `manifest-missing-file/`) carries a `landmarks[0]` object
with **no `source_title` key** — e.g. `Packages/Core/Tests/CoreTests/Fixtures/l0/valid/landmarks.json:1-19`
has `id, name, what_it_is, source_url, node_ids, region_ids, position` and no `source_title`. Decoding any of
these into `LandmarksFile` now throws:

```
DecodingError.keyNotFound: Key 'sourceTitle' not found in keyed decoding container. Path: landmarks[0].
Debug description: No value associated with key CodingKeys(stringValue: "sourceTitle", intValue: nil)
("sourceTitle").
```

`L0CheckerTests` and `L0CheckerContractTests` decode these fixtures via `BundleIO.read`, so every test that
loads any `l0-*` fixture now fails at decode, before the L0 rule under test ever runs:
`validFixturePasses`, `validateIsDeterministic`, `passedIsAndOverAllChecks`, `l0_4NeverInChecks`,
`l0_9AllowsNonResidentSuccessor`, `manifestVersionMismatchThrows`,
`negativeControlDetectsViolation(fixture:ruleId:errorCode:)` (all 10 parametrized cases),
`negativeControlExactIdAndCode(fixture:ruleId:contractErrorCode:)` (all cases), plus the
`L0CheckerContractTests` suite in full — 20 named failures total (pasted at the end of this file).

## What the spec, the bundle and the contracts each said

- **The spec's §2 file scope**, out-of-scope list, on `Packages/Core/Tests/CoreTests/Fixtures/**`:
  > these fixtures are not schema-validated (`test_data_bundles_validate` scans `data/**` only) and `check`
  > is optional in the Swift type, so they decode unchanged. Do not churn them.

  This reasoning is **only true for `check`** (optional on `ProbeItem`, so a fixture `nodes.json` without it
  still decodes). It does **not** hold for `sourceTitle`, which the same spec's §4 step 7 declares
  non-optional. The spec never states that fixtures carry `source_title`, and a direct read confirms none
  do. The out-of-scope note is factually wrong about the consequence for `Landmark`, and the task carries no
  authorization to edit `Fixtures/**` to correct it.
- **The task's own §7 Done definition** requires, unconditionally: "`Core` tests green on the iOS simulator
  (gate 3), including T1, T2, T5b" and "`scripts/gate.sh` green end-to-end" — both currently impossible
  without either (a) editing a file outside §2's scope (`Fixtures/l0/**/landmarks.json`, explicitly
  forbidden: "Do not churn them") or (b) making `sourceTitle` optional (explicitly forbidden by §4 step 7 and
  by I15's rationale for non-optionality, which the spec states in the same breath as the `sourceUrl`
  precedent already in the codebase).
- **The orchestrating instructions** (this task's dispatch message) additionally require: "Every existing
  test across tasks 01.1–01.6 must stay green" — the 20 `L0CheckerTests`/`L0CheckerContractTests` failures
  are exactly such pre-existing, previously-green tests, broken by a field this spec mandates as
  non-optional with no in-scope path to keep their fixtures decodable.
- **Contracts**: silent on this — `contracts/schemas/landmarks.schema.json` and
  `contracts/data-model.md` govern `data/**` and `contracts/examples/**`, not `Packages/Core/Tests/.../
  Fixtures/**`; the fixtures are explicitly outside schema enforcement's scope
  (`pipeline/tests/test_contracts.py::test_data_bundles_validate` scans `data/**` only, as the spec itself
  notes). The contracts do not resolve the conflict between "fixtures decode unchanged" and "`sourceTitle`
  is required."

## What would unblock it

One of, decided by the spec-arbiter/owner (a Q5-adjacent scope question, since it touches whether
`Fixtures/l0/**` is in this task's writable set):

1. Widen §2's file scope to include `Packages/Core/Tests/CoreTests/Fixtures/l0/**/landmarks.json` (and any
   other `Fixtures/**/landmarks.json`) so each can gain a `source_title` value, OR
2. Confirm these particular fixtures may be batch-amended by a follow-up mechanical pass (e.g. a script) as
   part of this task despite the current out-of-scope line, with the exact `source_title` value to use per
   fixture (or one shared placeholder, e.g. reusing `"Interest Act"` since every `l0-*` fixture's landmark
   is a copy of the same Demo landmark), OR
3. Rule that `sourceTitle` should in fact remain optional in `Core` for this task (reopening §4 step 7),
   which the spec-arbiter would need to weigh against I15's "structural" rationale the spec gives for
   non-optionality.

No other file in this task's diff is implicated — `contracts/**`, `contracts/examples/**`, `data/demo/**`,
and the Swift `Model` types all changed exactly as the spec's §4 prescribes, and the 20 SymPy `check`
derivations were independently verified to MATCH `answer.value` in every row (run separately, not part of
this failure).

## State left behind

The working tree was **clean** at report time (`git status` shows no diffs). All work performed for this
task is preserved in a stash on branch `epic-01-core-data-l0-layout-demo-bundle`:

```
git stash list
stash@{0}: On epic-01-core-data-l0-layout-demo-bundle: task-06.1 WIP: blocked on Fixtures/l0 sourceTitle decode failure
```

`git stash pop` restores it verbatim for the next attempt.

## The 20 failing tests (verbatim from `xcodebuild test`)

```
L0CheckerTests.validateIsDeterministic()
L0CheckerTests.l0_9AllowsNonResidentSuccessor()
L0CheckerTests.l0_4NeverInChecks()
L0CheckerTests.manifestVersionMismatchThrows()
L0CheckerTests.passedIsAndOverAllChecks()
L0CheckerTests.validFixturePasses()
-[L0CheckerTests negativeControlDetectsViolation(fixture:ruleId:errorCode:)]
L0CheckerContractTests.l0_3aUnknownCodeFixtureIsADoubleViolationByConstruction()
L0CheckerContractTests.reportShapeMatchesContract()
L0CheckerContractTests.l0_1SelfLoopIsolatesCleanly()
L0CheckerContractTests.l0_10DoesNotResolveSourceUrl()
L0CheckerContractTests.reportListsEveryContractRuleId()
L0CheckerContractTests.l0_4NoOutlierStillReported()
L0CheckerContractTests.l0_4OutlierReportedButAdvisory()
L0CheckerContractTests.l0_3bDoesNotResolveLocator()
L0CheckerContractTests.validateIsPureAcrossInterleavedCalls()
L0CheckerContractTests.l0_3aDirectionAIsolatedFromDirectionB()
L0CheckerContractTests.manifestVersionMismatchRefusesWithContractCode()
L0CheckerContractTests.l0_1CycleFixtureTripsL0_2AsWellByConstruction()
-[L0CheckerContractTests negativeControlExactIdAndCode(fixture:ruleId:contractErrorCode:)]
```

All fail with the identical root-cause `DecodingError.keyNotFound("sourceTitle")` (one representative
message, from `L0CheckerTests.swift:39:6`):

```
Test "valid fixture passes every non-advisory rule (AC1)" recorded an issue at L0CheckerTests.swift:39:6:
Caught error: DecodingError.keyNotFound: Key 'sourceTitle' not found in keyed decoding container.
Path: landmarks[0]. Debug description: No value associated with key CodingKeys(stringValue: "sourceTitle",
intValue: nil) ("sourceTitle").
```

## Work already verified correct (not the cause of the block, recorded for the retry)

- All 20 pinned `check` objects in the spec's §4 step 6 table derive, under the exact normative algorithm
  of `contracts/data-model.md` § Probe answer derivation (sympy 1.14.0, the pinned version), a value
  **exactly equal** to that item's `answer.value`. All 20 rows: `MATCH`.
- `data/demo/nodes.json` diff (before this block was filed) added exactly 20 `check` keys and changed
  nothing else — verified programmatically by stripping `check` from the modified document and comparing
  object-equal to the original.
- Gates 1 (`swift-format` + `ruff`) and 2 (`pyright`) passed clean on the changed files before the block was
  hit; gate 3 is where the fixture conflict surfaced.
