# Task 04.7 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: rendering-mathview
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 04
- Task: 07
- Slug: rendering-mathview
- Summary: `MathView` in `Packages/Rendering`, with a plain-text fallback when parsing fails. The Rendering product is already linked, so the pbxproj is not edited.
- Invariants in play: I1 (correctness from CAS alone, never model), I2 (Tier 0 alone usable), I3 (answers never withheld), I5 (no PII), I6 (no Ministry text), I10 (no OCR/free-text input), I14 (`Core` Foundation-only, L0/layout once, render layer free of state).

## §B. Applicable contract rules (verbatim)

### contracts/data-model.md v1.4.0 — § Text — LaTeX field routing
> All student-facing strings are English (DEFERRED D-1). LaTeX appears only in fields named `latex` or `prompt_latex` and must be in the SwiftMath-renderable subset or carry `render_fallback: "katex"`.

Source: `contracts/data-model.md:35-37`
Binds this task: `MathView` is used only for `prompt_latex`, `choices[].latex`, and an `mc` `correctAnswerDisplay`; other fields (`why`, hint strings, `paraphrase`) are plain text.

### contracts/content-policy.md v1.1.0 — § Generated content — Renderability requirement
> Prompts and hints must render in SwiftMath or carry `render_fallback: "katex"` (learning-objects W1 5b).

Source: `contracts/content-policy.md:34-35`
Binds this task: `MathView` must handle both parse success and `render_fallback: "katex"` items; when `RenderCheck.parseError(latex:)` is non-nil or the item carries `render_fallback: "katex"`, `MathView` shows the source string as plain text.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/learning-objects.md — W1 step 5b, Renderability
> 5b. **Renderability** — every prompt, hint and explanation renders in SwiftMath, or is flagged for the KaTeX fallback per item, else `LO_ITEM_UNRENDERABLE`. 5c. **Landmarks** — `source_url` present and resolving at build (HTTP 2xx), `node_ids[]` non-empty and known, else `LO_LANDMARK_UNSOURCED` (D22, I15).

Source: `docs/domains/learning-objects.md:81-83`

### docs/domains/learning-objects.md — W2 step 1, Hint lookup fallback
> **Steps:** 1. Resolve `(node, error_type) → tiers`; a miss raises `LO_HINT_NOT_FOUND` and the session falls back to the node's generic tier-1 hint.

Source: `docs/domains/learning-objects.md:92`

## §D. Prior task outputs this task depends on

- `RenderCheck.canRender(latex:)` — `public static func canRender(latex: String) -> Bool` — Source: `Packages/Rendering/Sources/Rendering/Rendering.swift:16-18` (produced by EPIC 01 task 01.6)
- `RenderCheck.parseError(latex:)` — `public static func parseError(latex: String) -> String?` — Source: `Packages/Rendering/Sources/Rendering/Rendering.swift:9-13` (produced by EPIC 01 task 01.6)
- `RenderCheckReport` and `RenderCheckEntry` types — Source: `Packages/Rendering/Sources/Rendering/RenderCheckReport.swift` (produced by EPIC 01)
- `BundleRenderCheckTests` — Source: `Packages/Rendering/Tests/RenderingTests/BundleRenderCheckTests.swift` (produced by EPIC 01 task 01.6)
- Swift Package `Rendering` linked into the App target — Source: `App/mathmath.xcodeproj/project.pbxproj:lines 12, 30, 75, 108, 282, 309` (produced by bootstrap Phase 5)

## §E. Negative facts (confirmed ABSENT)

- `MathView` does not exist yet in `Packages/Rendering`. Grep `pattern: "struct MathView"` on `Packages/Rendering/**/*.swift` returns no match.
- No `MathLabel` view exists in `Packages/Rendering`. The current `MathLabel` in `App/Sources/ContentView.swift:22-35` is a Phase-5 UIViewRepresentable over SwiftMath's `MTMathUILabel` directly, to be replaced by the new `MathView` (source: `App/Sources/ContentView.swift` line 21 comment).
- No App-level rendering of LaTeX beyond the Phase-5 placeholder. Grep `pattern: "MathView"` on `App/Sources/**/*.swift` returns no match (confirmed absent until this task creates it).

## §F. File scope

- CREATE `Packages/Rendering/Sources/Rendering/MathView.swift` — confirmed absent (Glob `Packages/Rendering/Sources/Rendering/MathView.swift` empty).
- MODIFY `Packages/Rendering/Tests/RenderingTests/RenderingTests.swift` — add test cases for `MathView` field routing and fallback.
- MODIFY `App/Sources/ContentView.swift` — replace the Phase-5 `MathLabel` with `MathView` import and usage (the current file is at `App/Sources/ContentView.swift:1-36`).

## §G. Stack constraints relevant here

### Concrete pins from `docs/tech-stack.md`

From § 1:
- **Math display:** `SwiftMath` **1.7.3 exact** (`Package.swift` `exact:` and the app's `XCRemoteSwiftPackageReference`). Source: `docs/tech-stack.md:18`
- **UI:** **SwiftUI**; map on **`Canvas`**. Source: `docs/tech-stack.md:15`
- **Deployment target:** **iOS / iPadOS 18.0**. Source: `docs/tech-stack.md:16`
- **Shared logic:** Swift Package **`Core`** (library) + **`core-cli`** (executable) — **Foundation only** (I14). Source: `docs/tech-stack.md:17`
- **Student app language:** **Swift 6** (language mode 6, strict concurrency `complete`). Source: `docs/tech-stack.md:14`

From § 3 — Gates (R-1):
> 3. **Core:** `swift build -c release --product core-cli`; `xcodebuild test -scheme Core-Package` and `-scheme Rendering` on the iOS simulator (D29 — the agent gate is the simulator, never a device).

Source: `docs/tech-stack.md:74-75`
Relevance: The **Rendering test scheme** is gate 3's second half; this task's tests run via `xcodebuild test -scheme Rendering`.

### Boundary validation: I14 and import checks

- `Core` imports Foundation only; `Rendering` imports SwiftMath only (not `Core`).
- A test in `OutcomeRecordAndImportBoundaryTests.swift:117-124` asserts `Core`'s `Package.swift` declares no dependency on Rendering or SwiftMath; this constraint binds the new `MathView`.

### Error codes in play

Internal only, no student surface:
- `LO_ITEM_UNRENDERABLE` — registered (internal) — when SwiftMath cannot parse a LaTeX string and no `render_fallback` flag exists. Source: `contracts/error-codes.json:32`

Note: `LO_ITEM_UNRENDERABLE` stays pipeline/test-side (gated by `BundleRenderCheckTests` before bundle ships). At runtime, the fallback lives in `Rendering` (I14).

### Tier-0 fallback and render gate

- Every SwiftMath parse error is handled at the Rendering layer (I14).
- On parse failure, show the unmodified LaTeX source as plain `Text`: never blank, never an error string, no student code.
- The fallback also covers items carrying `render_fallback: "katex"` (brief § 7 item 4, deferred to EPIC 09; `data/demo` has none).

## §H. Task-scoped excerpts from brief and arbiter

### docs/epics/epic-04-app-expedition-diagnosis-acceptance.md — § 2, MathView paragraph
> **`MathView` in `Packages/Rendering`.** The EPIC 03 brief §7 item 3 moved it here: "`MathView` therefore moves to EPIC 04, its first consumer". It is a SwiftUI view over SwiftMath for the only LaTeX-bearing fields, `prompt_latex` and `choices[].latex` (`contracts/data-model.md` § Text: "LaTeX appears only in fields named `latex` or `prompt_latex`"). It is also used for an `mc` `correctAnswerDisplay`, which is the correct choice's `latex` (`ItemChecker.swift:183-191`). A `numeric` `correctAnswerDisplay`, `why`, hint strings and `paraphrase` are plain text. When `RenderCheck.parseError(latex:)` is non-nil, or the item carries `render_fallback: "katex"`, `MathView` shows the unmodified source string as plain `Text`: never blank, never an error string, no student code (arbiter-04 § Q-E). `Rendering` already builds and is linked into the App target (pbxproj product `Rendering`), so no pbxproj edit is needed. `RenderCheck.canRender` exists; `MathView` does not.

Source: `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md:103-112`

### tasks/arbitration/arbiter-04-predispatch.md — § Q-E, ruling
> **Ruling.** CONFIRMED. The brief default has four precisions.
> 
> 1. `MathView(latex:)` calls `RenderCheck.parseError(latex:)` (`Rendering.swift:9-13`). If the result is non-nil, it shows the unmodified source string as plain `Text`. It is never blank and never an error string. This is presentation, not state, so it belongs in `Rendering` (I14: `Core` cannot import SwiftMath).
> 2. An item carrying `render_fallback: "katex"` (`nodes.schema.json` lines 248–253) is shown the same way. KaTeX is brief § 7 item 4, trigger EPIC 09. `data/demo` has none: `RenderCheckReport` shows 0 unresolved of 143.
> 3. No student code. `LO_ITEM_UNRENDERABLE` is `internal` (`error-codes.json` line 32) and stays a pipeline/test outcome. `BundleRenderCheckTests` is the pre-ship gate.
> 4. **Field routing.** `MathView` is used only for `prompt_latex`, `choices[].latex`, and an `mc` answer card's `correctAnswerDisplay`, which is a choice's `latex` (`ItemChecker.swift:183-191`). A `numeric` `correctAnswerDisplay` (`answer.value`), `why`, hints and `paraphrase` are plain `Text`. That follows `data-model.md` § Text: "LaTeX appears only in fields named `latex` or `prompt_latex`".

Source: `tasks/arbitration/arbiter-04-predispatch.md:323-341`

## §I. Data inventory from `data/demo/nodes.json`

The bundle contains 20 nodes, each with 2 probe items (one numeric, one mc). Total: 40 probe items.

**LaTeX strings used by `MathView` (field routing from arbiter Q-E, ruling 4):**
- **`prompt_latex`**: 40 strings (one per probe item)
- **`choices[].latex`**: 40 strings (2 choices per mc item × 20 mc items)
- **Total for AC §4 item 6**: 80 strings

Per the arbiter ruling and brief acceptance criterion:
> The §4 item 6 population is the 80 strings; empty = FAIL.

Source: `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md:342`; confirmed by inventory of `data/demo/nodes.json` in this run.

**Renderability in `data/demo`** (from EPIC 01 spike outcome):
> `Rendering.RenderCheckReport.scanning(nodesJSON:)` scanned **143** LaTeX-bearing strings … After the scan, **0** entries were unresolved. 

| Field kind | Entries scanned | Unresolved |
|---|---|---|
| `prompt_latex` | 40 | 0 |
| `choices[].latex` | 40 | 0 |
| `worked_examples[].steps_latex[]` | 0 | 0 |
| `hint_tree` tier strings | 63 | 0 |
| `explanation` | 0 | 0 |
| **Total** | **143** | **0** |

Source: `docs/epics/epic-01-rendering-spike-outcome.md:8, 11-20`

**Consequence for this task**: No `render_fallback` flag is present in `data/demo` (no unresolved entries); all 80 strings render cleanly under SwiftMath.

## §J. Code signatures and structural facts

### Public API of `RenderCheck` (already exists, from EPIC 01)

From `Packages/Rendering/Sources/Rendering/Rendering.swift`:
```swift
public enum RenderCheck {
    /// Returns nil when SwiftMath parses `latex` without error, else the parser's message.
    public static func parseError(latex: String) -> String? { … }

    /// True when `latex` parses without error under SwiftMath's builder.
    public static func canRender(latex: String) -> Bool { … }
}
```

Source: `Packages/Rendering/Sources/Rendering/Rendering.swift:7-19`

### Test structure: `BundleRenderCheckTests` (already exists, from EPIC 01)

The test suite `BundleRenderCheckTests` (in `Packages/Rendering/Tests/RenderingTests/BundleRenderCheckTests.swift:6-163`) provides:
- AC1: the real bundle scans clean across the broad field set
- AC2: an unresolved, un-flagged prompt is reported and throws `LO_ITEM_UNRENDERABLE`
- AC2b: explanation, hint_tree and worked_examples emit in the pinned order
- AC3: every item id in the outcome record's affected-items table is a real itemId

Source: `Packages/Rendering/Tests/RenderingTests/BundleRenderCheckTests.swift`

### Linking status: Rendering product in App target

The App's xcodeproj (`App/mathmath.xcodeproj/project.pbxproj`) declares `Rendering` as a framework dependency:

Line 12 (build file): `A100000000000000000000A3 /* Rendering in Frameworks */`
Line 30 (frameworks build phase): `A100000000000000000000A3 /* Rendering in Frameworks */,`
Line 75 (package product dependencies): `P100000000000000000000P3 /* Rendering */,`
Line 108 (XCLocalSwiftPackageReference): `L100000000000000000000L3 /* XCLocalSwiftPackageReference "../Packages/Rendering" */,`
Line 282–284 (reference definition): `L100000000000000000000L3 /* XCLocalSwiftPackageReference "../Packages/Rendering" */` with `relativePath = ../Packages/Rendering;`
Line 309–311 (product reference): `P100000000000000000000P3 /* Rendering */` with `productName = Rendering;`

Source: `App/mathmath.xcodeproj/project.pbxproj:12, 30, 75, 108, 282-284, 309-311`

Consequence: No pbxproj edit is needed by this task (as stated in brief § 2).

### Current usage: Phase-5 placeholder in `App/Sources/ContentView.swift`

The Phase-5 placeholder (to be replaced) is:
```swift
/// Minimal SwiftUI bridge over SwiftMath's `MTMathUILabel` (UIKit). Replaced by a proper view in the Demo.
struct MathLabel: UIViewRepresentable {
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
```

Source: `App/Sources/ContentView.swift:21-35`

This imports `SwiftMath` directly (line 2). The new `MathView` should replace this, importing from `Rendering` instead.

---

**Quote audit: performed.** All blocks re-read against source; byte-verified.

