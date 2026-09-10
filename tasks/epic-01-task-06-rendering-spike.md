# Epic 01 · Task 06: Rendering spike

---
epic: 01
task: 06
slug: rendering-spike
kind: feat
risk: seam
depends_on: [01.5]
model: sonnet
arbitrated: 2026-09-09
---

## §1 Goal & acceptance criteria

Goal: run `Rendering.RenderCheck` over every LaTeX-bearing field of `data/demo/nodes.json` — `prompt_latex`,
`choices[].latex`, `worked_examples[].steps_latex[]`, each `hint_tree` tier string, and `explanation` —
resolve every parse failure by rewriting the LaTeX notation or setting `render_fallback: "katex"` on the
owning probe item, and record the outcome at `docs/epics/epic-01-rendering-spike-outcome.md`. The result is a
report with zero unresolved LaTeX strings, proof that the check can fail (a fixture that reports
`LO_ITEM_UNRENDERABLE`), and an outcome record whose item ids are all real ids in the shipped bundle.

The five-field enumeration above is the **broad enumeration**, fixed by §6's reconciliation clause. It is the
enumeration named by the EPIC brief §2 verbatim ("over every `prompt_latex`, hint, explanation and choice in
the bundle", §3) and it satisfies both `contracts/data-model.md` § Text and `contracts/content-policy.md` §
Generated content simultaneously. Do not narrow it.

Invariants in play:

- **I1** — `RenderCheck` is a deterministic SwiftMath parse, never a model judgement; this task adds no
  model call anywhere (`contracts/ai-usage.md`: no model anywhere in EPIC 01).
- **I6** — this task touches `data/demo/nodes.json` only to change LaTeX notation inside `latex`-named fields
  and `render_fallback` values; it **reads but never edits** `hint_tree`, `explanation`, `paraphrase`, `name`
  or any other prose field. Scanning a prose field is not licence to rewrite it: see §6's STOP clause.
- **I11** — every count the outcome record states (strings scanned, failures found, fixes applied) carries
  `[SOURCED: …]` or `[ESTIMATE: …]`; no time estimate appears anywhere in the record.
- **I14** — `RenderCheck` and `RenderCheckReport` live in `Packages/Rendering`, which imports SwiftMath and
  Foundation only; `Core` gains no new import and this task touches no file under `Packages/Core`; the
  bundle-scanning code added in `RenderCheckReport.swift` decodes only the LaTeX-bearing shape it needs
  (its own private `Decodable` mirror), not a second copy of `Core`'s `Node` model and not a dependency on
  `Core`.
- **I15** — not substantively engaged: this task's file scope excludes `data/demo/landmarks.json`; the one
  landmark's `source_url` presence/resolution is authored by task 01.5 and verified by task 01.7.

Acceptance criteria (each independently verifiable):

- AC1 (brief §4.6): `xcodebuild test -scheme Rendering` on the simulator is green; the enumeration walks the
  broad five-field set over `data/demo/nodes.json` and `report.unresolvedCount == 0`.
  Instrument: `RenderCheckReport.scanning(nodesJSON:)` over the real on-disk bundle, asserted in
  `BundleRenderCheckTests.swift`. It excludes every other `data/demo/*.json` file (§2) and excludes
  `nodes[].name`, `nodes[].paraphrase` and `probe_items[].why` (§3, excluded-fields list).
  Emptiness policy, per field kind, grounded in §3's arbiter-verified bundle census:
  - `entries.count > 0` — **empty = FAIL**. Assert this *before* `unresolvedCount == 0`, so a zero-entry
    scan cannot pass silently.
  - at least one entry with `field == "prompt_latex"` — **empty = FAIL** (census: 40 present).
  - at least one entry whose `field` begins `choices[` — **empty = FAIL** (census: 40 present).
  - at least one entry whose `field` begins `hint_tree[` — **empty = FAIL** (census: 63 present). This is the
    assertion that makes the broadening load-bearing rather than decorative.
  - entries with `field` beginning `steps_latex[` — **empty = PASS** (census: 0; `worked_examples` is absent
    from every node in the landed bundle). Code coverage for this path comes from AC2b, not from real data.
  - entries with `field == "explanation"` — **empty = PASS** (census: 0; `explanation` is an optional field
    and is absent from every node in the landed bundle). Code coverage comes from AC2b.
  No hard-coded total-entry count is asserted — see §6.
- AC2 (brief §5, learning-objects row): a deliberately unrenderable fixture LaTeX string (no
  `render_fallback`) is reported as unresolved, and calling the throwing check on it throws
  `RenderingError.loItemUnrenderable(itemId:)` carrying the offending item id — the code this mirrors is
  registered in `contracts/error-codes.json:32` as `LO_ITEM_UNRENDERABLE` (`recoverable: true, surface:
  internal, user_text: null`) and in `docs/domains/learning-objects.md:129`. This proves the check can fail,
  not just pass. Instrument: an in-memory JSON `Data` fixture, not the real bundle.
- AC2b (emission coverage for the field kinds the real bundle does not exercise): an in-memory JSON `Data`
  fixture containing one node that carries `explanation`, a two-key `hint_tree`, and a `worked_examples`
  entry with two `steps_latex` strings produces exactly the entries §4 step 3 specifies — right `itemId`,
  right `field`, `hasFallback == false` on all of them, and in the emission order §4 step 3 pins.
  Instrument: the same `scanning(nodesJSON:)` entry point. Empty = FAIL (the fixture is authored to be
  non-empty; a zero-entry result is a defect).
- AC3: every item id named in `docs/epics/epic-01-rendering-spike-outcome.md`'s affected-items table
  resolves to a real `itemId` produced by a fresh scan of `data/demo/nodes.json`, asserted by a test that
  parses the table and cross-checks it — not eyeballed. Instrument: the AC3 test case; it excludes any claim
  about the table being complete (it guards against stale/invented ids only).
- AC4: the two existing cases in `Packages/Rendering/Tests/RenderingTests/RenderingTests.swift`
  (`parsesKnownGood`, `reportsError`) stay green, unmodified.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `Packages/Rendering/Sources/Rendering/Rendering.swift` — MODIFY. Add
  `RenderCheck.canRender(latex:) -> Bool`; the existing `parseError(latex:)` is unchanged (do not
  re-declare or rewrite it — extend the enum).
- `Packages/Rendering/Sources/Rendering/RenderCheckReport.swift` — CREATE. `RenderingError`,
  `RenderCheckEntry`, `RenderCheckReport`, the bundle-scanning function, and the throwing
  all-resolved assertion (exact shapes in §4).
- `Packages/Rendering/Tests/RenderingTests/BundleRenderCheckTests.swift` — CREATE. The spike's own test
  suite: AC1 (scan the real bundle), AC2 (fixture proving failure), AC2b (emission coverage), AC3
  (outcome-record id cross-check).
- `docs/epics/epic-01-rendering-spike-outcome.md` — CREATE. The outcome record (exact shape in §4 step 6).
- `data/demo/nodes.json` — MODIFY. LaTeX notation rewrites **inside `prompt_latex`, `choices[].latex` and
  `worked_examples[].steps_latex[]` only**, and `render_fallback` value changes — never an answer, a tag, an
  id, a paraphrase, a name, a `why`, a `hint_tree` string, an `explanation`, a node, or the node set. This
  file already exists (authored by task 01.5); this task amends it in place. Per §3's census, the expected
  number of edits to this file is **zero**; a non-zero edit set is legitimate only if the scan actually
  reports an unresolved entry in one of the three `latex`-named field kinds.

Out-of-scope (do not touch even if tempted):

- `Packages/Rendering/Package.swift` — no dependency change; `RenderCheckReport.swift`'s bundle decoding
  uses a private, minimal `Decodable` mirror of only the fields it scans, precisely so `Rendering` need not
  depend on `Core` (I14) and this file need not be touched.
- `Packages/Rendering/Tests/RenderingTests/RenderingTests.swift` — the two existing cases stay as they are;
  the new suite is a separate file (`BundleRenderCheckTests.swift`), not an addition to this one.
- `Packages/Core/**` — this task adds no `Core` dependency and no `Core` change.
- Any file under `App/Sources/**` — `MathView` and any rendering UI are EPIC 03's; this task ships
  `RenderCheck` and its report only.
- `data/demo/manifest.json`, `data/demo/regions.json`, `data/demo/edges.json`, `data/demo/courses.json`,
  `data/demo/landmarks.json`, `data/demo/sources.json` — no LaTeX-bearing field exists in any of these
  (verified: none of their schemas define a `latex`/`prompt_latex`/`steps_latex`/`hint_tree`/`explanation`
  field); this task's data edits are confined to `nodes.json`.
- Any eighth file under `data/**` — the outcome record is NOT a bundle file and does not go under `data/**`
  (see §3, §6): `pipeline/tests/test_contracts.py::test_data_bundles_validate` resolves a schema by filename
  stem for every `*.json` under `data/**` and fails on any name with no matching schema.
- `contracts/**` — read-only ground truth; never edited. The contract divergence recorded in §6 is NOT
  resolved by this task and no contract text is touched to make it go away.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rules — **both of the following bind this task; §6 states how they compose**:

- `contracts/data-model.md` § Text (`:36-37`):
  > All student-facing strings are English (DEFERRED D-1). LaTeX appears only in fields named `latex` or
  > `prompt_latex` and must be in the SwiftMath-renderable subset or carry `render_fallback: "katex"`.

- `contracts/content-policy.md` § Generated content (`:29-30`):
  > Probe answers are re-derived by SymPy before persistence (I1); prompts and hints must render in SwiftMath
  > or carry `render_fallback: "katex"` (learning-objects W1 5b).

- `contracts/content-policy.md` § Enforcement (excerpt on rendering):
  > wrap-epic (f): no `verbatim` key in `data/**`, `contracts/examples/**`, fixtures; every node has
  > `paraphrase`; every landmark has `source_url`; `official_url` host allow-list; `[SOURCED]/[ESTIMATE]`
  > presence on touched docs.

- `contracts/error-codes.md` § Rules (excerpt on code registration):
  > A code appears in exactly one domain doc and in the registry.

- `contracts/error-codes.json:32`:
  ```json
  {"code": "LO_ITEM_UNRENDERABLE", "recoverable": true, "surface": "internal", "user_text": null},
  ```

- `docs/domains/learning-objects.md:81-82` (Workflow W1, step 5b) — the rule
  `contracts/content-policy.md` § Generated content cross-references:
  > 5b. **Renderability** — every prompt, hint and explanation renders in SwiftMath, or is flagged for the
  > KaTeX fallback per item, else `LO_ITEM_UNRENDERABLE`.

- `docs/domains/learning-objects.md:129` (Errors produced):
  > | `LO_ITEM_UNRENDERABLE` | Prompt, hint or explanation fails SwiftMath and is not flagged for fallback |
  > Internal (rendering-spike report) | Yes — rewrite notation or flag |

- `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:20-22` (EPIC §2 In scope) — **the scan-scope
  mandate for this task**:
  > the **rendering spike** (v2.2 §B): `Rendering.RenderCheck` over every
  > `prompt_latex`, hint, explanation and choice in the bundle, failures listed, each resolved by rewriting the
  > notation or setting `render_fallback: "katex"`, outcome recorded.

- `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:29` (EPIC §3):
  > `contracts/data-model.md` — every section; the JSON Schemas in `contracts/schemas/` are normative. `READ-ONLY`.

- `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:79-80` (EPIC §4 criterion 6):
  > 6. The rendering spike reports zero unresolved items: every LaTeX string in `data/demo` parses in
  > SwiftMath or carries `render_fallback`; the outcome file lists what was rewritten.

- `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:147-154` (amendment 01.05.1, outcome-record
  location):
  > The **L0 report is not a bundle file and is not committed**: it is `core-cli validate` **stdout**, JSON,
  > in the shape fixed by `contracts/graph-constraints.md` § Report shape; the pipeline wrapper parses it
  > in-process and fails the build on `passed: false`. Nothing other than a schema-named bundle file may be
  > written under `data/**` (`contracts/data-model.md` § Enforcement: every `*.json` under `data/**`
  > validates against the schema its filename names).

- `docs/plans/epic-01-task-plan.md` planner note [3], verbatim:
  > **Shared-file ordering.** `data/demo/nodes.json` is written by 01.5, then amended by 01.6 (notation /
  > `render_fallback`) and 01.7 (answer or tag corrections). These three are strictly sequential and must
  > never be dispatched concurrently. This is the plan's only shared-write path.

  Status at arbitration (verified 2026-09-09): 01.5 has landed — `data/demo/nodes.json` exists on `main`.
  01.7 has **not** landed — no `tasks/epic-01-task-07-*.md` spec file exists. This task is therefore the
  sole current writer of `data/demo/nodes.json`; the sequencing constraint is satisfied and unaffected by
  the broadening in §6.

- `docs/plans/epic-01-task-plan.md` planner note [12], verbatim:
  > **Scope redistribution vs §8.** `Core`'s `validate` stays exactly L0-1 … L0-10 — no LO-prefixed checks
  > are bolted into the L0 report. Renderability (`LO_ITEM_UNRENDERABLE`) goes to 01.6 (`Rendering`);
  > distractor tags, SymPy re-derivation and landmark resolution go to 01.7 (pipeline), per
  > `docs/tech-stack.md` §2 ownership.

Schema fields this task's enumeration is grounded in — read directly from `contracts/schemas/nodes.schema.json`
(verified, path:line):

```json
// nodes.schema.json:240-243 — probe_items[].prompt_latex (required on every probe item)
"prompt_latex": {
  "type": "string",
  "minLength": 1
},
```
```json
// nodes.schema.json:248-253 — probe_items[].render_fallback (single-value enum; sibling of prompt_latex
// and choices, i.e. one flag per probe item, not per LaTeX string). THIS IS THE ONLY OCCURRENCE OF
// render_fallback IN THE WHOLE SCHEMA (verified by grep: one match, at :248).
"render_fallback": {
  "type": "string",
  "enum": [
    "katex"
  ]
},
```
```json
// nodes.schema.json:301-304 — probe_items[].choices[].latex (mc items only)
"latex": {
  "type": "string",
  "minLength": 1
},
```
```json
// nodes.schema.json:170-177 — worked_examples[].steps_latex[] (optional field; no render_fallback sibling
// exists anywhere in this object — worked_examples has only "id" and "steps_latex")
"steps_latex": {
  "type": "array",
  "items": {
    "type": "string",
    "minLength": 1
  },
  "minItems": 1
},
```
```json
// nodes.schema.json:157-160 — nodes[].explanation (optional, plain string, no render_fallback sibling)
"explanation": {
  "type": "string",
  "minLength": 1
},
```
```json
// nodes.schema.json:212-223 — nodes[].hint_tree: a required object keyed by error_type id, each value
// EXACTLY three tier strings. No render_fallback sibling anywhere inside it.
"hint_tree": {
  "type": "object",
  "additionalProperties": {
    "type": "array",
    "items": {
      "type": "string",
      "minLength": 1
    },
    "minItems": 3,
    "maxItems": 3
  }
},
```
```json
// nodes.schema.json:375 — the node object is closed, so a render_fallback key CANNOT be added at node
// level to cover hint_tree or explanation. This is why those two field kinds are rewrite-only (§6).
"additionalProperties": false,
```
```json
// nodes.schema.json:191-193 — error_types[].id pattern; hint_tree's keys are these ids. Kebab-case, so
// they can never contain an underscore. Relevant to the decoder's key strategy (§4 step 3).
"id": {
  "type": "string",
  "pattern": "^[a-z0-9]+(-[a-z0-9]+)*$"
},
```

Excluded fields — confirmed by direct read of `contracts/schemas/nodes.schema.json` to be plain prose that no
contract requires to render: `nodes[].name` (`:20-23`, plain string), `nodes[].paraphrase` (`:152-156`,
≤140-char plain prose, I6), `nodes[].probe_items[].why` (`:244-247`, a one-line plain-text justification
shown with the answer per I3). Neither `contracts/data-model.md` § Text nor
`contracts/content-policy.md` § Generated content nor the EPIC brief §2 names any of these three; they stay
out of the scan.

**Arbiter-verified census of the landed bundle** (`data/demo/nodes.json` as on `main` at commit `7f7000d`,
counted by direct read of the file on 2026-09-09 — this is the reference the implementer sanity-checks the
first scan against; it is NOT asserted as a literal in any test, see §6):

| Field kind | Entries | Note |
|---|---|---|
| `prompt_latex` | 40 `[SOURCED: direct read of `data/demo/nodes.json`]` | 20 nodes × 2 probe items |
| `choices[].latex` | 40 `[SOURCED: direct read of `data/demo/nodes.json`]` | the `mc` item of each node has 2 choices |
| `worked_examples[].steps_latex[]` | 0 `[SOURCED: direct read of `data/demo/nodes.json`]` | the key `worked_examples` occurs zero times in the file |
| `hint_tree` tier strings | 63 `[SOURCED: direct read of `data/demo/nodes.json`]` | 21 tiers × 3 strings (19 nodes with 1 tier, `exponential-functions` with 2) |
| `explanation` | 0 `[SOURCED: direct read of `data/demo/nodes.json`]` | the key `explanation` occurs zero times in the file |
| **Total (broad enumeration)** | **143** | narrow enumeration would have been 80 |
| Existing `render_fallback` keys | 0 `[SOURCED: direct read of `data/demo/nodes.json`]` | |

**Why broadening cannot spuriously red the build** (verified, and the reason §6's resolution is safe): after
JSON decoding, no `hint_tree` string in the landed bundle contains a backslash, `{`, `}`, `&`, `%`, `$` or
`#` — the hint text is ASCII prose with plain-text math such as `2 + 3 x 4`, `x^2`, `log_2(8)`, `sqrt(x-3)`,
`x >= 3` (the `\/` sequences visible in the raw file are JSON-escaped forward slashes and decode to `/`).
SwiftMath's builder **silently skips characters it does not recognise** rather than erroring:

```swift
// Packages/Rendering/.build/checkouts/SwiftMath/Sources/SwiftMath/MathRender/MTMathListBuilder.swift:301-306
} else {
    atom = MTMathAtomFactory.atom(forCharacter: char)
    if atom == nil {
        // Not a recognized character
        continue
    }
}
```

Its error paths (`setError`, same file) are reached only by unknown backslash commands, mismatched or
missing braces, `\left`/`\right`/`\begin`/`\end` imbalance and invalid delimiters — none of which any prose
field in the landed bundle can trigger. Prose punctuation (`?`, `:`, `,`, `.`, `'`) is skipped or accepted,
never an error.

Prior signature this task extends (verbatim, `Packages/Rendering/Sources/Rendering/Rendering.swift:7-14`,
confirmed by direct read):

```swift
public enum RenderCheck {
    /// Returns nil when SwiftMath parses `latex` without error, else the parser's message.
    public static func parseError(latex: String) -> String? {
        var error: NSError?
        _ = MTMathListBuilder.build(fromString: latex, error: &error)
        return error?.localizedDescription
    }
}
```

Existing test suite this task must not modify (verbatim, `RenderingTests.swift:1-16`, confirmed by direct
read):

```swift
import Testing

@testable import Rendering

@Suite("Rendering package")
struct RenderingTests {
    @Test("SwiftMath parses a quadratic-formula fragment")
    func parsesKnownGood() {
        #expect(RenderCheck.parseError(latex: #"x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}"#) == nil)
    }

    @Test("SwiftMath reports an unbalanced brace")
    func reportsError() {
        #expect(RenderCheck.parseError(latex: #"\frac{1"#) != nil)
    }
}
```

Gate 3 command (`scripts/gate.sh:19`, verbatim):
> `( cd "$ROOT/Packages/Rendering" && xcodebuild test -quiet -scheme Rendering -destination "$SIM"
> CODE_SIGNING_ALLOWED=NO )`

## §4 Implementation outline

1. **Precondition.** Confirm `data/demo/nodes.json` exists (task 01.5's output). If it is absent, this is a
   blocking-dependency gap — stop and report it; do not invent bundle content or a placeholder file.

2. **Extend `Rendering.swift` (① / layer-neutral utility).** Add, inside the existing `RenderCheck` enum
   (do not re-declare the enum or `parseError`):
   ```swift
   /// True when `latex` parses without error under SwiftMath's builder.
   public static func canRender(latex: String) -> Bool {
       parseError(latex: latex) == nil
   }
   ```

3. **Create `RenderCheckReport.swift` (③ learning-objects static validation, in `Packages/Rendering`).**
   Shape:
   - `public enum RenderingError: Error, Equatable { case loItemUnrenderable(itemId: String) }` — mirrors
     `LO_ITEM_UNRENDERABLE` (`contracts/error-codes.json:32`) for this package's own surface, since
     `Rendering` does not import `Core` and therefore cannot reuse `CoreError` (`contracts/error-codes.md` §
     Rules: "the App and the pipeline each map their own" — `Rendering` does the same for its own domain).
   - `public struct RenderCheckEntry: Equatable` with `itemId: String`, `field: String`, `latex: String`,
     `parsed: Bool`, `hasFallback: Bool`, and computed `resolved: Bool { parsed || hasFallback }`.
   - `public struct RenderCheckReport: Equatable` wrapping `entries: [RenderCheckEntry]`, with computed
     `unresolvedEntries: [RenderCheckEntry]` and `unresolvedCount: Int`.
   - A private, minimal `Decodable` mirror of only the fields being scanned:
     `BundleNodesFile { nodes }` → `BundleNode { id, explanation?, hintTree?, workedExamples?, probeItems }`
     → `BundleProbeItem { id, promptLatex, renderFallback?, choices? }` /
     `BundleWorkedExample { id, stepsLatex }` / `BundleChoice { id, latex }`, with
     `hintTree: [String: [String]]?`. Decode with `JSONDecoder` and
     `keyDecodingStrategy = .convertFromSnakeCase`, for property-mapping consistency with `Core`'s own
     `CoreCoding.decoder` convention. This is a deliberately partial decode, not a second `Node` model
     (I14: `Core`'s type is the single source; this mirror exists only because `Rendering` must not depend
     on `Core`). `hint_tree` is decoded as `[String: [String]]` and typed optional purely for decoder
     robustness — the schema makes it required (`nodes.schema.json:372`).
   - `public static func scanning(nodesJSON data: Data) throws -> RenderCheckReport` — decodes the bundle and
     emits entries. **Emission order is pinned** (T6 depends on it): nodes in array order, and within each
     node, in this order:
     1. `explanation`, if present — one entry. `itemId: "<node id>.explanation"`, `field: "explanation"`,
        `hasFallback: false` **always**.
     2. `hint_tree` — iterate its keys via `keys.sorted()` (lexicographic ascending; a Swift `Dictionary`
        has no stable natural order, so sorting is what makes T6 hold), then each tier string by array
        index. `itemId: "<node id>.hint_tree.<error type id>"`, `field: "hint_tree[<index>]"` with
        `<index>` in `0…2`, `hasFallback: false` **always**.
     3. `worked_examples[]` in array order, each `steps_latex[]` string by index.
        `itemId: "<node id>.worked_examples.<example id>"`, `field: "steps_latex[<index>]"`,
        `hasFallback: false` **always**.
     4. `probe_items[]` in array order; for each item, first one entry for `prompt_latex`
        (`field: "prompt_latex"`, `itemId: "<node id>.probe_items.<item id>"`,
        `hasFallback: (item.renderFallback == "katex")`), then one entry per `choices[]` element in array
        order (`field: "choices[<choice id>].latex"`, same `itemId`, same `hasFallback` — the schema attaches
        `render_fallback` once per probe item, covering that item's prompt and all its choices together, not
        one flag per string).

     `hasFallback` is `false` unconditionally for `explanation`, `hint_tree` and `worked_examples` because
     `render_fallback` occurs exactly once in the entire schema, inside the probe-item object
     (`nodes.schema.json:248`), and the node object is closed (`nodes.schema.json:375`) — there is no
     schema-legal place to put a fallback flag for those three field kinds. See §6.
   - `parsed` on every entry is `RenderCheck.canRender(latex:)` applied to the string.
   - `public func assertAllResolved() throws` on `RenderCheckReport` — throws
     `RenderingError.loItemUnrenderable(itemId:)` naming the first unresolved entry's `itemId` if
     `unresolvedEntries` is non-empty, else returns normally.

4. **Run the scan against the real bundle** (as part of authoring, via the test in step 7, or a scratch
   invocation) to find every currently-unresolved entry in `data/demo/nodes.json`. Sanity-check the totals
   against §3's census (expected 143 entries, 0 unresolved); a materially different count means the decode
   or the emission is wrong, not that the census is stale.

5. **Resolve every failure** found in step 4. The permitted resolution depends on the field kind:
   - `prompt_latex` or `choices[].latex` — rewrite the LaTeX notation in place (preferred, when a
     straightforward SwiftMath-renderable equivalent exists), or add `"render_fallback": "katex"` to the
     owning probe item.
   - `worked_examples[].steps_latex[]` — rewrite the notation only. `render_fallback` is not schema-legal on
     a `worked_examples` entry, so flagging is not available.
   - `hint_tree` tier string or `explanation` — **neither rewrite nor flag: STOP and report** (§6). These
     are student-facing prose authored by task 01.5, outside this task's data-edit mandate (§2), and no
     schema-legal fallback flag exists for them. Per §3's census this cannot fire on the landed bundle; if
     it does fire, the contract divergence recorded in §6 has become real and needs a human.
   No other key in `nodes.json` changes (no answer, tag, id, paraphrase, name, `why`, or node
   added/removed).

6. **Write `docs/epics/epic-01-rendering-spike-outcome.md`.** Required shape: a short lead paragraph stating
   the total LaTeX-bearing entries scanned, the per-field-kind breakdown, and the unresolved count after
   fixes (`0`), each number tagged `[SOURCED: …]` (counted directly from the scan, not estimated); a
   one-line statement that the broad five-field enumeration of §6 was used; then an "Affected items" table
   with columns `Item id | Field | Action | Reason`, one row per entry that was rewritten or flagged (empty
   table — zero rows — is valid and must still be printed if no fixes were needed, per the C3
   empty-list-printed convention this EPIC uses elsewhere).
   `Action` is a closed vocabulary of exactly two values:
   - `rewritten-notation` — legal for `prompt_latex`, `choices[].latex`, `steps_latex[<index>]`.
   - `flagged-katex` — legal for `prompt_latex` and `choices[<id>].latex` **only**; never for
     `steps_latex[<index>]`, `hint_tree[<index>]` or `explanation`.
   A row whose `Field` is `hint_tree[<index>]` or `explanation` is not writable: such an entry triggers the
   step-5 STOP instead.
   Every `Item id` value MUST be exactly one of the `itemId` strings `RenderCheckReport.scanning` produces,
   so AC3's test can parse the table and cross-check it against a fresh scan.

7. **Write `BundleRenderCheckTests.swift`.** Four cases, `import Testing`, `@testable import Rendering`
   (Swift Testing, matching the existing suite's framework):
   - AC1 case: load `data/demo/nodes.json` from disk (resolve its path by walking up from `#filePath`:
     `Tests/RenderingTests/BundleRenderCheckTests.swift` → `Tests/RenderingTests/` → `Tests/` → `Rendering/`
     → `Packages/` → repo root — five `deletingLastPathComponent()` calls from the file URL — then append
     `data/demo/nodes.json`), call `RenderCheckReport.scanning(nodesJSON:)`, then assert, in this order:
     `#expect(report.entries.count > 0)` (anti-vacuity), the three empty=FAIL field-kind coverage
     assertions of AC1 (`prompt_latex`, `choices[`, `hint_tree[`), then
     `#expect(report.unresolvedCount == 0)`.
   - AC2 case: build an in-memory JSON `Data` fixture for a single node with one `probe_items` entry whose
     `prompt_latex` is deliberately unbalanced (e.g. `#"\frac{1"#`) and no `render_fallback`; scan it,
     `#expect` the entry is unresolved, then `#expect(throws: RenderingError.loItemUnrenderable(itemId:
     "fixture-node.probe_items.fixture-item"))` from `report.assertAllResolved()`.
   - AC2b case: build an in-memory JSON `Data` fixture for a single node `fixture-node` carrying
     `explanation`, a `hint_tree` with two keys (choose keys whose sorted order differs from their literal
     order in the JSON, so the `keys.sorted()` requirement is actually proved), and one `worked_examples`
     entry with two `steps_latex` strings, plus one minimal renderable `probe_items` entry. Assert the
     produced `entries` — `itemId`, `field`, `hasFallback` and order — equal the expected array exactly,
     per step 3's pinned emission order. All non-probe entries must have `hasFallback == false`.
   - AC3 case: read `docs/epics/epic-01-rendering-spike-outcome.md` (same `#filePath`-relative path
     resolution as the AC1 case), extract every backticked `Item id` value from the "Affected items" table
     rows via a table-row parse (split on `|`, first cell), and assert each one is a member of the set of
     `itemId` values from a fresh `RenderCheckReport.scanning` of the real bundle — an empty table passes
     vacuously (nothing to cross-check), which is correct: the guarantee is "no id in the record is stale or
     invented," not "the record is non-empty."

8. Smoke check: `swift test --package-path Packages/Rendering` — must be green, before running the full
   simulator gate.

## §5 Test plan (seam risk — full plan)

- T1 happy path: `RenderCheckReport.scanning(nodesJSON:)` over the real `data/demo/nodes.json` returns
  `entries.count > 0`, at least one entry for each of the three field kinds present in the bundle
  (`prompt_latex`, `choices[`, `hint_tree[` — empty = FAIL each), and `unresolvedCount == 0` (AC1).
  Reference values from §3's census: 143 entries total, 40 / 40 / 0 / 63 / 0 by field kind.
- T2 negative — invalid input rejected at the boundary: the AC2 fixture (an unresolved, un-flagged
  unrenderable `prompt_latex`) is reported as unresolved by `scanning`, proving the scan does not silently
  pass a bad string.
- T3 error-taxonomy: `report.assertAllResolved()` on the AC2 fixture throws exactly
  `RenderingError.loItemUnrenderable(itemId:)` with the fixture's item id — the mirrored code is
  `LO_ITEM_UNRENDERABLE` (`contracts/error-codes.json:32`).
- T4 conformance per requirements §B.1 (EPIC §5, learning-objects row: "renderability
  (`LO_ITEM_UNRENDERABLE` via `RenderCheck`)"): AC1's real-bundle scan IS this conformance check, run over
  real data, not a synthetic composition — this is the C1-style real-composition proof for the
  learning-objects renderability requirement, and with the broad enumeration it now covers the "hint and
  explanation" half of `docs/domains/learning-objects.md:81-82`'s W1 5b, not just the prompt half. I14's
  boundary is satisfied by construction: `Rendering`'s `Package.swift` is untouched (out of scope, §2) and
  `RenderCheckReport`'s decode is a private mirror, not a `Core` import.
- T5 negative control for the AC3 regression guard: the implementer PROVES it is load-bearing by
  temporarily planting one invented `Item id` (naming a node/item pair that does not exist in
  `data/demo/nodes.json`) in a scratch copy of the outcome record and confirming the AC3 test reds, then
  reverting before commit — recorded in the PR description, not shipped as a permanent fixture.
- T5b negative control for the AC1 field-kind coverage guard: the implementer PROVES the `hint_tree[`
  coverage assertion is load-bearing by temporarily commenting out the `hint_tree` emission branch in
  `scanning` and confirming the AC1 test reds on that assertion (not merely on the total count), then
  restoring it — recorded in the PR description. Without this, a silently-dropped broad branch would still
  pass AC1 on `prompt_latex` entries alone.
- T6 idempotency / no-leak: re-running `RenderCheckReport.scanning(nodesJSON:)` twice over the same
  unmodified `data/demo/nodes.json` bytes produces byte-for-byte equal `entries` arrays (pure function, no
  side effect, no I/O beyond the one read already performed by the caller). This is the assertion that
  `hint_tree`'s `keys.sorted()` exists to satisfy — dictionary iteration order is not stable across runs.
- T7 emission coverage for the field kinds real data does not exercise (AC2b): the synthetic node fixture
  produces exactly the expected `explanation`, `hint_tree` and `steps_latex` entries, in the pinned order,
  all with `hasFallback == false`. Empty = FAIL.

## §6 Decision defaults

**Reconciliation clause (the arbitrated resolution — this replaces the prior narrow-enumeration default).**

Two ground-truth rules both bind this task and appear to disagree about which fields the spike scans:

> `contracts/data-model.md` § Text: "All student-facing strings are English (DEFERRED D-1). LaTeX appears
> only in fields named `latex` or `prompt_latex` and must be in the SwiftMath-renderable subset or carry
> `render_fallback: "katex"`."

> `contracts/content-policy.md` § Generated content: "Probe answers are re-derived by SymPy before
> persistence (I1); prompts and hints must render in SwiftMath or carry `render_fallback: "katex"`
> (learning-objects W1 5b)."

The first is a **field-naming** rule and, read as a scan boundary, yields the narrow set
(`prompt_latex`, `choices[].latex`, `worked_examples[].steps_latex[]`). The second names **hints**
explicitly and, with the rule it cross-references (`docs/domains/learning-objects.md:81-82`, "every prompt,
hint and explanation renders in SwiftMath"), yields the broad set, which adds each `hint_tree` tier string
and `explanation`.

**Resolution: scan the broad set.** Authority and reasoning, in order:

1. The **EPIC brief §2** (`docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:20-22`) states this task's
   scan scope in so many words: "`Rendering.RenderCheck` over every `prompt_latex`, hint, explanation and
   choice in the bundle". That is the broad set, and it is this task's mandate. Any spec narrowing it
   contradicts its own EPIC brief.
2. The broad set is a **strict superset** of the narrow set, so scanning it cannot violate
   `contracts/data-model.md` § Text: that rule constrains where LaTeX may *appear*, not where a checker may
   *look*. Checking a field that contains no LaTeX consumes the check and reports `parsed: true`; it removes
   no guarantee the narrow set provides.
3. On the landed bundle the two enumerations are **empirically equivalent in outcome**: §3's census shows
   zero LaTeX markup in `hint_tree`, and `explanation` is absent from every node; and SwiftMath's builder
   skips unrecognised characters rather than erroring
   (`MTMathListBuilder.swift:301-306`, quoted in §3), so ASCII prose with no backslash, brace or `&` cannot
   produce a parse failure. Broadening therefore adds 63 entries that all report `parsed: true` and changes
   no fix, no data edit and no acceptance outcome. It is safe to adopt now.

- IF a `worked_examples[].steps_latex[]` string fails to parse THEN it MUST be rewritten to a
  SwiftMath-renderable equivalent — `render_fallback` occurs exactly once in `nodes.schema.json` (`:248`,
  inside the probe-item object), so flagging is not schema-legal there.
- IF a `hint_tree` tier string or an `explanation` string fails to parse THEN it is **rewrite-only and
  out-of-mandate**: there is no schema-legal fallback flag for it (`render_fallback` exists only at
  `nodes.schema.json:248` inside the probe-item object, and the node object is closed at
  `nodes.schema.json:375`, so one cannot be added at node level), AND rewriting student-facing hint or
  explanation prose is outside this task's `data/demo/nodes.json` edit mandate (§2) and is task 01.5's
  authorship. The implementer STOPs and reports it as a Q4 rather than editing the prose or widening §2.
  Per §3's census this cannot fire on the landed bundle.
- IF the scan's total entry count must be asserted as a literal THEN it must not be: `data/demo/nodes.json`
  is amended again by task 01.7 (planner note [3], §3), whose answer and tag corrections may legitimately
  change the number of `error_types` and therefore of `hint_tree` tiers. AC1 asserts structural coverage
  (non-empty overall, plus the three empty=FAIL field-kind assertions) instead; §3's census is the
  implementer's sanity reference and the outcome record states the observed number `[SOURCED: …]`.
- IF `.convertFromSnakeCase` appears to threaten the `hint_tree` dictionary keys THEN it does not:
  `JSONDecoder`'s key strategy rewrites only keys containing `_`, and `hint_tree`'s keys are
  `error_types[].id` values constrained to kebab-case by `nodes.schema.json:191-193`
  (`^[a-z0-9]+(-[a-z0-9]+)*$`), which admits no underscore. The keys pass through unchanged and are safe to
  embed in `itemId`.
- IF `data/demo/nodes.json` has zero `worked_examples` entries or no `explanation` (both true of the landed
  bundle, §3) THEN the scan simply produces zero entries of those kinds — declared empty = PASS in AC1, with
  code coverage supplied by the AC2b fixture instead. This is not the AC1 anti-vacuity failure, which is
  about the overall entry count and about the three field kinds the bundle demonstrably does contain.
- IF the outcome record needs zero rows because every scanned string already parses cleanly THEN the
  "Affected items" table is still written, with a header row and no data rows, and the lead paragraph states
  the scanned/unresolved counts and the per-field-kind breakdown (all `[SOURCED: …]`) — an empty table is a
  valid, printed outcome, not an omission (C3 convention, consistent with the L0 report's
  empty-violation-lists-printed rule quoted elsewhere in this EPIC).
- IF `render_fallback` needs a value other than `"katex"` THEN there is no such value: the schema's enum is
  single-valued (`nodes.schema.json:248-253`, verified) and `contracts/data-model.md` § Text names only
  `"katex"`.

**Out of scope for this task — recorded, not resolved.** `contracts/content-policy.md` § Generated content
offers hints an escape hatch ("or carry `render_fallback: "katex"`") that
`contracts/schemas/nodes.schema.json` provides nowhere: `render_fallback` occurs only inside the probe-item
object (`:248`) and the node object is closed (`:375`). That divergence is real but does not block this task,
because on the landed bundle no hint fails and no fallback is needed. It is filed as an EPIC-01 wrap-ledger
item in `tasks/blocked/RESOLVED-arbiter-01-06-latex-enumeration.md` for task 01.8 and for the
generated-content EPICs (05–09), where hints become model-generated and the question stops being academic.
Resolving it would change contract text and is an owner decision; **no agent, including the implementer of
this task, may edit `contracts/**` to close it.**

Standing defaults: identifiers referenced in the outcome record and in `RenderCheckEntry.itemId` are the
bundle's own existing kebab-case ids (`contracts/data-model.md` § Identifiers), never renumbered or
invented; no model call anywhere in this task (I1, `contracts/ai-usage.md`); telemetry is not touched by
this task; no identifying field is added anywhere (I5 — moot here, this task adds no new schema-governed
field); nodes keep their `paraphrase`, untouched by this task (I6).

## §7 Done definition

The task is done when ALL gates pass:

- format + lint clean (`swift-format lint --strict` over `Packages/Rendering`)
- typecheck clean (Swift's typecheck is the build: `swift build --package-path Packages/Rendering`)
- `Core` build + test green — unaffected, this task touches no `Core` file, but the boundary is confirmed
  by `Packages/Rendering/Package.swift` being unchanged (§2)
- `swift test --package-path Packages/Rendering` green (smoke check, §4 step 8)
- `xcodebuild test -scheme Rendering -destination "$SIM" CODE_SIGNING_ALLOWED=NO` green (gate 3,
  `scripts/gate.sh:19`), including both `RenderingTests.swift` cases (AC4) and the new
  `BundleRenderCheckTests.swift` cases (AC1, AC2, AC2b, AC3)
- `pytest pipeline/tests/test_contracts.py -k "data_bundles or verbatim"` still green after any `nodes.json`
  edit (no schema violation introduced, no `verbatim` key introduced). Per §3's census the expected edit set
  for `data/demo/nodes.json` is empty; the gate is run regardless.
- both negative controls (T5, T5b) exercised and recorded in the PR description
- tests green for every case in §5
- conforms to every contract section cited in §3 and §4, and to every invariant listed in §1
