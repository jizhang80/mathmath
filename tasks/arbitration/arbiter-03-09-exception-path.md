# Arbiter ruling — task 03.09: SwiftMath exception must match an exact path, not a file name

**Date**: 2026-09-10
**Spec**: `tasks/epic-03-task-09-app-sources-i14-scan.md`
**Trigger**: writer↔reviewer non-convergence (2 BLOCK cycles). Cycle 1 (module-wide `SwiftMath` allowance) was
already fixed by the file-scoped exception. Cycle 2 is the finding below.

## Finding

The §4.2 skip block matched `file.lastPathComponent == contentViewSwiftMathExceptionFile`, so any
`ContentView.swift` anywhere under the scanned root (e.g. `App/Sources/Views/ContentView.swift`) was exempt. That
contradicts §1's "named, file-scoped, time-boxed exception" for exactly `App/Sources/ContentView.swift`.

**Classification: VALID.** Verified: the pre-arbitration spec §4.2 skip block compared `lastPathComponent`.
`App/Sources/ContentView.swift:2` is `import SwiftMath`, and it is the only file under `App/Sources` that imports
it (Glob `App/Sources/**/*.swift` → `MathmathApp.swift`, `ContentView.swift`). So an exception scoped to the one
top-level path covers everything that exists today.

## Ruling

- The exception applies only when
  `file.resolvingSymlinksInPath().standardizedFileURL.path ==
  root.appendingPathComponent(contentViewSwiftMathExceptionFile).resolvingSymlinksInPath().standardizedFileURL.path`
  and the trimmed line is `import SwiftMath`. Both sides are resolved so a Darwin temp root (`/var` →
  `/private/var`) cannot defeat the positive case. A mismatch can only withhold the exception, never widen it.
- The constant names stay the same. The semantics of `contentViewSwiftMathExceptionFile` change from
  "file name" to "path relative to the scanned root" (value is still `"ContentView.swift"`, meaning the top
  level only).
- AC7 becomes three tests: (a) top-level `MathView.swift` with `import SwiftMath` is reported (existing);
  (b) NEW: nested `Views/ContentView.swift` with `import SwiftMath` is reported, alone and beside an exempt
  top-level `ContentView.swift` (exactly one report); (c) top-level `ContentView.swift` is exempt (existing,
  renamed `exemptsSwiftMathInsideTopLevelContentView`).
- Sections edited: §1 (exception paragraph, AC7), §2 (negative-control file role), §3 (two lines about the
  carve-out fact), §4.2 (doc comment, skip block, explanatory note), §4.4 (AC7 tests), §5 (T1, T5.7, new
  T5.8, T6), §6 (first default, a new path-comparison default, the 03.12 deletion default), §7. The
  reviewer-passed content outside these sections is unchanged.

## 03.12 deletion obligation (unchanged names)

- `AppSourcesBoundary.contentViewSwiftMathExceptionFile` (`"ContentView.swift"`, root-relative path)
- `AppSourcesBoundary.contentViewSwiftMathExceptionImport` (`"SwiftMath"`)
- The whole `if rule.name == "non-allow-listed import", <exact-path comparison>, <import line match> { continue }`
  statement in `violations(in:rules:)`
- Plus: invert or delete `exemptsSwiftMathInsideTopLevelContentView()`. Its premise no longer holds once the
  exception is gone. The other two AC7 tests stay valid.
