# Epic 01 · Task 06.1: Contract v1.1 — ProbeItem `check` + landmark `source_title`, and their ripple

---
epic: 01
task: 06.1
slug: contract-v1-1-probe-check
kind: feature
risk: seam
depends_on: [01.1, 01.5, 01.6]
model: sonnet
---

> **Origin.** This task exists only to carry out the owner's Q5 ruling of 2026-09-09,
> `tasks/blocked/Q5-RULING-01-07.md`. It is inserted between task 01.6 and task 01.7; **01.7 now depends on
> it** and must not be dispatched before it lands (01.7 derives its answers from the field this task adds).
> It is one atomic change on purpose — see §6, "why this is not split".

## §1 Goal & acceptance criteria

Goal: apply the versioned contract change the owner ruled on — ProbeItem gains a machine-readable `check`
field from which SymPy derives the answer, and a landmark gains a `source_title` the source page can
actually be asserted to contain — and carry that change through every artifact that conforms to it, in one
green commit series: the two JSON Schemas, the two contract documents, `contracts/examples/`, the `Core`
`Codable` types, and `data/demo/`.

Invariants in play:

- **I1** — the point of `check` is that a CAS decides correctness. `check` is a *declaration* the CAS
  evaluates; `answer.value` is the *claim* it is compared against. `prompt_latex` is never parsed to derive
  an answer, and no model is called anywhere in this task.
- **I15** — the landmark's `name` is NOT edited (owner ruling Q5-2). The landmark becomes verifiable by
  declaring the real thing it cites (`source_title`), not by weakening the check. A landmark that cannot be
  sourced is still dropped, never invented.
- **I6** — `source_title` holds the title of a public document, which is a fact and may be stored
  (`contracts/content-policy.md` § Grade 9–12 tier: "Codes, course names, strand names and structure are
  facts and may be stored freely"). No Ministry or third-party prose is added anywhere; `paraphrase`,
  `why`, `what_it_is` and `name` are untouched in every file.
- **I14** — `Core` gains two `Codable` types and one field on two existing types. Foundation only; no logic,
  no validation, no derivation in `Core`. The CAS derivation is the pipeline's (task 01.7).

Acceptance criteria (each independently verifiable):

- AC1: `contracts/schemas/nodes.schema.json` defines `check` exactly as §4 step 1 fixes it, and its
  `probe_items[].items.allOf` requires `check` on every `numeric` item and forbids it on every `mc` item.
  Instrument: `cd pipeline && uv run pytest tests/test_contracts.py -q` green (schema is valid 2020-12),
  plus the two negative controls of AC7.
- AC2: `contracts/schemas/landmarks.schema.json` requires `source_title` (`type: string`, `minLength: 1`)
  on every landmark. Instrument: same test file.
- AC3: `contracts/data-model.md` carries the `check` documentation and the new `### Probe answer derivation
  (normative)` section verbatim as §4 step 3 fixes them, and its `Contract version` reads `v1.1.0`;
  `contracts/content-policy.md` carries the two amended bullets verbatim as §4 step 4 fixes them and its
  `Contract version` reads `v1.1.0`. Instrument: `rg -n "Contract version" contracts/data-model.md
  contracts/content-policy.md` shows `v1.1.0` in both; the amended text is present verbatim.
- AC4: `contracts/examples/nodes.json`'s two `numeric` items (`exp-1`, `expf-1`) carry the `check` objects
  pinned in §4 step 5, and `contracts/examples/landmarks.json` carries `"source_title": "Interest Act"`.
  Instrument: `test_example_validates` green for both files.
- AC5: all **20** `numeric` items of `data/demo/nodes.json` carry exactly the `check` object pinned for
  their item id in §4 step 6's table — no item skipped, no value invented — and
  `data/demo/landmarks.json` carries `"source_title": "Interest Act"`. `name`, `prompt_latex`,
  `answer.value`, `why`, `what_it_is` and every other existing field in both files are byte-unchanged.
  Instrument: `test_data_bundles_validate` green; `git diff` on the two files shows added keys only.
- AC6: `Core` round-trips the new fields. `ProbeItem` gains `check: ProbeCheck?`, `Landmark` gains
  `sourceTitle: String` (non-optional — the schema requires it), and `ProbeCheck`, `ProbeCheckKind`,
  `ProbeCheckSelect` are added per §4 step 7. Instrument:
  `DecodeRoundTripTests.decodeRoundTrip` green over the amended `contracts/examples/`.
- AC7: the new schema requirements are proven live by two negative controls added to
  `pipeline/tests/test_contracts.py` (§5 T5): deleting `check` from a `numeric` item of
  `contracts/examples/nodes.json` in memory makes validation FAIL with a message naming `check`; deleting
  `source_title` from the example landmark in memory makes validation FAIL with a message naming
  `source_title`. A control that passes on the mutated document is a FAIL of this task.
- AC8: **the field survives a real `core-cli layout` round-trip** — the seam this change is most likely to
  break silently. `BundleIO.write` re-encodes all seven bundle files from the `Core` types
  (`Packages/Core/Sources/Core/BundleIO.swift:58-71`), so a `Core` type that does not carry `check` /
  `source_title` would *erase* them from `data/demo` on the next layout run. A test asserts that decoding
  `data/demo/nodes.json` + `data/demo/landmarks.json` into the `Core` types and re-encoding preserves every
  `check` object and the `source_title` string (§5 T1). Anti-vacuity: the test asserts it compared ≥ 20
  `check` objects.
- AC9: every one of the 20 pinned `check` objects derives, under the normative derivation of
  `contracts/data-model.md` § Probe answer derivation, a value **exactly equal** to that item's declared
  `answer.value`. Instrument: the verification run of §4 step 8, whose printed 20-row output the implementer
  pastes into the PR description. A row that does not match is a blocking gap (§6), never fixed by editing
  `answer.value`.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `contracts/schemas/nodes.schema.json` — MODIFY. Add the `check` property and the two `allOf` conditions.
- `contracts/schemas/landmarks.schema.json` — MODIFY. Add `source_title` to `properties` and to `required`.
- `contracts/data-model.md` — MODIFY. `Contract version` bump; § ProbeItem gains the `check` paragraphs;
  a new § Probe answer derivation (normative); the `landmarks.json` row of § Collections gains
  `source_title`.
- `contracts/content-policy.md` — MODIFY. `Contract version` bump; § Generated content re-derivation
  bullet replaced; § Landmarks bullet replaced.
- `contracts/examples/nodes.json` — MODIFY. `check` on `exp-1` and `expf-1`.
- `contracts/examples/landmarks.json` — MODIFY. `source_title`.
- `Packages/Core/Sources/Core/Model/Nodes.swift` — MODIFY. `ProbeCheck`, `ProbeCheckKind`,
  `ProbeCheckSelect`; `check` on `ProbeItem`.
- `Packages/Core/Sources/Core/Model/Landmarks.swift` — MODIFY. `sourceTitle` on `Landmark`.
- `Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift` — MODIFY. Add the three tests of §5: T1, T2 and T5b. T2 (mutate `check.kind` to `"guess"`, assert `DecodingError`) is new — the pre-existing `unrecognizedEnumValueFailsDecode` mutates `region_id`, not `ProbeCheckKind`, so it does not cover it.
- `Packages/Core/Tests/CoreTests/Fixtures/l0/*/landmarks.json` (19 files) — MODIFY. Add `source_title` to
  each. **Amendment 01.06.1.1 (orchestrating session, 2026-09-09), correcting a spec defect found by the
  implementer:** the original out-of-scope note claimed these "decode unchanged" because `check` is
  optional. That is true of `check` but NOT of `sourceTitle`, which §4 step 7 mandates **non-optional** —
  so every one of these fixtures fails `BundleIO.read`, reding 20 pre-existing `L0CheckerTests` /
  `L0CheckerContractTests` cases, and there was no in-scope way to keep gate 3 green.
  This is not scope creep: task 02b's AC4 requires `Fixtures/l0/valid/` to be **byte-identical** to
  `contracts/examples/`, and it currently is for all seven files (verified). Once
  `contracts/examples/landmarks.json` gains `source_title`, the fixtures must gain it too or 02b's AC4
  breaks. Keep `valid/landmarks.json` byte-identical to `contracts/examples/landmarks.json`; give every
  other fixture the same `source_title` unless that fixture's whole point is a mutated landmark, in which
  case mutate only what that fixture exists to mutate.
- `data/demo/nodes.json` — MODIFY. **Add the `check` key to the 20 `numeric` probe items and nothing
  else.** Every other key in the file is byte-unchanged.
- `data/demo/landmarks.json` — MODIFY. **Add `"source_title": "Interest Act"` and nothing else.** The
  landmark's `name` is NOT edited (owner ruling Q5-2, quoted in §3).
- `pipeline/tests/test_contracts.py` — MODIFY. Add the two negative controls of §5 T5a.

**Write authority over `contracts/**` for this task only.** `contracts/` is read-only to every agent by
standing rule (`CLAUDE.md` RULE 5). It is writable here, and only here, because the owner ruled a versioned
contract change: `tasks/blocked/Q5-RULING-01-07.md:22` ("**OWNER RULING: extend the schema.**") and `:39`
("**OWNER RULING: assert `\"Interest Act\"`.**"), with `:46-47` naming the two contract edits as
consequences to carry out. Nothing in `contracts/` outside the six files listed above may be touched.

Out-of-scope (do not touch even if tempted):

- `pipeline/src/mathmath_pipeline/verify/**` — task 01.7's files. This task ships **no** derivation module,
  no `answers.py`, no SymPy code under `pipeline/src/`. The derivation *rule* is written into the contract
  here; the derivation *code and its committed test* are 01.7's, once (C1, single source).
- `pipeline/tests/test_demo_bundle.py` — reserved for task 01.7.
- `pipeline/tests/test_demo_bundle_shape.py` — task 01.5's file.
- `docs/epics/epic-01-core-data-l0-layout-demo-bundle.md` — the EPIC brief is `brief-amender`'s file. Its
  §3 invariant line and §4 criterion 7 must change with this contract change; the exact replacement text is
  filed in `tasks/blocked/brief-amendment-01-07-probe-check-and-landmark.md` and is a separate
  `brief-amender` pass, not this task's edit.
- `docs/domains/*.md` — domain docs sit *below* contracts in the ground-truth order
  (`contracts/README.md:4-6`); `docs/domains/learning-objects.md` W1 step 5 ("every ProbeItem answer
  re-derived by SymPy in the pipeline … else `LO_PROBE_UNCHECKABLE`") stays true word-for-word under this
  change and needs no edit.
- `contracts/error-codes.md` / `error-codes.json` — no new code. `LO_PROBE_UNCHECKABLE` and
  `LO_LANDMARK_UNSOURCED` already carry both failure modes and are already registered.
- `Packages/Core/Sources/Core/Validation/**`, `Layout/**` — no L0 rule is added. `check` is content the
  pipeline verifies, not graph structure (`docs/tech-stack.md:67`; planner note [4]).
- `Packages/Core/Tests/CoreTests/Fixtures/**` — EXCEPT the 19 `Fixtures/l0/*/landmarks.json` files, which
  are IN SCOPE (see below). Everything else under `Fixtures/**` stays untouched: those files are not
  schema-validated (`test_data_bundles_validate` scans `data/**` only) and `check` is optional in the Swift
  type, so they decode unchanged.
- Any `data/demo/*.json` other than `nodes.json` and `landmarks.json`.
- `App/**`, `Packages/Rendering/**` — `RenderCheckReport`'s field enumeration selects schema properties
  whose name contains `latex` (`Packages/Rendering/Tests/RenderingTests/SchemaEnumerationCoverageTests.swift:68-71`);
  none of `check`, `kind`, `expr`, `at`, `equations`, `unknown`, `select`, `source_title` contains `latex`,
  so that suite is unaffected **by construction** and must not be edited to accommodate this change. If it
  reds, the schema fragment was mistyped — fix the schema, not the test.

## §3 Inputs (verbatim — do not paraphrase)

The owner ruling that authorizes this task:

- `tasks/blocked/Q5-RULING-01-07.md:22-25`:
  > **OWNER RULING: extend the schema.** ProbeItem gains a machine-readable expression field; SymPy derives
  > the answer from that field and compares against `answer`. Chosen over re-authoring the demo data and
  > over qualifying the contract, because the problem is not Demo-local: the generated-content EPICs (05–09)
  > need machine-checkable answers for I1 to hold at product scale, and both other options leave that
  > unsolved.
- `tasks/blocked/Q5-RULING-01-07.md:27-28`:
  > This is a **versioned contract change** (`contracts/README.md`): bump the contract version, ripple to
  > every conforming EPIC, commit under scope `contract(<name>)`.
- `tasks/blocked/Q5-RULING-01-07.md:39-42`:
  > **OWNER RULING: assert `"Interest Act"`.** The general rule — "the fetched page contains the landmark's
  > name" — is amended, because a landmark `name` is by design the project's own descriptive claim and not a
  > term from the source document, so the rule is unsatisfiable for essentially every landmark, not just
  > this one. The landmark's `name` is NOT edited to suit the test.

The procedure this task must follow, verbatim:

- `contracts/README.md:42-44` (§ Lock-first rule):
  > A change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every
  > conforming EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

The rule that makes a new field a versioned change at all:

- `contracts/data-model.md:43` (§ Nulls, enums, unknowns):
  > Every object schema sets `additionalProperties: false` — a new field is a versioned change.
- `contracts/data-model.md:42`:
  > Optional means the key is **absent**, never `null`. Enums are closed; an unknown value fails decode.

The text being replaced (quoted so the diff is unambiguous):

- `contracts/content-policy.md:29-30` (§ Generated content):
  > Probe answers are re-derived by SymPy before persistence (I1); prompts and hints must render in
  > SwiftMath or carry `render_fallback: "katex"` (learning-objects W1 5b).
- `contracts/content-policy.md:35-36` (§ Landmarks (I15, D22)):
  > Real, named, verifiable; `source_url` required and resolving at build (HTTP 2xx) with the page text
  > containing the landmark's name; ≥ 1 node id. Unsourced → dropped, never invented, never
  > "hypothetical".
- `contracts/data-model.md:58-62` (§ ProbeItem) — kept in full; the new paragraphs are **appended** to it:
  > `id`, `type ∈ {numeric, mc}`, `prompt_latex`, `why`, and either `answer {value (string, normalised
  > decimal or rational), tolerance (≥ 0, default 0)}` with `wrong_answers[] {value, error_type_id}`
  > (numeric) or `choices[] {id, latex, error_type_id?}` + `correct_choice_id` (mc; every non-correct
  > choice carries an `error_type_id`). No free-text answer field exists (I1, I10).

The rule that keeps `expr` out of the LaTeX regime:

- `contracts/data-model.md:36-37` (§ Text):
  > All student-facing strings are English (DEFERRED D-1). LaTeX appears only in fields named `latex` or
  > `prompt_latex` and must be in the SwiftMath-renderable subset or carry `render_fallback: "katex"`.

  `check.expr` and `check.equations[]` hold **SymPy source, not LaTeX**, and are never rendered or shown to
  a student. § Text is therefore unaffected by this change, and the new fields are deliberately *not*
  `latex`-suffixed.

The seam that forces the `Core` type change (not an optional nicety):

- `Packages/Core/Sources/Core/BundleIO.swift:58-71` — `BundleIO.write` re-encodes **all seven** bundle files
  from the `Core` types, and `core-cli layout data/demo` writes the bundle back
  (`docs/epics/epic-01-core-data-l0-layout-demo-bundle.md:73-74`: "`core-cli layout data/demo` writes
  `position` for every node … running it twice yields byte-identical `nodes.json`"). A `ProbeItem` without
  `check` would silently drop every `check` object on the next layout run, and a `Landmark` without
  `sourceTitle` would drop the string this EPIC's landmark assertion depends on.

Prior shapes this task extends (verified by direct read):

- `Packages/Core/Sources/Core/Model/Nodes.swift:54-64` — `ProbeItem` has no explicit `CodingKeys`;
  `CoreCoding.decoder` uses `.convertFromSnakeCase` (`Packages/Core/Sources/Core/CoreCoding.swift:15`).
  Property names therefore map by convention: `sourceTitle` ↔ `source_title`, `check` ↔ `check`.
- `Packages/Core/Sources/Core/Model/Landmarks.swift:11-19` — `Landmark` fields, `sourceUrl` non-optional
  by the same I15 reasoning that makes `sourceTitle` non-optional.
- `contracts/schemas/nodes.schema.json:330-360` — the existing `allOf` if/then pair on `type` is the shape
  the two new conditions extend.

## §4 Implementation outline

### 1. `contracts/schemas/nodes.schema.json` — add `check`

Insert this property into `probe_items[].items.properties`, after `correct_choice_id`
(`contracts/schemas/nodes.schema.json:318-321`), keeping the file's 2-space indentation:

```json
"check": {
  "type": "object",
  "properties": {
    "kind": { "type": "string", "enum": ["evaluate", "solve"] },
    "expr": {
      "type": "string",
      "minLength": 1,
      "not": { "pattern": "^\\s*[+-]?[0-9]+(\\.[0-9]+)?(/[0-9]+)?\\s*$" }
    },
    "at": {
      "type": "object",
      "propertyNames": { "pattern": "^[a-zA-Z][a-zA-Z0-9]*$" },
      "additionalProperties": {
        "type": "string",
        "pattern": "^-?[0-9]+(\\.[0-9]+)?(/[1-9][0-9]*)?$"
      },
      "minProperties": 1
    },
    "equations": {
      "type": "array",
      "items": { "type": "string", "minLength": 1, "pattern": "^Eq\\(" },
      "minItems": 1
    },
    "unknown": { "type": "string", "pattern": "^[a-zA-Z][a-zA-Z0-9]*$" },
    "select": { "type": "string", "enum": ["only", "max", "min"] }
  },
  "required": ["kind"],
  "additionalProperties": false,
  "allOf": [
    {
      "if": { "properties": { "kind": { "const": "evaluate" } } },
      "then": {
        "required": ["expr"],
        "not": {
          "anyOf": [
            { "required": ["equations"] },
            { "required": ["unknown"] },
            { "required": ["select"] }
          ]
        }
      }
    },
    {
      "if": { "properties": { "kind": { "const": "solve" } } },
      "then": {
        "required": ["equations", "unknown"],
        "not": {
          "anyOf": [{ "required": ["expr"] }, { "required": ["at"] }]
        }
      }
    }
  ]
}
```

Then amend the two existing conditions at `contracts/schemas/nodes.schema.json:330-360`:

- the `"type": "numeric"` branch's `then` becomes `{"required": ["answer", "check"]}`;
- the `"type": "mc"` branch's `then` becomes
  `{"required": ["choices", "correct_choice_id"], "not": {"required": ["check"]}}`.

Three properties of this fragment are load-bearing and must not be "simplified" away:

- `expr`'s `not`/`pattern` is the **anti-vacuity guard on the field itself**: a `check` whose `expr` is a
  bare numeric literal would merely restate `answer.value` and prove nothing. It is enforced at the schema
  rung — the cheapest rung that holds it (`contracts/README.md:32`).
- `equations[]`'s `^Eq\(` pattern keeps a solve declaration an equation, not an expression that happens to
  parse.
- the two `not`/`anyOf` blocks make the two kinds disjoint, so no item can carry a half-filled check whose
  unused half is silently ignored.

### 2. `contracts/schemas/landmarks.schema.json` — add `source_title`

Add to `landmarks[].properties`, after `name`:

```json
"source_title": { "type": "string", "minLength": 1 },
```

and add `"source_title"` to the `required` array (after `"what_it_is"`).

### 3. `contracts/data-model.md`

Bump the version line at `contracts/data-model.md:3` to:

```
**Contract version:** v1.1.0 · Source: brief v2 §5 as amended (D20–D22, D32, D33, D43–D48), `docs/domains/*.md`; v1.1.0 adds `ProbeItem.check` and `Landmark.source_title` (owner Q5 ruling 2026-09-09, `tasks/blocked/Q5-RULING-01-07.md`)
```

Append to § ProbeItem, after the existing paragraph:

```
Every `numeric` item additionally carries **`check`** — the machine-readable declaration the CAS re-derives
the answer from (I1). An `mc` item never carries `check`: its correctness is `correct_choice_id` plus the
on-enum distractor rule (`content-policy.md` § Generated content). Extending `check` to `mc` items is a
further versioned change.

`check` is `{ kind ∈ {evaluate, solve} }` plus, by kind:
- **`evaluate`** — `expr` (required): one SymPy-source expression; `at` (optional): a map from symbol name
  to a numeric string, substituted before evaluation. `equations`, `unknown`, `select` are absent.
- **`solve`** — `equations[]` (required): one or more `Eq(lhs, rhs)` in SymPy source; `unknown` (required):
  the symbol whose value is the answer; `select ∈ {only, max, min}` (optional, default `only`): which
  solution is the answer when a well-posed problem has more than one. `expr` and `at` are absent.

`expr` and `equations[]` hold **SymPy source, never LaTeX** (§ Text is unaffected); they are never rendered
and never shown to a student. `expr` may not be a bare numeric literal — a check that restates
`answer.value` proves nothing, and the schema rejects it. `answer.value` is the claim, `check` is the
derivation, and the two are compared, never merged: a disagreement is a build failure, never a correction of
one from the other.
```

Add this new section immediately after § ProbeItem:

```
### Probe answer derivation (normative)
The pipeline derives every `numeric` answer from `check` alone. **`prompt_latex` is never parsed** — it is a
presentation string that may embed an English question, and a parser that mis-reads it does not fail, it
silently confirms whatever answer was authored. No model participates at any point (I1).

Parsing is `sympy.parse_expr` with `standard_transformations + (rationalize,)` — so decimal literals become
exact `Rational`s — and a **closed name allow-list**: `Eq`, `Rational`, `sqrt`, `log`, `exp`, `Abs`, `diff`,
`pi`, `E`. Any other name parses to a free symbol; calling one raises, and the item fails. Extending the
allow-list is a versioned change.

- `evaluate`: parse `expr`; every key of `at` must be a free symbol of `expr`; substitute; the result must
  have no free symbols left.
- `solve`: parse each equation; `unknown` must be a free symbol of the set; call
  `sympy.solve(equations, sorted(free_symbols), dict=True)`; keep the solutions that bind `unknown`;
  `select: only` requires exactly one distinct bound value, `max`/`min` take the extreme of them.

The derived value must be an exact rational after `sympy.simplify` (`.is_Rational` true). A parse failure,
an unknown name, a leftover free symbol, an unbound `unknown`, zero solutions, more than one solution under
`select: only`, or a non-rational result is `LO_PROBE_UNCHECKABLE` and **fails the build**. Nothing is
rounded, nothing is approximated, nothing is inferred. The derived value is then compared to
`answer.value` within `answer.tolerance` (default `0`); a mismatch fails the build.
```

In § Collections, the `landmarks.json` row: insert `source_title` after `name`, so the row reads
`` `id`, `name`, `source_title`, `what_it_is`, `source_url` (**required**, https), `node_ids[]` (≥ 1), `region_ids[]`, `position` ``.

### 4. `contracts/content-policy.md`

Bump the version line at `contracts/content-policy.md:3` to:

```
**Contract version:** v1.1.0 · Source: I6, I9, I11, I15; D2 (revised), D12, D13, D18, D22, D43; brief §10; v1.1.0 amends answer re-derivation and the landmark page assertion (owner Q5 ruling 2026-09-09, `tasks/blocked/Q5-RULING-01-07.md`)
```

Replace the § Generated content re-derivation bullet (`:29-30`) with:

```
- Probe answers are re-derived by SymPy before persistence (I1): every `numeric` ProbeItem carries `check`
  and the CAS derives the answer from `check` alone — never by parsing `prompt_latex`, never by a model
  (`data-model.md` § ProbeItem, § Probe answer derivation). An item the CAS cannot derive exactly, or whose
  derived value differs from `answer.value` beyond `tolerance`, is `LO_PROBE_UNCHECKABLE` and fails the
  build; nothing ships unchecked. `mc` correctness is `correct_choice_id` plus the distractor rule below;
  extending `check` to `mc` is a further versioned change. Prompts and hints must render in SwiftMath or
  carry `render_fallback: "katex"` (learning-objects W1 5b).
```

Replace the § Landmarks bullet (`:35-36`) with:

```
- Real, named, verifiable; `source_url` required and resolving at build (HTTP 2xx); `source_title` required
  — the title of the real, named thing the landmark cites, as that title appears on the source page — and
  the fetched page text must contain it (case-insensitive substring). The landmark's `name` is the
  project's own descriptive claim about the mathematics and is by design not a term from the source, so it
  is never asserted against the page; a landmark's `name` is never edited to make a check pass. ≥ 1 node
  id. Unsourced → dropped, never invented, never "hypothetical".
```

### 5. `contracts/examples/`

`contracts/examples/nodes.json` — add to `exp-1` (`prompt_latex` `(2^3)^2 = 2^{\,?}`, answer `6`):

```json
"check": { "kind": "solve", "equations": ["Eq((2**3)**2, 2**k)"], "unknown": "k" }
```

and to `expf-1` (`y = 3^x,\ x = 2 \Rightarrow y = ?`, answer `9`):

```json
"check": { "kind": "evaluate", "expr": "3**x", "at": { "x": "2" } }
```

`exp-2` is `mc` and must NOT gain a `check`. `contracts/examples/landmarks.json` — add
`"source_title": "Interest Act"` after `name`.

### 6. `data/demo/nodes.json` — the 20 `check` objects, pinned

Add exactly this `check` to the item with the given id. Nothing else in the file changes. The
"derives" column is what §4 step 8's run must print, and it equals that item's existing `answer.value` in
every row — the answers are not being changed, they are being made checkable.

| # | item id | `check` | derives |
|---|---|---|---|
| 1 | `integer-operations-1` | `{"kind":"evaluate","expr":"-3 - (-7)"}` | `4` |
| 2 | `order-of-operations-1` | `{"kind":"evaluate","expr":"2 + 3*4"}` | `14` |
| 3 | `rational-numbers-1` | `{"kind":"evaluate","expr":"1/2 + 1/3"}` | `5/6` |
| 4 | `exponent-laws-1` | `{"kind":"solve","equations":["Eq((2**3)**2, 2**k)"],"unknown":"k"}` | `6` |
| 5 | `scientific-notation-1` | `{"kind":"evaluate","expr":"3.2*10**4"}` | `32000` |
| 6 | `linear-relations-1` | `{"kind":"evaluate","expr":"diff(3*x + 5, x)"}` | `3` |
| 7 | `solving-linear-equations-1` | `{"kind":"solve","equations":["Eq(2*x + 3, 11)"],"unknown":"x"}` | `4` |
| 8 | `solving-systems-of-equations-1` | `{"kind":"solve","equations":["Eq(x + y, 10)","Eq(x - y, 2)"],"unknown":"x"}` | `6` |
| 9 | `simplifying-expressions-1` | `{"kind":"evaluate","expr":"diff(3*x + 5*x, x)"}` | `8` |
| 10 | `polynomials-1` | `{"kind":"evaluate","expr":"diff((3*x**2 + 2*x) + (x**2 + 5*x), x, 2)/2"}` | `4` |
| 11 | `factoring-1` | `{"kind":"evaluate","expr":"x**2 + 5*x + 6","at":{"x":"0"}}` | `6` |
| 12 | `solving-quadratics-1` | `{"kind":"solve","equations":["Eq(x**2 - 5*x + 6, 0)"],"unknown":"x","select":"max"}` | `3` |
| 13 | `rational-expressions-1` | `{"kind":"evaluate","expr":"(x**2 - 9)/(x - 3)","at":{"x":"5"}}` | `8` |
| 14 | `quadratic-functions-1` | `{"kind":"solve","equations":["Eq(diff((x - 3)**2 + 4, x), 0)"],"unknown":"x"}` | `3` |
| 15 | `function-concept-1` | `{"kind":"evaluate","expr":"2*x + 1","at":{"x":"3"}}` | `7` |
| 16 | `function-transformations-1` | `{"kind":"evaluate","expr":"x - (x - 4)"}` | `4` |
| 17 | `function-notation-1` | `{"kind":"evaluate","expr":"3*x - 2","at":{"x":"4"}}` | `10` |
| 18 | `domain-and-range-1` | `{"kind":"solve","equations":["Eq(x - 3, 0)"],"unknown":"x"}` | `3` |
| 19 | `exponential-functions-1` | `{"kind":"evaluate","expr":"3**x","at":{"x":"2"}}` | `9` |
| 20 | `logarithms-1` | `{"kind":"evaluate","expr":"log(8, 2)"}` | `3` |

Why the seven non-arithmetic prompts are expressible without a question-understander — each is a CAS
identity, not a reading of the prompt's English:

- 6 `slope`: the slope of a line is its derivative — `diff(3x+5, x)`.
- 9 `k` in `3x+5x = kx`: the coefficient of a linear expression is its derivative.
- 10 `coefficient of x²`: for a polynomial `p`, that coefficient is `p''(x)/2`.
- 11 `a·b` in `x²+5x+6=(x+a)(x+b)`: for a monic quadratic the constant term is `p(0) = a·b`.
- 12 `larger root`: solve, then `select: max`.
- 14 `vertex x-coordinate`: the stationary point, `diff(y, x) = 0`.
- 16 `shifts right by ?`: the shift is the difference of the arguments, `x - (x-4)`.
- 18 `domain requires x ≥ ?`: the boundary of `sqrt(u)`'s domain is `u = 0`.

`data/demo/landmarks.json` — add `"source_title": "Interest Act"` after `name`. The `name`
(`Canadian fixed-rate mortgages compound semi-annually`) is **not** edited (owner ruling, §3).

### 7. `Core` types

`Packages/Core/Sources/Core/Model/Nodes.swift` — add `public let check: ProbeCheck?` to `ProbeItem` (last
stored property, matching the file's field-order convention of following the schema) and add:

```swift
/// The machine-readable declaration the pipeline's CAS re-derives `answer.value` from
/// (`contracts/data-model.md` § Probe answer derivation). `Core` carries it so a bundle re-encode
/// (`BundleIO.write`) preserves it; `Core` never parses or evaluates it — that is the pipeline's job
/// (I1, I14).
public struct ProbeCheck: Codable, Equatable {
    public let kind: ProbeCheckKind
    public let expr: String?
    public let at: [String: String]?
    public let equations: [String]?
    public let unknown: String?
    public let select: ProbeCheckSelect?
}

public enum ProbeCheckKind: String, Codable {
    case evaluate
    case solve
}

public enum ProbeCheckSelect: String, Codable {
    case only
    case max
    case min
}
```

`Packages/Core/Sources/Core/Model/Landmarks.swift` — add `public let sourceTitle: String` after `name`.
It is non-optional for the same reason `sourceUrl` is (the doc comment at `Landmarks.swift:9-10`): the
schema requires it, so decode fails without it, and I15's verifiability is structural.

`at`'s keys pass through `.convertFromSnakeCase`; the schema's `propertyNames` pattern forbids `_`, so no
binding key can be rewritten by the strategy. Do not add `CodingKeys` to any of these types.

### 8. Verify the 20 derivations before committing (AC9)

Run, from `pipeline/`, a one-off `uv run python` snippet that implements exactly the § Probe answer
derivation algorithm of §4 step 3 over `data/demo/nodes.json`, and print one row per numeric item:
`item id | derived | declared | MATCH/DIFFER`. All 20 rows must read `MATCH` and the run must cover exactly
20 items. Paste the 20-row output into the PR description.

This snippet is **scratch, not a deliverable** — it is not committed anywhere, and no file under
`pipeline/src/` is created by this task. The committed, permanent instrument for the same property is task
01.7's `verify/answers.py` plus `pipeline/tests/test_demo_bundle.py`, which is where it lives once (C1).

### 9. Commits (the auditable ripple, `contracts/README.md:42-44`)

Two commits in one PR, each carrying its contract edit and the ripple that edit forces:

1. `contract(data-model): add ProbeItem.check and Landmark.source_title (v1.1.0)` —
   `contracts/schemas/nodes.schema.json`, `contracts/schemas/landmarks.schema.json`,
   `contracts/data-model.md`, `contracts/examples/*`, `Packages/Core/**`, `data/demo/*`,
   `pipeline/tests/test_contracts.py`.
2. `contract(content-policy): derive answers from check; assert the landmark's source_title (v1.1.0)` —
   `contracts/content-policy.md`.

The PR description states: the ruling file, the two version bumps, and the ripple list (this spec's §2).

## §5 Test plan (seam risk — full plan)

- **T1 happy path / AC8 (the real seam).** In `DecodeRoundTripTests`: decode `data/demo/nodes.json` into
  `NodesFile` and `data/demo/landmarks.json` into `LandmarksFile` with `CoreCoding.decoder`, re-encode with
  `CoreCoding.encoder`, and compare the re-encoded document to the original via `JSONSerialization` object
  graphs (the helper `assertRoundTrip` already in that file). Then, independently of the round-trip, assert
  the decoded model itself: every `numeric` `ProbeItem` has a non-`nil` `check`, and
  `landmarks[0].sourceTitle == "Interest Act"`. **Anti-vacuity:** assert the count of non-`nil` `check`
  objects observed is exactly `20` and the count of `numeric` items is exactly `20` — a decoder that
  dropped the field, or a walk that visited nothing, fails here rather than passing quietly.
- **T2 negative — invalid input rejected at the boundary.** In `DecodeRoundTripTests`: take
  `contracts/examples/nodes.json`, mutate the first numeric item's `check.kind` to `"guess"`, and assert
  `CoreCoding.decoder.decode(NodesFile.self, …)` throws `DecodingError` (closed enum,
  `contracts/data-model.md:42`).
- **T3 error taxonomy.** Nothing to assert: this task registers no error code and raises none. The codes
  the new rule fails under (`LO_PROBE_UNCHECKABLE`, `LO_LANDMARK_UNSOURCED`) are already registered and are
  raised by task 01.7's module, not here. Recorded explicitly so the omission is a decision, not a gap.
- **T4 conformance.** `test_example_validates` and `test_data_bundles_validate` are the conformance
  instruments for the amended schemas and already run over every example and every `data/**` file; no new
  parametrization is needed. `test_schema_is_valid_2020_12` covers the new keywords being legal 2020-12.
- **T5 negative controls for the new guards** (a guard that has never failed is indistinguishable from a
  guard that cannot fail):
  - **T5a**, in `pipeline/tests/test_contracts.py`:
    - `test_numeric_probe_item_requires_check` — load `contracts/examples/nodes.json`, delete `check` from
      the first item whose `type == "numeric"`, assert `_errors("nodes", mutated)` is non-empty and that
      some message mentions `check`. Assert the item it mutated was found (a `None` target is a FAIL).
    - `test_mc_probe_item_rejects_check` — add a `check` object to the `mc` item `exp-2`; assert
      validation fails.
    - `test_check_expr_rejects_a_bare_numeric_literal` — set the first `evaluate` check's `expr` to
      `"6"`; assert validation fails. This is the negative control for the anti-vacuity `not`/`pattern`.
    - `test_landmark_requires_source_title` — load `contracts/examples/landmarks.json`, delete
      `source_title`, assert validation fails with a message mentioning `source_title`.
  - **T5b**, in `DecodeRoundTripTests`: `Landmark` without `source_title` fails decode — mutate the example
    landmarks document to drop the key and assert `DecodingError` is thrown. This proves `sourceTitle` was
    declared non-optional rather than quietly `String?`.
- **T6 idempotency / no-leak.** `BundleIO.write` determinism is already asserted by
  `DecodeRoundTripTests.bundleWriteIsIdempotent` over `contracts/examples/`; the examples now carry the new
  fields, so that test covers them without modification. Do not duplicate it.

## §6 Decision defaults

- IF the question is whether `check` is required or optional on a `numeric` item THEN it is **required**.
  `contracts/content-policy.md` requires re-derivation of probe answers with no expressibility qualifier,
  and an optional field would re-open exactly the gap the owner ruled shut
  (`tasks/blocked/Q5-RULING-01-07.md:22-25`): an item with no `check` would be an item that ships
  unchecked. It is forbidden on `mc` items so that no half-populated shape exists.
- IF `expr` could hold LaTeX instead of SymPy source THEN it holds SymPy source. LaTeX is a presentation
  form; re-introducing a LaTeX-to-CAS translation step re-introduces the mis-read-then-confirm failure the
  arbiter refused (`tasks/blocked/blocked-arbiter-01-07.md:84-85`) and would drag the field into
  `contracts/data-model.md` § Text's renderability regime for no gain.
- IF a pinned `check` in §4 step 6 does not derive its declared `answer.value` in the §4 step 8 run THEN
  **stop and report it as a blocking gap on this spec** (a mis-declared check), naming the item id, the
  derived value and the declared value. Do **not** edit `answer.value` to match, do not edit
  `prompt_latex`, and do not invent a different `check`: the declared answers in `data/demo` were authored
  and reviewed in task 01.5, and a check that disagrees with one is more likely mis-declared than the
  answer is wrong. I1 is not served by making the two agree; it is served by finding out which is wrong.
- IF `sympy` 1.14 cannot derive one of the 20 exactly under the algorithm as written THEN that is a
  blocking gap on this spec, reported with the exact `sympy` output — never patched by loosening the
  algorithm (adding a numeric fallback, a rounding step, an `evalf`, or an `nsimplify` on a non-exact
  value). A CAS that cannot decide must say so loudly (I1).
- IF `data/demo/*.json`'s `format_version` should be bumped for a required-field addition THEN it stays
  `"0.0.0"`. `contracts/data-model.md:26-27` ties `format_version` to `CoreInfo.dataFormatVersion`
  (`Packages/Core/Sources/Core/Core.swift:9` = `"0.0.0"`) and L0 compares the **major** component only
  (`Packages/Core/Sources/Core/Validation/L0Checker.swift:13`). No bundle has been released (the Demo is
  D26 pre-release), so no shipped data can be corrupted by the change, and bumping would force an unrelated
  edit to `CoreInfo`, every example, and every L0 fixture.
- IF the landmark's `name` looks easier to edit than adding `source_title` THEN it is not an option: the
  owner ruled the `name` is not edited (`tasks/blocked/Q5-RULING-01-07.md:39-42`), and I15's rule is that a
  landmark is dropped, never edited into truth.
- IF `pipeline/tests/test_contracts.py`'s existing tests red because `data/demo` or
  `contracts/examples/` has not been populated yet THEN finish the population — do **not** relax the
  schema, and do not stage the change as "schema first, data later". The two must land together (below).

**Why this is not split into a contract task and a data task.** The new fields are `required`, and every
object schema is `additionalProperties: false` (`contracts/data-model.md:43`). A commit that adds the
schema requirement without the data leaves `test_data_bundles_validate` red; a commit that adds the data
without the schema is rejected by `additionalProperties: false`. Neither order produces a green PR, and
`main` accepts only green PRs (`CLAUDE.md` § Principal languages: "changes land only through a PR with both
CI jobs green"). The change is therefore atomic by construction, not by preference. It is nonetheless a
single writer per file: no other in-flight task writes any file in §2 — 01.7 writes
`data/demo/nodes.json` after this task lands and only for `answer.value` / `error_type_id` corrections.

Standing defaults: no identifying field is added anywhere (I5) — `check` holds mathematics and
`source_title` holds a public document title; telemetry is untouched; this task has zero model-calling
paths, so no confidence threshold and no Tier-0 fallback applies (I2 is not engaged); no `paraphrase`,
`why`, `what_it_is` or `name` string is touched anywhere (I6, I15).

## §7 Done definition

The task is done when ALL gates pass:

- `cd pipeline && uv run ruff check . && uv run ruff format --check .` clean
- `cd pipeline && uv run pyright` clean (strict) over `tests/test_contracts.py`
- `swift-format` clean over the three touched Swift files, per `scripts/gate.sh` gate 1
- `cd pipeline && uv run pytest -q` green — including the four new negative controls of T5a
- `Core` tests green on the iOS simulator (gate 3), including T1, T2, T5b
- `scripts/gate.sh` green end-to-end
- `core-cli layout data/demo` run twice yields byte-identical `nodes.json` **and** that `nodes.json` still
  contains all 20 `check` objects and `landmarks.json` still contains `source_title` (AC8's seam, checked
  by hand once in addition to the test)
- the 20-row derivation output of §4 step 8 is in the PR description, all rows `MATCH`, 20 items covered
- both contract files read `Contract version: v1.1.0`; the two commits carry the `contract(data-model)` and
  `contract(content-policy)` scopes
- conforms to every contract section cited in §3 and §4, and to every invariant listed in §1
