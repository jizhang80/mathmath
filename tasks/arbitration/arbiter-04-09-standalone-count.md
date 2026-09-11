# Arbiter ruling: task 04.09 — AC5 `isStandaloneDiagnosis` guard count and "session" prose

**Date**: 2026-09-10
**Spec**: tasks/epic-04-task-09-app-diagnosis-screens.md
**Trigger**: writer↔reviewer non-convergence (2nd BLOCK)

## Findings

1. **§5 T5 AC5 guard miscounts construction sites — VALID.** The guard named six `DoorBRunSnapshot(...)` sites.
   Recount from the code the spec mandates:
   - 04.8 §4.9 (`tasks/epic-04-task-08-app-expedition-screens.md:831, :901, :906, :915`): four sites —
     `.doorBStarted`, `submit`, `continueTapped`, `startAnother`. `backToMap` (`:923`) constructs none.
   - 04.9 §4.6: `.diagnosisStarted` (1); `decideProbe`, `answerProbeItem`, `continueDiagnosisTapped`,
     `decideFurtherLevel`, each passing `isStandaloneDiagnosis: current.isStandaloneDiagnosis` (4);
     `returnFromDiagnosis`'s non-standalone arm (1).
   - Total: **10** construction sites. There is also one declaration (`let isStandaloneDiagnosis: Bool`), one
     conditional read (`if current.isStandaloneDiagnosis`), and four value reads that sit beside their labels.
     A raw `rg -n` line count therefore also changes with formatting.
2. **"session" prose for a diagnosis event or expedition run — VALID.** `contracts/domain-glossary.md:29` bans
   "session" as a synonym for Expedition. `:62` says Session is "in telemetry only … Not a product concept".
   `:40` defines "Diagnosis event". The spec's prose used "session" in §4.6's doc comment and the paragraph after
   it (the reviewer's lines), and also in §1 I14, AC8 and §6 default 1 (the same defect, fixed as cascade).

## Ruling (applied)

- §5 T5: the AC5 guard is now a structural check over `App/Sources/Shell/AppShell.swift`:
  - (a) `rg --count-matches "DoorBRunSnapshot\("` == (b) `rg --count-matches
    "isStandaloneDiagnosis: (true|false|current\.isStandaloneDiagnosis)\b"`, and both == 10.
  - (c) exactly one `isStandaloneDiagnosis: true` line.
  - (d) exactly one `let isStandaloneDiagnosis: Bool` line and exactly one `if current.isStandaloneDiagnosis` line.
  - Empty output = FAIL throughout.
  - The compile-time half is stated: the memberwise init has no default, and `expedition` is non-public.
  - Two negative controls are piped through stdin: a non-permitted value makes the counts diverge, and a
    second `true` site fails (c).
- §4.6 doc comment and the following paragraph, §1 I14, AC8 and §6 default 1 are reworded to "diagnosis event" or "expedition
  run". I14's stale "§4.4" pointer is corrected to §4.6.
- §3: a glossary `:62` citation is added under the existing `:29` block. An "Arbitration correction" note is added.
- §6: one new default records why an exact line count is not used.
- §7: the tests line names the T5 structural guard and its controls.

Unchanged: all production code in §4, the AC semantics, §2 file scope, the 04.8 quote (byte-identical), the Door A
entries, the `Doors/` directory and hint display.
