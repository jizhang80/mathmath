# Epic 04 · Task 07: `MathView` — the SwiftMath display view with plain-text fallback

---
epic: 04
task: 07
slug: rendering-mathview
kind: feat
risk: seam
depends_on: [04.6]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: Implement `MathView` in `Packages/Rendering` — a SwiftUI view over SwiftMath's `MTMathUILabel`
(via a `UIViewRepresentable`) for the app's only LaTeX-bearing fields (`prompt_latex`, `choices[].latex`,
and an `mc` `correctAnswerDisplay`) — plus one static, non-UI entry point the view itself calls to decide
what to show: the parsed display when SwiftMath can render the string, or the unmodified LaTeX source as
plain text when it cannot. The entry point reuses `RenderCheck.parseError(latex:)` (EPIC 01,
`Packages/Rendering/Sources/Rendering/Rendering.swift:9-13`) — no second parser. `Rendering` is already
linked into the App target (`App/mathmath.xcodeproj/project.pbxproj:12, 30, 75, 108, 282-284, 309-311`), so
no pbxproj edit is needed or made. This task ships `MathView` and its entry point only, in
`Packages/Rendering`; it adds no App-layer call site — see §2 for why `App/Sources/ContentView.swift` is
out of scope for this task.

Invariants in play:

- **I1** — not applicable: `MathView` decides nothing about answer correctness; it only displays LaTeX
  strings that `ItemChecker`/the CAS have already produced or verified elsewhere.
- **I2** — vacuous here: `MathView` makes no Tier-1/2 model call. Its one branch point (SwiftMath parses /
  does not parse) is a deterministic Tier-0 computation, not a model guess, so no confidence threshold
  applies.
- **I3** — satisfied by construction: a parse failure never produces a blank view or an error string —
  `MathView` always shows the unmodified LaTeX source as plain `Text`, so a probe prompt, choice or answer
  display is never withheld.
- **I5** — no PII: `MathView`'s only input is a `latex: String`; it emits no telemetry and stores nothing.
- **I6** — out of scope for this task and not violated: `MathView` renders only `prompt_latex`/
  `choices[].latex`/an `mc` `correctAnswerDisplay` per `contracts/data-model.md` § Text; it never renders
  `paraphrase` or any Ministry-sourced field (those stay plain `Text` at call sites this task does not
  touch).
- **I10** — no OCR, no new input path: `MathView` is read-only display; it introduces no student input
  mechanism at all.
- **I14** — `Core` imports Foundation only and gains no dependency on `Rendering` or `SwiftMath` (asserted
  by the existing, unmodified `OutcomeRecordAndImportBoundaryTests.swift` import-boundary test); `Rendering`
  imports `SwiftMath` (and `SwiftUI`) only, never `Core`; L0 and layout are untouched, still exist once in
  `Core`.

Acceptance criteria (each independently verifiable):

- AC1: `MathView.content(latex:)` is a `public static` non-UI entry point declared on `MathView` that calls
  `RenderCheck.parseError(latex:)` (`Rendering.swift:9-13`) and no other SwiftMath parse API — it is the one
  and only place `MathView`'s rendered/fallback decision is made.
- AC2: Over the real `data/demo/nodes.json` bundle, every one of the 80 `prompt_latex`/`choices[].latex`
  strings (40 + 40, verified this session by direct grep — §3 "Data re-read") resolves to the rendered case
  when passed through `MathView.content(latex:)`. An empty scanned set is a hard FAIL, not a vacuous pass.
- AC3: A planted unparsable string (`\frac{1`, already proven unparsable by `RenderingTests.swift`'s
  existing `"SwiftMath reports an unbalanced brace"` test) resolves to the fallback case through
  `MathView.content(latex:)`, and the fallback's text equals the unmodified source string and is never
  empty.
- AC4: `MathView`'s SwiftUI `body` uses the SwiftMath-backed `MTMathUILabel` wrapper only in the rendered
  branch, and plain `Text` in the fallback branch; no branch ever displays an empty string.
- AC5: `LO_ITEM_UNRENDERABLE` (`contracts/error-codes.json:32`, `"surface": "internal"`) is never thrown,
  constructed or referenced anywhere in `MathView.swift` — the runtime fallback path carries no student
  code.
- AC6: The App target still builds green — `xcodebuild build -quiet -workspace App/mathmath.xcworkspace
  -scheme mathmath -destination "$SIM" CODE_SIGNING_ALLOWED=NO` (`scripts/gate.sh:22`, gate 4) — with
  `MathView` available from the already-linked `Rendering` product
  (`App/mathmath.xcodeproj/project.pbxproj:12, 30, 75, 108, 282-284, 309-311`); this task adds no App-layer
  call site and makes no edit under `App/Sources`. `MathView`'s first App consumers are 04.8/04.9
  (`docs/plans/epic-04-plan.md`: "04.8: expedition screens: item view, keypad, choice buttons, answer card
  with an explicit continue, and summary. It replaces 03.11's placeholder for Include and Unit expedition.").
- AC7 (I14): `Packages/Rendering/Tests/RenderingTests/OutcomeRecordAndImportBoundaryTests.swift` stays green
  unmodified — `Core`'s `Package.swift` and every `Core` source file still declare no dependency on
  `Rendering` or `SwiftMath`.
- AC8: The pre-existing Rendering test files (`RenderingTests.swift`, `BundleRenderCheckTests.swift`,
  `CanRenderBoundaryTests.swift`, `FieldKindPolicyMutationTests.swift`,
  `OutcomeRecordAndImportBoundaryTests.swift`, `SchemaEnumerationCoverageTests.swift`) stay green, unmodified
  by this task.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Rendering/Sources/Rendering/MathView.swift` — CREATE. Confirmed absent this session (context
  bundle §E: grep `pattern: "struct MathView"` over `Packages/Rendering/**/*.swift` returns no match). Holds
  `MathViewContent`, `MathView` (public `View`), `MathView.content(latex:)`, and the private
  `UIViewRepresentable` wrapper over `MTMathUILabel`.
- `Packages/Rendering/Tests/RenderingTests/MathViewTests.swift` — CREATE. Confirmed absent (Glob
  `Packages/Rendering/Tests/RenderingTests/MathViewTests.swift` returns no match). Holds T1–T6.

Out-of-scope (do not touch even if tempted):

- `App/Sources/ContentView.swift` — out of scope; this task does not read or write it. This task runs in
  sub-EPIC 04b, which dispatches after EPIC 03 has merged (`docs/plans/epic-04-plan.md`: "04b — Door app:
  04.7–04.13 (wrap 04.13), branch `epic-04b-door-app`"). By the time 04.7 runs, EPIC 03 task 03.12 has
  already replaced the Phase-5 placeholder `ContentView` (with its `MathLabel`/`import SwiftMath`) with the
  map-screen app shell: `docs/plans/epic-03-plan.md` § 03.12 ("the app shell") states "replaces the
  placeholder `ContentView`" and "Only 03.12 writes `ContentView.swift` and `MathmathApp.swift`." The file
  form an earlier draft of this spec quoted (the Phase-5 `MathLabel` struct) will not exist at 04.7's run.
  `docs/plans/epic-04-plan.md`'s own 04.7 note describes only "`MathView` in `Packages/Rendering`, with a
  plain-text fallback when parsing fails (Q-E). The Rendering product is already linked, so the pbxproj is
  not edited" — no `App/Sources` edit. `App/Sources` is written next by 04.8/04.9 (04.8 "replaces 03.11's
  placeholder for Include and Unit expedition"; 04.9 "replaces the Check me here placeholder"), not by 04.7.
- `Packages/Rendering/Sources/Rendering/Rendering.swift` — read-only. `MathView.content(latex:)` calls
  `RenderCheck.parseError(latex:)` (public, already exists) only; no change to `RenderCheck`.
- `Packages/Rendering/Sources/Rendering/RenderCheckReport.swift` — read-only. `MathViewTests.swift` calls
  `RenderCheckReport.scanning(nodesJSON:)` (public, already exists) only, to assemble the 80-string
  population without re-walking the bundle a second way.
- `Packages/Rendering/Tests/RenderingTests/RenderingTests.swift`,
  `BundleRenderCheckTests.swift`, `CanRenderBoundaryTests.swift`, `FieldKindPolicyMutationTests.swift`,
  `OutcomeRecordAndImportBoundaryTests.swift`, `SchemaEnumerationCoverageTests.swift` — read-only; stay
  green unmodified (AC8). **Correction to the context bundle**: the bundle's §F named
  `RenderingTests.swift` as the file to modify for this task's new cases; this task instead creates the new
  file `MathViewTests.swift` per its own scope, per §6 decision default 3 below.
- `App/mathmath.xcodeproj/project.pbxproj` — never edited by an agent (`docs/tech-stack.md` § 2: "Agents add
  files under `App/Sources` and `Packages/Core` without editing the pbxproj"). `Rendering` is already
  declared as a linked framework product (lines 12, 30, 75, 108, 282-284, 309-311, verified this session)
  and needs no further entry.
- `Packages/Core/**`, `contracts/**`, `data/demo/**`, `docs/**` — read-only. `data/demo/nodes.json` is read
  only by `MathViewTests.swift`, through `RenderCheckReport.scanning(nodesJSON:)`.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules:

- `contracts/data-model.md` v1.4.0 — heading `### Text` (nested under `## Rules (normative)`):
  > All student-facing strings are English (DEFERRED D-1). LaTeX appears only in fields named `latex` or
  > `prompt_latex` and must be in the SwiftMath-renderable subset or carry `render_fallback: "katex"`.

  Source: `contracts/data-model.md:35-37` (re-read and byte-verified this session). Binds this task:
  `MathView` is the display for `prompt_latex`, `choices[].latex`, and an `mc` `correctAnswerDisplay` (which
  is the correct choice's own `latex`, `ItemChecker.swift:183-191`); every other field a Door screen shows
  (`why`, hint strings, `paraphrase`) is plain `Text`, never routed through `MathView` — call-site
  responsibility for later tasks (04.8/04.9), not enforced by `MathView` itself.

- `contracts/content-policy.md` v1.1.0 — heading `## Generated content (all tiers)`:
  > Prompts and hints must render in SwiftMath or carry `render_fallback: "katex"` (learning-objects W1 5b).

  Source: `contracts/content-policy.md:34-35` (re-read and byte-verified this session). Binds this task:
  `MathView` must never show a blank view on a `render_fallback: "katex"`-flagged string; per §6 decision
  default 2, this is satisfied by construction because such a string is, by definition, one
  `RenderCheck.parseError(latex:)` reports non-nil for, so it already routes to the fallback branch — no
  separate parameter is needed for this task (`data/demo` carries zero `render_fallback` occurrences,
  verified this session).

Domain-doc excerpt (verbatim):

- `docs/domains/learning-objects.md` — W1 step 5b, Renderability:
  > 5b. **Renderability** — every prompt, hint and explanation renders in SwiftMath, or is flagged for the
  > KaTeX fallback per item, else `LO_ITEM_UNRENDERABLE`.

  Source: `docs/domains/learning-objects.md:81` (context bundle §C, cited verbatim; not re-read from disk in
  this session — carried from the context bundle unchanged since it matches the error-code and contract
  facts independently verified above).

Task-scoped excerpts from the amended brief and the arbiter ruling:

- `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md` — § 4 item 6 (acceptance criterion):
  > 6. **MathView**: `RenderingTests` render every `prompt_latex` and `choices[].latex` in `data/demo` (80
  > strings: 40 + 40 [SOURCED: tasks/arbitration/arbiter-04-predispatch.md § Q-B, count over
  > `data/demo/nodes.json`]) through `MathView`'s own entry point without a parse error. Empty set = FAIL.
  > `MathView` is used only for those fields and an `mc` `correctAnswerDisplay`. The failure path shows the
  > unmodified source as plain text (§9 Q-E) and is covered by one planted unparsable string.

  Source: `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md:339-343` (re-read and byte-verified
  this session; the 80-string count independently re-verified against `data/demo/nodes.json` this session:
  40 occurrences of `"prompt_latex"`, 40 occurrences of `"latex":` inside `choices[]`).

- `tasks/arbitration/arbiter-04-predispatch.md` — § Q-E, ruling:
  > **Ruling.** CONFIRMED. The brief default has four precisions.
  >
  > 1. `MathView(latex:)` calls `RenderCheck.parseError(latex:)` (`Rendering.swift:9-13`). If the result is
  > non-nil, it shows the unmodified source string as plain `Text`. It is never blank and never an error
  > string. This is presentation, not state, so it belongs in `Rendering` (I14: `Core` cannot import
  > SwiftMath).
  > 2. An item carrying `render_fallback: "katex"` (`nodes.schema.json` lines 248–253) is shown the same
  > way. KaTeX is brief § 7 item 4, trigger EPIC 09. `data/demo` has none: `RenderCheckReport` shows 0
  > unresolved of 143.
  > 3. No student code. `LO_ITEM_UNRENDERABLE` is `internal` (`error-codes.json` line 32) and stays a
  > pipeline/test outcome. `BundleRenderCheckTests` is the pre-ship gate.
  > 4. **Field routing.** `MathView` is used only for `prompt_latex`, `choices[].latex`, and an `mc` answer
  > card's `correctAnswerDisplay`, which is a choice's `latex` (`ItemChecker.swift:183-191`). A `numeric`
  > `correctAnswerDisplay` (`answer.value`), `why`, hints and `paraphrase` are plain `Text`. That follows
  > `data-model.md` § Text: "LaTeX appears only in fields named `latex` or `prompt_latex`".

  Source: `tasks/arbitration/arbiter-04-predispatch.md:323-341` (context bundle §H, cited verbatim; not
  re-read from disk this session).

Prior signatures this task builds on (verbatim, re-read and byte-verified this session):

- `Packages/Rendering/Sources/Rendering/Rendering.swift:7-19`:
  ```swift
  public enum RenderCheck {
      /// Returns nil when SwiftMath parses `latex` without error, else the parser's message.
      public static func parseError(latex: String) -> String? {
          var error: NSError?
          _ = MTMathListBuilder.build(fromString: latex, error: &error)
          return error?.localizedDescription
      }

      /// True when `latex` parses without error under SwiftMath's builder.
      public static func canRender(latex: String) -> Bool {
          parseError(latex: latex) == nil
      }
  }
  ```

- `Packages/Rendering/Sources/Rendering/RenderCheckReport.swift:29-45` (the public surface this task's tests
  reuse to assemble the 80-string population — no second bundle walk):
  ```swift
  public struct RenderCheckEntry: Equatable {
      public let itemId: String
      public let field: String
      public let latex: String
      public let parsed: Bool
      public let hasFallback: Bool
      public var resolved: Bool { parsed || hasFallback }
  }
  public struct RenderCheckReport: Equatable {
      public let entries: [RenderCheckEntry]
      public var unresolvedEntries: [RenderCheckEntry] { entries.filter { !$0.resolved } }
      public var unresolvedCount: Int { unresolvedEntries.count }
      public func assertAllResolved() throws { /* throws RenderingError.loItemUnrenderable(itemId:) */ }
  }
  extension RenderCheckReport {
      public static func scanning(nodesJSON data: Data) throws -> RenderCheckReport { /* … */ }
  }
  ```
  Entry `field` values relevant here: `"prompt_latex"` and `"choices[\(choice.id)].latex"` (matches
  `field.hasPrefix("choices[")`), emitted per `RenderCheckReport.swift:141-161`.

- `Packages/Core/Sources/Core/ItemChecker.swift:183-192`:
  ```swift
  /// The correct answer's display string — `item.answer.value` verbatim for `numeric`, the matching
  /// choice's `latex` for `mc` — always shown alongside `why` (I3).
  public static func correctAnswerDisplay(for item: ProbeItem) -> String {
      switch item.type {
      case .numeric:
          return item.answer?.value ?? ""
      case .mc:
          return item.choices?.first(where: { $0.id == item.correctChoiceId })?.latex ?? ""
      }
  }
  ```

- `Packages/Rendering/Package.swift:1-20` (platforms declaration, byte-verified this session):
  ```swift
  let package = Package(
      name: "Rendering",
      platforms: [.iOS(.v18), .macOS(.v15)],
      products: [.library(name: "Rendering", targets: ["Rendering"])],
      dependencies: [
          .package(url: "https://github.com/mgriebling/SwiftMath.git", exact: "1.7.3")
      ],
      targets: [
          .target(name: "Rendering", dependencies: ["SwiftMath"]),
          .testTarget(name: "RenderingTests", dependencies: ["Rendering"]),
      ],
      swiftLanguageModes: [.v6]
  )
  ```

- `Packages/Rendering/.build/checkouts/SwiftMath/Sources/SwiftMath/MathRender/MTConfig.swift:11-30`
  (SwiftMath 1.7.3, pinned exact per `Packages/Rendering/Package.resolved`; verified this session — this is
  why `MTMathUILabel` needs a platform guard, §6 decision default 1):
  ```swift
  #if os(iOS) || os(visionOS)
  import UIKit
  public typealias MTView = UIView
  // …
  #else
  import AppKit
  public typealias MTView = NSView
  // …
  ```
  `MTMathUILabel : MTView` (`MTMathUILabel.swift:51`) — a `UIView` subclass on iOS/visionOS, an `NSView`
  subclass elsewhere. `UIViewRepresentable` only exists for the `UIView` case.

- `App/mathmath.xcodeproj/project.pbxproj` linking lines (verified this session, unchanged by this task):
  - Line 12 (build file): `A100000000000000000000A3 /* Rendering in Frameworks */`
  - Line 30 (frameworks build phase): `A100000000000000000000A3 /* Rendering in Frameworks */,`
  - Line 75 (package product dependencies): `P100000000000000000000P3 /* Rendering */,`
  - Line 108 (XCLocalSwiftPackageReference): `L100000000000000000000L3 /* XCLocalSwiftPackageReference
    "../Packages/Rendering" */,`
  - Lines 282-284 (reference definition): `L100000000000000000000L3 /* XCLocalSwiftPackageReference
    "../Packages/Rendering" */` with `relativePath = ../Packages/Rendering;`
  - Lines 309-311 (product reference): `P100000000000000000000P3 /* Rendering */` with
    `productName = Rendering;`

Error code (registered, internal only):

- `contracts/error-codes.json:32`:
  ```
  {"code": "LO_ITEM_UNRENDERABLE", "recoverable": true, "surface": "internal", "user_text": null},
  ```
  Verified this session. `MathView`/`MathView.content(latex:)` never throws, constructs or references this
  code (AC5) — it stays a pipeline/test outcome, unchanged by this task.

## §4 Implementation outline

1. **Layer.** `MathView.swift` is layer ④ interaction's render-side display component, living in
   `Packages/Rendering` (never `Core` — I14: `Core` imports Foundation only and cannot import `SwiftMath`).
   It is the render counterpart later Door screens (04.8/04.9) call for `prompt_latex`, `choices[].latex`
   and an `mc` `correctAnswerDisplay`; this task ships the view and its entry point only — it adds no App-
   layer call site at all (§2: `App/Sources/ContentView.swift` is out of scope).

2. **The non-UI entry point** — `MathView`'s own static decision function, calling `RenderCheck.parseError`
   exactly once and no other SwiftMath parse API:
   ```swift
   /// What `MathView` shows for `latex`. Never blank (I3).
   public enum MathViewContent: Equatable {
       case rendered(latex: String)
       case fallback(text: String)
   }

   extension MathView {
       /// Non-UI entry point `MathView.body` itself calls. Reuses `RenderCheck.parseError(latex:)` — the
       /// same parser `RenderCheckReport`/`BundleRenderCheckTests` already gate the bundle with — never a
       /// second parser.
       public static func content(latex: String) -> MathViewContent {
           RenderCheck.parseError(latex: latex) == nil
               ? .rendered(latex: latex)
               : .fallback(text: latex)
       }
   }
   ```
   No boundary schema applies here — `latex` is a plain `String`, not decoded JSON — but `content(latex:)`
   never throws: a parse failure is expressed as the `.fallback` case, a value, never an error, matching I3
   (answers/prompts are never withheld, not even by a thrown error interrupting the view).

3. **The view**, platform-guarded per §6 decision default 1 (SwiftMath's `MTMathUILabel` is a `UIView`
   subclass only on iOS/visionOS, an `NSView` subclass on macOS — `MTConfig.swift:11-30`, §3):
   ```swift
   public struct MathView: View {
       public let latex: String

       public init(latex: String) {
           self.latex = latex
       }

       public var body: some View {
           switch MathView.content(latex: latex) {
           case .rendered:
               #if canImport(UIKit)
               MathLabel(latex: latex)
               #else
               Text(latex)
               #endif
           case .fallback(let text):
               Text(text)
           }
       }
   }

   #if canImport(UIKit)
   /// UIKit bridge over SwiftMath's `MTMathUILabel`, used only when `MathView.content(latex:)` resolves
   /// `.rendered` — i.e. `RenderCheck.parseError(latex:)` returned nil for this string.
   private struct MathLabel: UIViewRepresentable {
       let latex: String

       func makeUIView(context: Context) -> MTMathUILabel {
           let label = MTMathUILabel()
           label.latex = latex
           label.textAlignment = .center
           return label
       }

       func updateUIView(_ uiView: MTMathUILabel, context: Context) {
           uiView.latex = latex
       }
   }
   #endif
   ```
   `MTMathUILabel`'s `.latex` and `.textAlignment` properties are the same SwiftMath API surface the Phase-5
   placeholder (now superseded by EPIC 03 task 03.12, §2) already exercised — reused for their verified
   SwiftMath API shape only, not mirrored blindly: `MathView` additionally satisfies AC1–AC5, which the
   Phase-5 placeholder never had to.

4. **Error codes.** None thrown by this task's code. `LO_ITEM_UNRENDERABLE` (`contracts/error-codes.json:32`,
   `"surface": "internal"`) stays a pipeline/test-only outcome via `RenderCheckReport.assertAllResolved()` /
   `BundleRenderCheckTests`, unmodified by this task; `MathView.swift` never references
   `RenderingError.loItemUnrenderable` (AC5, tested structurally in §5 T3).

5. **Model-calling path.** None. `MathView` performs no Tier-1/2 model call; its one branch point is a
   deterministic Tier-0 SwiftMath parse, not a model guess — I2's confidence-threshold/fallback machinery
   does not apply here, and I1's "CAS decides correctness" is not in play because `MathView` decides nothing
   about correctness, only renderability.

6. **`MathViewTests.swift`.** One `@Suite("MathView")` with:
   - a private `nodesJSONURL()` helper resolving `data/demo/nodes.json` from `#filePath` (same
     five-`deletingLastPathComponent()` pattern `BundleRenderCheckTests.nodesJSONURL()` uses — the same
     nesting depth: `Tests/RenderingTests/MathViewTests.swift` → `Tests/RenderingTests/` → `Tests/` →
     `Rendering/` → `Packages/` → repo root);
   - a private `promptAndChoiceLatexStrings()` helper calling `RenderCheckReport.scanning(nodesJSON:)` and
     filtering to `$0.field == "prompt_latex" || $0.field.hasPrefix("choices[")` — the 80-string population,
     no second bundle walk, no second parser;
   - T1–T6 per §5.

7. **Smoke check**: `( cd Packages/Rendering && xcodebuild test -quiet -scheme Rendering -destination "$SIM"
   CODE_SIGNING_ALLOWED=NO )` (the exact command `scripts/gate.sh:19` runs, `$SIM` from
   `scripts/pick-simulator.sh`) — must be green, including `MathViewTests`.

## §5 Test plan

- T1 (happy path, AC2, AC4): `promptAndChoiceLatexStrings()` returns exactly 80 strings (`!isEmpty`, hard
  FAIL if the scan comes back empty, and `count == 80`); every one resolves `.rendered` through
  `MathView.content(latex:)`.
- T2 (negative — invalid input, AC3): `MathView.content(latex: #"\frac{1"#)` (the same string
  `RenderingTests.swift`'s existing `"SwiftMath reports an unbalanced brace"` test already proves
  unparsable) resolves `.fallback(text:)`; assert `text == #"\frac{1"#` (unmodified) and `!text.isEmpty`.
- T3 (error-taxonomy, AC5): read `MathView.swift`'s own source text (`String(contentsOfFile:encoding:
  .utf8)` from a path resolved via `#filePath`, same repo-root-walk pattern as T1's `nodesJSONURL()`) and
  assert it does not contain the substring `"LO_ITEM_UNRENDERABLE"` and does not contain
  `"RenderingError"` — the fallback path is a plain value (`MathViewContent.fallback`), never that internal
  error type. Empty-read guard: assert the read text is non-empty and contains `"func content(latex:"`
  before asserting the negative, so a wrong path cannot pass vacuously.
- T4 (conformance §B.1 — `contracts/data-model.md` § Text, `contracts/content-policy.md` § Generated
  content, I14): over the 80-string population (T1) plus the one planted string (T2), assert
  `MathView.content(latex:)`'s rendered/fallback split matches `RenderCheck.parseError(latex:) == nil` /
  `!= nil` exactly, string for string — i.e. `MathView.content` is a pure re-expression of the one existing
  parser, never an independent renderability judgment. Also read `MathView.swift`'s import lines and assert
  they are exactly `import SwiftUI` and `import SwiftMath` — no `import Core` (I14).
- T5 (negative control for the "no second parser" guard): a private scan helper
  `usesOnlyRenderCheckAsParser(_ source: String) -> Bool` returns `false` iff `source` contains the
  substring `"MTMathListBuilder"` (the underlying SwiftMath parser `RenderCheck.parseError` itself wraps,
  `Rendering.swift:11`) anywhere outside `Rendering.swift`'s own file — applied to `MathView.swift`'s real
  source text, asserting `true` (no second, independent call to the underlying parser). Negative control:
  the same helper applied to a synthetic in-memory string containing a planted
  `_ = MTMathListBuilder.build(fromString: latex, error: &error)` line is asserted to return `false`,
  proving the guard is non-vacuous (following the planted-violation shape of
  `ImportBoundaryNegativeControlTests.swift`, cited for shape only, not copied).
- T6 (idempotency / no-leak): `MathView.content(latex:)` called twice with the same input (once with a
  renderable string from T1's population, once with T2's planted string) returns `Equatable`-equal results
  both times — no hidden state, no side effect, confirming the function is a pure derivation over its one
  `String` argument.

## §6 Decision defaults

- IF `Packages/Rendering/Package.swift` declares `platforms: [.iOS(.v18), .macOS(.v15)]` (verified,
  `Package.swift:10`) AND SwiftMath's `MTMathUILabel` is a `UIView` subclass only on iOS/visionOS, an
  `NSView` subclass elsewhere (`MTConfig.swift:11-30`, verified) THEN guard the `UIViewRepresentable`/
  `MTMathUILabel` branch of `MathView.body` with `#if canImport(UIKit)`, falling back to plain `Text(latex)`
  on any other platform — never a second, `NSViewRepresentable`-based rendering implementation, since the
  App target itself is iOS/iPadOS-only (`docs/tech-stack.md` § 1: deployment target iOS/iPadOS 18.0) and no
  macOS destination ever exercises that branch; this keeps the package's own stated macOS platform
  typecheck-clean without adding scope.
- IF a LaTeX string is intended to carry `render_fallback: "katex"` (arbiter-04 § Q-E ruling item 2) THEN no
  separate parameter is added to `MathView`/`MathView.content(latex:)` for this task, because such a string
  is by construction one `RenderCheck.parseError(latex:)` reports non-nil for (it was flagged precisely
  because SwiftMath cannot render it), so it already routes to `.fallback` without a second signal; `data/
  demo` carries zero `render_fallback` occurrences (verified this session), and wiring an explicit
  `render_fallback` parameter through to a KaTeX/WKWebView path is EPIC 09's work (brief § 7 item 4), out of
  scope here.
- IF the context bundle's §F says to modify `Packages/Rendering/Tests/RenderingTests/RenderingTests.swift`
  but this task's own scope (per the planner's dispatch) names a new file `MathViewTests.swift` THEN follow
  the explicit scope: create `MathViewTests.swift`; `RenderingTests.swift`'s existing two tests
  (`parsesKnownGood`, `reportsError`) stay untouched (AC8). This corrects a bundle-vs-scope mismatch, not a
  contract conflict — a Q1 (information), resolved in favour of the task's own file-scope instruction.
- IF `MathView.content(latex:)`'s return-type naming is otherwise undetermined (no contract or bundle names
  it) THEN name it exactly `MathViewContent` with cases `.rendered(latex: String)` / `.fallback(text:
  String)`, `Equatable`, consistent with `RenderCheckEntry`'s existing `latex`-field naming style in
  `RenderCheckReport.swift` (§3).
- IF a future call site (04.8/04.9) needs to decide which field routes through `MathView` (per `contracts/
  data-model.md` § Text and arbiter-04 § Q-E ruling item 4) THEN that routing decision is made at the call
  site, not inside `MathView` — `MathView` itself takes only a `latex: String` and has no knowledge of
  `ProbeItem.type` or field names; this task ships the view and entry point only. The answer-card
  display-kind flag itself (LaTeX vs. plain, so the App does not re-derive it from `item.type`, arbiter-04
  § Q-E item 4) is `Core`'s `DoorAnswerDisplayKind` / `DoorAnswerCardContent.correctAnswerDisplayKind`,
  **defined by task 04.2** (`tasks/epic-04-task-02-core-door-item-card-keypad.md`: "this task's
  `DoorAnswerDisplayKind` is the canonical name; a later task adapts to it, not the reverse") and consumed by
  the 04.8/04.9 call sites, not by this task — this task neither defines nor references that flag.
- IF a call site outside this task (04.8/04.9) needs `App/Sources/ContentView.swift` or
  `App/Sources/MathmathApp.swift` edited to wire `MathView` into a Door screen THEN that edit belongs to
  04.8/04.9, per `docs/plans/epic-04-plan.md` ("04.8: ... It replaces 03.11's placeholder for Include and
  Unit expedition"; "04.9: ... It replaces the Check me here placeholder") — this task's file scope (§2)
  excludes every file under `App/Sources`.
- Standing defaults: no identifiers or timestamps are introduced (`MathView` persists nothing); no model
  call anywhere (Tier 0 only, I2 vacuous); no telemetry client; no identifying field anywhere; `MathView`
  never renders `paraphrase` or any Ministry-sourced text — those stay plain `Text` at call sites outside
  this task's scope.

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`swift-format lint --strict` over `Packages/Rendering/Sources/Rendering/MathView.swift`
  and `Packages/Rendering/Tests/RenderingTests/MathViewTests.swift`).
- typecheck clean (Swift's typecheck is the build: `swift build --package-path Packages/Rendering`).
- `Rendering` build + test green: `( cd Packages/Rendering && xcodebuild test -quiet -scheme Rendering
  -destination "$SIM" CODE_SIGNING_ALLOWED=NO )` (`scripts/gate.sh:19`), including the existing
  `OutcomeRecordAndImportBoundaryTests` (I14, AC7) and all other pre-existing Rendering test files (AC8),
  unmodified and still green.
- App build green: `xcodebuild build -quiet -workspace App/mathmath.xcworkspace -scheme mathmath
  -destination "$SIM" CODE_SIGNING_ALLOWED=NO` (`scripts/gate.sh:22`), confirming the App target still
  builds with `MathView` available from the already-linked `Rendering` product (AC6); this task makes no
  edit under `App/Sources`, so no App source file changes as part of this gate. `pytest` is not applicable —
  no `pipeline/` change in this task.
- tests green for every case in §5 (T1–T6).
- conforms to every contract section cited in §3 (`contracts/data-model.md` § Text,
  `contracts/content-policy.md` § Generated content) and to every invariant listed in §1.
