# Task 01.6 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-09
> Slug: epic-01-task-06-rendering-spike
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity
- Epic: 01
- Task: 06
- Slug: epic-01-task-06-rendering-spike
- Summary: Run `Rendering.RenderCheck` over every LaTeX string in `data/demo`, resolve each failure by rewriting the notation or setting `render_fallback: "katex"`, and record the outcome at `docs/epics/epic-01-rendering-spike-outcome.md`.
- Invariants in play: I1 (no model decides correctness), I6 (no verbatim Ministry text), I11 (all quantitative claims tagged), I14 (`Core` Foundation-only, render layer separate), I15 (landmarks real and sourced)

## §B. Applicable contract rules (verbatim)

### contracts/content-policy.md — Generated content
> Probe answers are re-derived by SymPy before persistence (I1); prompts and hints must render in SwiftMath or carry `render_fallback: "katex"` (learning-objects W1 5b).

Source: `contracts/content-policy.md:29-30`
Binds this task: specifies the exact rule this task executes — every LaTeX string must render or carry the fallback flag.

### contracts/content-policy.md — Enforcement (excerpt on rendering)
> wrap-epic (f): no `verbatim` key in `data/**`, `contracts/examples/**`, fixtures; every node has `paraphrase`; every landmark has `source_url`; `official_url` host allow-list; `[SOURCED]/[ESTIMATE]` presence on touched docs.

Source: `contracts/content-policy.md:49-51`
Binds this task: the wrap-epic step will audit the outcome record for quantitative claims tagged correctly.

### contracts/data-model.md — Text
> All student-facing strings are English (DEFERRED D-1). LaTeX appears only in fields named `latex` or `prompt_latex` and must be in the SwiftMath-renderable subset or carry `render_fallback: "katex"`.

Source: `contracts/data-model.md:36-37`
Binds this task: pinpoints the exact fields where LaTeX may appear and the rendering requirement.

### contracts/error-codes.md — Rules (excerpt on code registration)
> A code appears in exactly one domain doc and in the registry.

Source: `contracts/error-codes.md:11`
Binds this task: `LO_ITEM_UNRENDERABLE` must be registered in both the domain doc and the JSON registry.

### contracts/error-codes.json — LO_ITEM_UNRENDERABLE entry
```
{"code": "LO_ITEM_UNRENDERABLE", "recoverable": true, "surface": "internal", "user_text": null}
```

Source: `contracts/error-codes.json:32`
Binds this task: the error code definition this task uses when reporting unrenderable LaTeX.

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/learning-objects.md — Workflow W1, step 5b
> 5b. **Renderability** — every prompt, hint and explanation renders in SwiftMath, or is flagged for the KaTeX fallback per item, else `LO_ITEM_UNRENDERABLE`.

Source: `docs/domains/learning-objects.md:81-82`
Acceptance path: this is the workflow step this task implements.

### docs/domains/learning-objects.md — Errors produced (LO_ITEM_UNRENDERABLE)
> | `LO_ITEM_UNRENDERABLE` | Prompt, hint or explanation fails SwiftMath and is not flagged for fallback | Internal (rendering-spike report) | Yes — rewrite notation or flag |

Source: `docs/domains/learning-objects.md:129`
Acceptance path: the error row — the task must resolve each occurrence by rewriting or flagging.

### docs/domains/learning-objects.md — Core entities (ProbeItem)
> **ProbeItem** — a short item tagged with a node id, of type `numeric | mc` (I10): a `prompt` (LaTeX subset SwiftMath renders — the rendering spike, v2.2 §B), an `answer` (numeric, with an optional declared tolerance) or `choices[]` with the correct id, a one-line `why` shown with the answer (D5), and `distractor_error_types` — every distractor and each anticipated numeric wrong answer tagged with an `ErrorType` id, the Tier 0 classifier (diagnosis Q1). The answer is re-derived by SymPy in the pipeline (D41, I1); on the device it is checked in code, with no grader model and no free text.

Source: `docs/domains/learning-objects.md:54-60`
Acceptance path: defines the ProbeItem entity, which carries `prompt_latex`; task enumerates every LaTeX-bearing field by walking the schema.

## §D. Prior task outputs this task depends on
- None — no prior task outputs consumed directly. The task reads `data/demo/nodes.json`, produced by task 01.5, which is a separate dependency managed by EPIC coordination.

## §E. Negative facts (confirmed ABSENT)
- `data/demo/` directory — confirmed absent. Glob pattern `data/demo` returned no match. Source: task 01.5 produces this; it is a successor dependency.
- `Packages/Rendering/Sources/Rendering/RenderCheckReport.swift` — confirmed absent. This file is to be created by this task.
- No pytest markers for network/rendering tests registered in `pipeline/pyproject.toml`. Grep pattern `markers|pytest.mark` returned no match. Source: `pipeline/pyproject.toml` (lines 1–42).

## §F. File scope
Files this task may create or touch. Mark each create / modify.

- MODIFY `Packages/Rendering/Sources/Rendering/Rendering.swift` — `RenderCheck` — extend `parseError(latex:)` and add `canRender(latex:) → Bool`.
- CREATE `Packages/Rendering/Sources/Rendering/RenderCheckReport.swift` — new module to define the report shape and collection methods.
- MODIFY `Packages/Rendering/Tests/RenderingTests/RenderingTests.swift` — add test suite over `data/demo/nodes.json` once available.
- CREATE `docs/epics/epic-01-rendering-spike-outcome.md` — outcome record listing all LaTeX strings scanned, failures found, and resolutions applied.
- MODIFY `data/demo/nodes.json` — notation rewrites and `render_fallback` flags only (after task 01.5 completes).

## §G. Stack constraints relevant here

**SwiftMath version and import constraint:**
> **SwiftMath**, imported only by the `Packages/Rendering` package | **1.7.3 exact** (`Package.swift` `exact:` and the app's `XCRemoteSwiftPackageReference`)

Source: `docs/tech-stack.md:18`
Constraint: exactly version 1.7.3; only `Packages/Rendering` may import it (I14).

**Test framework:**
From `Packages/Rendering/Tests/RenderingTests/RenderingTests.swift:1`, the suite uses `import Testing`, which is Swift Testing (first-party, `swift-tools-version 6.2` compatible).

**Gate 3 (Core + Rendering):**
> ( cd "$ROOT/Packages/Rendering" && xcodebuild test -quiet -scheme Rendering -destination "$SIM" CODE_SIGNING_ALLOWED=NO )

Source: `scripts/gate.sh:19`
Constraint: `-scheme Rendering` on the iOS simulator; the test must pass `scripts/gate.sh` gate 3.

**Deployment target:**
> **iOS / iPadOS 18.0** | `IPHONEOS_DEPLOYMENT_TARGET = 18.0`; `Core` platforms `.iOS(.v18)`, `.macOS(.v15)`

Source: `docs/tech-stack.md:16`
Constraint: `Packages/Rendering` targets iOS 18.0 (already set in `Package.swift:10` as `.iOS(.v18)`).

**Python pipeline sympy dependency:**
> **sympy** ≥ 1.14,<2 (exact pins in `pipeline/uv.lock`) ... sympy 1.14.0 ... CAS answer re-derivation (I1)

Source: `docs/tech-stack.md:27`
Note: task 01.7 depends on this; 01.6 documents it for reference.

**No model anywhere in EPIC 01:**
> `contracts/ai-usage.md` — no model anywhere in this EPIC. `READ-ONLY`.

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:34`
Constraint: `RenderCheck` is deterministic, zero model calls.

**Data model LaTeX fields enumeration:**
The nodes.schema.json schema §D lists these fields that hold LaTeX and must be checked:

1. `nodes[].paraphrase` — not LaTeX, but plain text ≤140 chars; skip
2. `nodes[].explanation` — plain text, may contain small LaTeX citations; check if schema requires LaTeX
3. `nodes[].worked_examples[].steps_latex[]` — array of LaTeX strings
4. `nodes[].hint_tree[<error_type_id>][]` — array of strings (hint tiers); may contain LaTeX
5. `nodes[].probe_items[].prompt_latex` — LaTeX string (required)
6. `nodes[].probe_items[].why` — plain text string; skip
7. `nodes[].probe_items[].choices[].latex` — LaTeX string for `mc` items

Per contract/data-model.md §Text, LaTeX appears only in fields named `latex` or `prompt_latex`. The task enumerates by schema inspection.

**Outcome record location constraint (amended):**
From epic-01-core-data-l0-layout-demo-bundle.md §10 (change log, amendment 01.05.1, lines 151–154):
> The **L0 report is not a bundle file and is not committed**: it is `core-cli validate` **stdout**, JSON, in the shape fixed by `contracts/graph-constraints.md` § Report shape; the pipeline wrapper parses it in-process and fails the build on `passed: false`. Nothing other than a schema-named bundle file may be written under `data/**` (`contracts/data-model.md` § Enforcement: every `*.json` under `data/**` validates against the schema its filename names).

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:147-154`
Constraint: the rendering-spike outcome record **must NOT be written under `data/**`**. It lives in `docs/epics/`, not `data/`. Only schema-named bundle files go under `data/`.

**Quantitative claims policy (I11):**
> Docs: every quantitative claim in `docs/`, `contracts/`, briefs and amendments carries `[SOURCED: …]` or `[ESTIMATE: …]`. **No time estimates anywhere**.

Source: `CLAUDE.md:34`
Constraint: the outcome record must tag any counts or thresholds (e.g., "X items scanned," "Y failures found") with `[SOURCED: …]` or `[ESTIMATE: …]`.

**Core import boundary (I14):**
> **`Core` is renderer-free and single-source**: `Core` imports Foundation only; the render layer never computes state; L0 and layout exist once, in `Core`. A test asserts the import boundary.

Source: `CLAUDE.md:37`
Constraint: `Packages/Rendering` is separate from `Core` precisely so `Core` stays Foundation-only. The rendering check must live in `Packages/Rendering`.

**EPIC 01 acceptance criterion 6 (full text):**
> 6. The rendering spike reports zero unresolved items: every LaTeX string in `data/demo` parses in SwiftMath or carries `render_fallback`; the outcome file lists what was rewritten.

Source: `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:79-80`
Acceptance: pass = zero unresolved items in the final outcome.

---

## Quote audit

1. `contracts/content-policy.md:29-30` — re-read: ✓ byte-exact match
2. `contracts/content-policy.md:49-51` — re-read: ✓ byte-exact match
3. `contracts/data-model.md:36-37` — re-read: ✓ byte-exact match
4. `contracts/error-codes.md:11` — re-read: ✓ byte-exact match
5. `contracts/error-codes.json:32` — re-read: ✓ byte-exact match
6. `docs/domains/learning-objects.md:81-82` — re-read: ✓ byte-exact match
7. `docs/domains/learning-objects.md:129` — re-read: ✓ byte-exact match
8. `docs/domains/learning-objects.md:54-60` — re-read: ✓ byte-exact match
9. `docs/tech-stack.md:18` — re-read: ✓ byte-exact match
10. `scripts/gate.sh:19` — re-read: ✓ byte-exact match
11. `docs/tech-stack.md:16` — re-read: ✓ byte-exact match
12. `docs/tech-stack.md:27` — re-read: ✓ byte-exact match
13. `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:34` — re-read: ✓ byte-exact match
14. `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:147-154` — re-read: ✓ byte-exact match
15. `CLAUDE.md:34` — re-read: ✓ byte-exact match
16. `CLAUDE.md:37` — re-read: ✓ byte-exact match
17. `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:79-80` — re-read: ✓ byte-exact match
