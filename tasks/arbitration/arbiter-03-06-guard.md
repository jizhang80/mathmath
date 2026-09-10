# Arbiter ruling: task 03.06 — T9 single-source guard negative control

**Date**: 2026-09-10
**Spec**: tasks/epic-03-task-06-map-view-model.md
**Trigger**: writer↔reviewer non-convergence (2nd BLOCK)

## Finding

§5 T9 (AC14 structural guard: `MapViewModel.swift` declares no `scopeWindow`/`fringeNodeIds`/
`residentNodeIds`/`unitIndex`) had no negative control proving the scan fails red on a planted violation, and
did not declare empty-scan behaviour.

**Classification: VALID.** Verified against the codebase precedent
`Packages/Core/Tests/CoreTests/ImportBoundaryNegativeControlTests.swift:20-83`: one scan helper parameterised
over its input (`forbiddenImportViolations(in:)`), `#expect(!files.isEmpty, "... empty scan is a FAIL")`
(`:31`), a planted-violation case asserting detection (`:47-64`), and a clean-fixture case asserting no
detection (`:68-83`). T9 as written had only the real-file half.

## Ruling (applied)

- §4 step 9 (new): a single private test helper `restatedDeclarations(in source: String) -> Set<String>`
  (matches `func <name>(` with any modifier; skips `//` lines; call sites never match). Old step 9 (smoke)
  renumbered to 10.
- §5 T9: rewritten to use only that helper; empty scan = FAIL (file resolves, non-empty, contains
  `static func derive(`).
- §5 T9b (new): planted synthetic text with all four names (varied modifiers) → helper returns exactly the four;
  clean synthetic text (call sites + comment + `derive`) → empty set. In-memory text, not a temp directory,
  because T9 scans one file's text rather than walking a tree.
- §1 (summary + I14 clause) and AC14: instrument named (helper, empty=FAIL, exclusions) and T9b cited.
- §2: test-file role line names the shared helper; precedent file listed read-only.
- §3: precedent file cited with excerpt.
- §6: one decision default recording the shape choice.
- §7: T9 and both T9b cases named explicitly.

Unchanged: every production-code instruction, the `Expedition.swift` visibility edit, the public
`derive(bundle:state:today:)` signature consumed by 03.7, T1–T8.
