# Epic 02 · Task 02.2: Contract v1.3.0 — StudentState `remediated` + marker `past_last_unit`

---
epic: 02
task: 02
slug: contract-data-model-remediated-flag
kind: feat
risk: seam
depends_on: []
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: land the data-model contract bump that carries out arbiter rulings Q-A and Q-F together
(`tasks/arbitration/arbiter-02-predispatch.md`): an optional boolean `remediated` on the `StudentState` node
entry, and an optional boolean `past_last_unit` on the `StudentState` marker; `contracts/data-model.md` moves
to v1.3.0; `contracts/schemas/student-state.schema.json` gains both properties (neither required); the
`contracts/examples/student-state.json` `schema_version` moves to 2 and exercises the new node key; `Core`'s
`Marker` and `NodeState` types gain the matching optional `Codable` fields; and the ripple lands in one green
commit so no dependent EPIC 02 task (02.6, 02.11, 02.12) reads a field that does not yet exist.

Invariants in play:

- **I5** — both new fields are booleans about a *node's* or a *marker's* state, never about a person, device,
  account, install or session. `contracts/data-model.md` § StudentState: "**No field may name a person,
  device, account, install or session** (I5); the schema's closed key set is the guard." Neither field name
  is on the identifier blocklist (`Packages/Core/Tests/CoreTests/IdentifierBlocklistParityTests.swift:17-19`,
  `pipeline/tests/test_contracts.py:26-36`), and this task adds neither field to that blocklist because
  neither identifies anything.
- **I14** — `Core` gains two `Codable` stored properties only: `NodeState.remediated: Bool?` and
  `Marker.pastLastUnit: Bool?`. No decode-time validation, no derivation, no migration function is added to
  `Core`; `Core` stays renderer-free and carries no logic beyond `Codable` conformance
  (`Packages/Core/Sources/Core/Model/StudentState.swift:1-9`, doc comment: no type below declares an
  explicit `CodingKeys`).

Acceptance criteria (each independently verifiable):

- AC1: `contracts/data-model.md`'s `Contract version` line reads `v1.3.0`, and § StudentState carries the
  combined Q-A + Q-F normative text of §4 step 1 — the `marker` and `nodes` field-list clauses gain
  `past_last_unit?` and `remediated?` respectively, and both explanatory paragraphs are present, including
  the `schema_version` **2** / identity-migration sentence.
  Instrument: `rg -n "Contract version" contracts/data-model.md` shows `v1.3.0`; `rg -n "past_last_unit\?|remediated\?" contracts/data-model.md` shows both inside the `marker {...}` / `nodes {...}` clauses.
  Excludes: § ProbeItem, § Probe answer derivation, § Collections and every other section are byte-unchanged;
  no § StudentState merge subsection is added (that is task 02.9's v1.4.0, per the plan's sequencing note).
- AC2: `contracts/schemas/student-state.schema.json` adds `"remediated": {"type": "boolean"}` to the
  node-entry `properties` and `"past_last_unit": {"type": "boolean"}` to `marker.properties`; neither name is
  added to either object's `required` array; `additionalProperties: false` is unchanged on both objects.
  Instrument: `cd pipeline && uv run pytest tests/test_contracts.py -q` green, in particular
  `test_schema_is_valid_2020_12` and `test_example_validates`.
  Excludes: `schema_version`'s own schema fragment (`type: integer, minimum: 1`) is untouched — it already
  admits the value `2`.
- AC3: `contracts/examples/student-state.json`'s `schema_version` is `2`; a new `nodes.matrix-multiplication`
  entry `{"mastery": "blocked", "correct_count": 0, "ladder_rung": 0, "remediated": true}` is present; the
  two pre-existing node entries and the `marker` object are otherwise byte-unchanged (neither gains
  `past_last_unit`).
  Instrument: `test_example_validates["student-state.json"]` green; `git diff contracts/examples/student-state.json` shows the `schema_version` line and one added `nodes` key only.
  Excludes: no other example file changes.
- AC4: `Packages/Core/Sources/Core/Model/StudentState.swift`'s `NodeState` gains `public let remediated:
  Bool?` (last stored property) and `Marker` gains `public let pastLastUnit: Bool?` (last stored property);
  neither type declares an explicit `CodingKeys`.
  Instrument: `swift build` (package `Core`) succeeds; `DecodeRoundTripTests.decodeRoundTrip` green, which
  decodes the amended `contracts/examples/student-state.json` into `StudentState` and re-encodes it
  structurally-equal.
  Excludes: no other `Model/` type is touched.
- AC5: the new `matrix-multiplication` entry's `remediated == true` survives a full decode → re-encode round
  trip, and both new fields' *absence* on the pre-existing entries re-encodes as an omitted key, never `null`
  (`contracts/data-model.md` § Nulls: "Optional means the key is **absent**, never `null`.").
  Instrument: `OptionalAbsentTests` — the new/extended test of §4 step 5 — green.
- AC6: three negative controls prove the guards this task adds are real (a guard that has never failed is
  indistinguishable from one that cannot fail): a non-boolean `remediated` value fails schema validation; a
  non-boolean `past_last_unit` value fails schema validation; a non-boolean `remediated` value fails `Core`
  decode with `DecodingError`.
  Instrument: `pipeline/tests/test_contracts.py::test_node_state_remediated_must_be_boolean`,
  `::test_marker_past_last_unit_must_be_boolean`, and
  `DecodeRoundTripTests.remediatedNonBooleanValueFailsDecode`, all green (i.e., they correctly assert
  failure).
- AC7: the identifier-blocklist guard (I5) continues to hold with both new fields present in the schema and
  the example — `pipeline/tests/test_contracts.py::test_transmitted_shapes_reject_identifier_keys["student-state"]`
  and `IdentifierBlocklistParityTests` stay green with **no edit** to either file.
  Instrument: both test files pass unmodified; `git diff` shows no changes to
  `Packages/Core/Tests/CoreTests/IdentifierBlocklistParityTests.swift`.

## §2 File scope

In-scope (the implementer touches EXACTLY these; nothing else):

- `contracts/data-model.md` — MODIFY. `Contract version` line (v1.2.0 → v1.3.0); § StudentState field-list
  clauses and explanatory paragraphs per §4 step 1.
- `contracts/schemas/student-state.schema.json` — MODIFY. Add `remediated` to the node-entry `properties`;
  add `past_last_unit` to `marker.properties`. Neither added to a `required` array.
- `contracts/examples/student-state.json` — MODIFY. `schema_version` → `2`; add the
  `nodes.matrix-multiplication` entry.
- `Packages/Core/Sources/Core/Model/StudentState.swift` — MODIFY. `remediated: Bool?` on `NodeState`;
  `pastLastUnit: Bool?` on `Marker`.
- `Packages/Core/Tests/CoreTests/OptionalAbsentTests.swift` — MODIFY. Add the test of §4 step 5.
- `Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift` — MODIFY. Add the negative control of §4 step 6.
- `pipeline/tests/test_contracts.py` — MODIFY. Add the two negative controls of §4 step 7.

Out-of-scope (do not touch even if tempted):

- `contracts/interaction-contract.md` — task 02.1's file. Both arbiter rulings' interaction-contract text
  (the `remediated(p)` predicate wording, the `compose` side-effect wording, the `probe` wording, and the
  Q-F § 3 `set_marker` paragraph) lands in 02.1, not here (`docs/plans/epic-02-plan.md`: "Any interaction-contract
  text ruled by the arbiter (Q-A alternative, Q-F) lands here [02.1]").
- `contracts/data-model.md` § ProbeItem, § Probe answer derivation, § Collections, § Enforcement, § Versioning
  — untouched; only the `Contract version` line and § StudentState change.
- `contracts/data-model.md` § StudentState merge subsection — task 02.9's v1.4.0 (Q-B), landed sequentially
  after this task per the plan's note "`contracts/data-model.md` by 02.2 then 02.9".
- `Packages/Core/Tests/CoreTests/IdentifierBlocklistParityTests.swift` — no edit: `remediated` and
  `past_last_unit` are not identifier-shaped and are confirmed absent from both blocklists (§6 default 5).
  The suite is re-run, unmodified, as part of the gate.
- `Packages/Core/Sources/Core/State/**`, `Packages/Core/Sources/Core/CoreError.swift` — task 02.4's files.
  No behavior (fringe eligibility, mastery transitions, `CoreError` cases) is added by this task; this task
  ships the data shape only.
- `pipeline/src/**` — no migration code, no CAS derivation, no runtime writer. `StudentState.schema_version`
  migration is "migrated forward only (platform W3)" (`contracts/data-model.md` § Versioning) — a different,
  later task's scope, not this one's.
- `data/demo/**` — `StudentState` is not a bundle asset (it is listed as the separate `(state)` row in
  `contracts/data-model.md` § Collections, not among the seven files `manifest.json` lists), and no
  `data/demo` student-state fixture exists to update.
- `contracts/error-codes.md` / `contracts/error-codes.json` — no new error code; nothing this task adds can
  fail at runtime (it is a shape change only).
- `App/**` — no application code reads either field in this task.

## §3 Inputs (verbatim — do not paraphrase)

Binding contract rule (the versioning procedure this task follows):

- `contracts/README.md` — heading `## Lock-first rule`:
  > A change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every
  > conforming EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

- `contracts/data-model.md` — heading `### Nulls, enums, unknowns`:
  > Optional means the key is **absent**, never `null`. Enums are closed; an unknown value fails decode.
  >
  > Every object schema sets `additionalProperties: false` — a new field is a versioned change.

Arbiter rulings (normative text this task must land verbatim, `tasks/arbitration/arbiter-02-predispatch.md`):

- Q-A, § `## Q-A — remediated(p) has no field`, "Normative text for 02.2":
  > **Normative text for 02.2: `contracts/data-model.md` § StudentState (v1.3.0).** Replace the `nodes`
  > clause with:
  > > `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?, next_due?, ladder_rung, remediated?}}`
  >
  > Then add this paragraph after the field list:
  > > `remediated` (boolean, optional; absent = false) records that a diagnosis event confirmed this node
  > > (probe outcome `fail`) and showed its one remediation piece (diagnosis W4). It is written `true` only by
  > > that step and only on a node whose `mastery` is `blocked`; it is removed whenever the node becomes
  > > `cleared`. A node blocked by `capped` or by a second miss after the run's Door A event was spent does not
  > > carry it. It is a fact about a node, never about a person, device, install or session (I5).
  > >
  > > `schema_version` is **2**. Migration 1 → 2 is the identity: a version-1 document is a valid version-2
  > > document with every `remediated` absent.
  >
  > - **Schema.** Add `"remediated": {"type": "boolean"}` to the node-entry `properties`. It is not in
  >   `required`, and `additionalProperties: false` stays.
  > - **Example.** In `contracts/examples/student-state.json`, set `schema_version` to 2 and add one entry
  >   `{"mastery": "blocked", "correct_count": 0, "ladder_rung": 0, "remediated": true}` so the round-trip
  >   test exercises the key.
  > - **Type.** Add `remediated: Bool?` to `NodeState`. It encodes as absent, never `null` (§ Nulls, enums,
  >   unknowns).

- Q-F, § `## Q-F — representing "marker past the course's last unit"`, "Normative text for 02.2":
  > **Normative text for 02.2: `contracts/data-model.md` § StudentState.** Replace the `marker` clause with
  > `marker {course_code, unit_id, past_last_unit?}`, then add:
  > > `past_last_unit` (boolean, optional; absent = false): `true` means the marker has been moved past the
  > > course's last unit (v2.7 §4). `unit_id` then names the course's last unit at the time it was set and
  > > must still name a unit of the course.
  >
  > Schema: add `"past_last_unit": {"type": "boolean"}` to `marker.properties`. It is not required.

- Summary table row, § `## Summary`:
  > | Q-A | **Planner default adopted**: optional boolean `remediated` on the node entry; data-model v1.3.0;
  > `schema_version` 2 | 02.2 (schema/type), 02.1 (§1/§2/§4 text), 02.11 (sets it), 02.12 (merge) |
  >
  > | Q-F | Optional boolean `past_last_unit` on `marker`; there is no sentinel `unit_id` | 02.2 (schema/type),
  > 02.1 (§3/§2 text) |

- Sequencing note, header block:
  > One data-model bump carries Q-A and Q-F together: **v1.3.0, one task (02.2)**. Q-B follows as **v1.4.0
  > (02.9)**. The file is written sequentially, per the plan's note "`contracts/data-model.md` by 02.2 then
  > 02.9".

Prior shapes this task extends (verified by direct read):

- `contracts/data-model.md` — current `Contract version` line:
  > **Contract version:** v1.2.0 · Source: brief v2 §5 as amended (D20–D22, D32, D33, D43–D48),
  > `docs/domains/*.md`; v1.1.0 adds `ProbeItem.check` and `Landmark.source_title` (owner Q5 ruling
  > 2026-09-09, `tasks/blocked/Q5-RULING-01-07.md`); v1.2.0 corrects § Probe answer derivation — the name
  > allow-list alone does not close the parse environment, so an AST-shape allow-list is added and the true
  > name list is stated (orchestrating session's authorization 2026-09-09,
  > `tasks/blocked/AUTHORIZATION-01-07a-contract-write.md`, on the defect reported in
  > `tasks/blocked/tester-blocked-01-07.md`; not an owner ruling)

- `contracts/data-model.md` — current § StudentState (the paragraph this task replaces):
  > `schema_version`, `format_version_seen`, `syllabi[]` (course codes), `marker {course_code, unit_id}`,
  > `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?, next_due?, ladder_rung}}`,
  > `trail {segments[] {kind ∈ {course, extension}, course_code?, node_ids[]}}` (derived, cached),
  > `expedition_log[] {day, item_count, cleared, blocked, abandoned, diagnosis_events}`,
  > `probe_log[] {day, node_id, item_id, correct, retry}`, `install_day`, `consent_on`. **No field may name a
  > person, device, account, install or session** (I5); the schema's closed key set is the guard.

- `Packages/Core/Sources/Core/Model/StudentState.swift:23-34` (current shape, before this task):
  ```swift
  public struct Marker: Codable, Equatable {
      public let courseCode: String
      public let unitId: String
  }

  public struct NodeState: Codable, Equatable {
      public let mastery: Mastery
      public let correctCount: Int
      public let lastProbe: String?
      public let nextDue: String?
      public let ladderRung: Int
  }
  ```

- `Packages/Core/Sources/Core/CoreCoding.swift:14-17`:
  ```swift
  public static var decoder: JSONDecoder {
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      return decoder
  }
  ```
  — snake_case wire keys map to camelCase Swift properties by convention; `remediated` ↔ `remediated`,
  `pastLastUnit` ↔ `past_last_unit`. No explicit `CodingKeys` is added.

- `pipeline/tests/test_contracts.py:52-56` (the assertion helper this task's two new negative controls use):
  ```python
  def _errors(name: str, instance: JsonValue) -> list[str]:
      """Validation error messages for `instance` against schema `name` (jsonschema ships partial stubs)."""
      validator = _validator(name)
      found = validator.iter_errors(instance)  # pyright: ignore[reportUnknownMemberType]
      return sorted(e.message for e in found)
  ```

- `contracts/examples/nodes.json:148` — the node id `matrix-multiplication` exists in the example bundle and
  is not yet referenced by `contracts/examples/student-state.json` (which uses only `exponent-laws` and
  `exponential-functions`).

## §4 Implementation outline

### 1. `contracts/data-model.md`

Change the `Contract version` line's leading version from `v1.2.0` to `v1.3.0`, keeping every existing clause
of the line byte-unchanged, and append one more clause at the end:

```
; v1.3.0 adds `StudentState.nodes[].remediated` and `StudentState.marker.past_last_unit`, `schema_version` 2
(arbiter rulings Q-A, Q-F, `tasks/arbitration/arbiter-02-predispatch.md`)
```

Replace § StudentState in full with the following (this combines the Q-A field-list replacement, the Q-F
field-list replacement, and both explanatory paragraphs from §3 above into one section — every sentence
below is copied verbatim from one of the two arbiter quotes in §3, only their relative order is chosen here):

```
### StudentState (`student-state.schema.json`)
`schema_version`, `format_version_seen`, `syllabi[]` (course codes), `marker {course_code, unit_id,
past_last_unit?}`, `nodes {node_id → {mastery ∈ {fog, cleared, blocked}, correct_count, last_probe?,
next_due?, ladder_rung, remediated?}}`, `trail {segments[] {kind ∈ {course, extension}, course_code?,
node_ids[]}}` (derived, cached), `expedition_log[] {day, item_count, cleared, blocked, abandoned,
diagnosis_events}`, `probe_log[] {day, node_id, item_id, correct, retry}`, `install_day`, `consent_on`.
**No field may name a person, device, account, install or session** (I5); the schema's closed key set is the
guard.

`past_last_unit` (boolean, optional; absent = false): `true` means the marker has been moved past the
course's last unit (v2.7 §4). `unit_id` then names the course's last unit at the time it was set and must
still name a unit of the course.

`remediated` (boolean, optional; absent = false) records that a diagnosis event confirmed this node (probe
outcome `fail`) and showed its one remediation piece (diagnosis W4). It is written `true` only by that step
and only on a node whose `mastery` is `blocked`; it is removed whenever the node becomes `cleared`. A node
blocked by `capped` or by a second miss after the run's Door A event was spent does not carry it. It is a
fact about a node, never about a person, device, install or session (I5).

`schema_version` is **2**. Migration 1 → 2 is the identity: a version-1 document is a valid version-2
document with every `remediated` absent.
```

### 2. `contracts/schemas/student-state.schema.json`

Add to `marker.properties`, after `unit_id`:

```json
"past_last_unit": {
  "type": "boolean"
}
```

Do not add `"past_last_unit"` to `marker.required`. `marker.additionalProperties` stays `false`.

Add to the node-entry `properties` (inside `nodes.additionalProperties.properties`), after `ladder_rung`:

```json
"remediated": {
  "type": "boolean"
}
```

Do not add `"remediated"` to the node-entry's `required` array (`["mastery", "correct_count",
"ladder_rung"]` stays as-is). The node-entry's `additionalProperties` stays `false`.

### 3. `contracts/examples/student-state.json`

Change `"schema_version": 1` to `"schema_version": 2` (line 2). Add one entry to the `nodes` object, after
`exponential-functions`:

```json
"matrix-multiplication": {
  "mastery": "blocked",
  "correct_count": 0,
  "ladder_rung": 0,
  "remediated": true
}
```

Leave `marker`, `exponent-laws`, `exponential-functions`, `trail`, `expedition_log`, `probe_log`,
`install_day`, `consent_on` byte-unchanged (see §6 default 1 for why the marker does not also gain
`past_last_unit`).

### 4. `Packages/Core/Sources/Core/Model/StudentState.swift`

Add `public let pastLastUnit: Bool?` as the last stored property of `Marker`:

```swift
public struct Marker: Codable, Equatable {
    public let courseCode: String
    public let unitId: String
    public let pastLastUnit: Bool?
}
```

Add `public let remediated: Bool?` as the last stored property of `NodeState`:

```swift
public struct NodeState: Codable, Equatable {
    public let mastery: Mastery
    public let correctCount: Int
    public let lastProbe: String?
    public let nextDue: String?
    public let ladderRung: Int
    public let remediated: Bool?
}
```

Do not add `CodingKeys` to either type — `.convertFromSnakeCase` already maps `pastLastUnit` ↔
`past_last_unit` and `remediated` ↔ `remediated` (§3).

### 5. `Packages/Core/Tests/CoreTests/OptionalAbsentTests.swift`

Add one new test to the suite, following the existing `nodeStateOmitsAbsentOptionalKeys` shape
(precondition on the source fixture, decode, re-encode, assert the key is omitted — and, for `remediated`,
also assert the *present* case survives as `true` rather than being dropped):

```swift
@Test("StudentState.Marker/NodeState round-trip the new optional fields (past_last_unit, remediated)")
func markerAndNodeStateRoundTripNewOptionalFields() throws {
    let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent("student-state.json"))
    let sourceJSON = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let sourceMarker = try #require(sourceJSON["marker"] as? [String: Any])
    #expect(
        sourceMarker["past_last_unit"] == nil,
        "fixture precondition failed: marker unexpectedly has past_last_unit")
    let sourceNodes = try #require(sourceJSON["nodes"] as? [String: [String: Any]])
    let sourceExponentLaws = try #require(sourceNodes["exponent-laws"])
    #expect(
        sourceExponentLaws["remediated"] == nil,
        "fixture precondition failed: exponent-laws unexpectedly has remediated")
    let sourceMatrixMultiplication = try #require(sourceNodes["matrix-multiplication"])
    let declaredRemediated = try #require(sourceMatrixMultiplication["remediated"] as? Bool)
    #expect(declaredRemediated == true, "fixture precondition failed: matrix-multiplication.remediated != true")

    let decoded = try CoreCoding.decoder.decode(StudentState.self, from: data)
    #expect(decoded.marker.pastLastUnit == nil)
    #expect(decoded.nodes["exponent-laws"]?.remediated == nil)
    #expect(decoded.nodes["matrix-multiplication"]?.remediated == true)

    let reencoded = try CoreCoding.encoder.encode(decoded)
    let reencodedJSON = try #require(JSONSerialization.jsonObject(with: reencoded) as? [String: Any])
    let reencodedMarker = try #require(reencodedJSON["marker"] as? [String: Any])
    #expect(
        reencodedMarker["past_last_unit"] == nil,
        "re-encoded marker emitted a key for absent optional past_last_unit")
    let reencodedNodes = try #require(reencodedJSON["nodes"] as? [String: [String: Any]])
    let reencodedExponentLaws = try #require(reencodedNodes["exponent-laws"])
    #expect(
        reencodedExponentLaws["remediated"] == nil,
        "re-encoded exponent-laws emitted a key for absent optional remediated")
    let reencodedMatrixMultiplication = try #require(reencodedNodes["matrix-multiplication"])
    #expect(
        (reencodedMatrixMultiplication["remediated"] as? Bool) == true,
        "re-encoded matrix-multiplication lost its remediated:true value")
}
```

### 6. `Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift`

Add one negative control, mirroring the existing `unrecognizedEnumValueFailsDecode` T2 pattern (mutate the
example JSON in memory, decode, expect `DecodingError`):

```swift
// T2 / AC6: `remediated` is Bool? — a non-boolean value fails decode (closed shape, contracts/data-model.md
// § Nulls: "Optional means the key is absent, never null").
@Test("non-boolean remediated value fails decode")
func remediatedNonBooleanValueFailsDecode() throws {
    let data = try Data(contentsOf: Self.examplesDir.appendingPathComponent("student-state.json"))
    var json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    var nodes = try #require(json?["nodes"] as? [String: [String: Any]])
    nodes["matrix-multiplication"]?["remediated"] = "true"
    json?["nodes"] = nodes
    let mutated = try JSONSerialization.data(withJSONObject: json as Any)
    #expect(throws: DecodingError.self) {
        try CoreCoding.decoder.decode(StudentState.self, from: mutated)
    }
}
```

### 7. `pipeline/tests/test_contracts.py`

Add two negative controls, following the file's existing `_errors(name, instance)` pattern (see §3):

```python
def test_node_state_remediated_must_be_boolean() -> None:
    """v1.3.0: schema types StudentState.nodes[].remediated as boolean (arbiter Q-A)."""
    example = json.loads((EXAMPLES / "student-state.json").read_text())
    example["nodes"]["matrix-multiplication"]["remediated"] = "true"
    errors = _errors("student-state", example)
    assert errors, "a string remediated value did not fail validation"


def test_marker_past_last_unit_must_be_boolean() -> None:
    """v1.3.0: schema types StudentState.marker.past_last_unit as boolean (arbiter Q-F)."""
    example = json.loads((EXAMPLES / "student-state.json").read_text())
    example["marker"]["past_last_unit"] = 1
    errors = _errors("student-state", example)
    assert errors, "an integer past_last_unit value did not fail validation"
```

Both rely on `contracts/examples/student-state.json` already carrying the `matrix-multiplication` entry from
step 3 above — land steps 2, 3 and 7 in the same commit (§6 default 6 explains why this cannot be split).

### 8. Smoke check

From the repo root:

```
cd pipeline && uv run pytest tests/test_contracts.py -q
```

must be green, including the two new negative controls; then

```
xcodebuild test -scheme Core-Package -destination 'platform=iOS Simulator,name=iPhone 16'
```

(or the simulator target `scripts/gate.sh` uses) must be green, including
`OptionalAbsentTests.markerAndNodeStateRoundTripNewOptionalFields`,
`DecodeRoundTripTests.remediatedNonBooleanValueFailsDecode`, and the unmodified `decodeRoundTrip`, which now
also round-trips the `matrix-multiplication` entry.

### 9. Error codes and model-calling paths

No error code is added or raised by this task; nothing here is reachable at runtime yet (`Core` types are
inert `Codable` shapes). No model-calling path exists in this task — I2's confidence-threshold/Tier-0-fallback
requirement is not engaged.

### 10. Commit

One commit, since the schema requirement and the data that must satisfy it cannot land separately without
reding a test in between (§6 default 6):

```
contract(data-model): add StudentState.nodes[].remediated and marker.past_last_unit (v1.3.0)
```

Scope: `contracts/data-model.md`, `contracts/schemas/student-state.schema.json`,
`contracts/examples/student-state.json`, `Packages/Core/Sources/Core/Model/StudentState.swift`,
`Packages/Core/Tests/CoreTests/OptionalAbsentTests.swift`,
`Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift`, `pipeline/tests/test_contracts.py`.

## §5 Test plan (seam risk — full plan)

- **T1 happy path.** `OptionalAbsentTests.markerAndNodeStateRoundTripNewOptionalFields` (§4 step 5) proves
  both directions in one instrument: `matrix-multiplication.remediated` decodes to `true` and survives
  re-encode as `true`; `marker.pastLastUnit` and `exponent-laws.remediated` decode to `nil` and re-encode with
  the key omitted, never `null`. The existing, unmodified `DecodeRoundTripTests.decodeRoundTrip` additionally
  proves the whole `student-state.json` example — now carrying both new fields — round-trips
  structurally-equal, because it iterates the fixed 8-file list that already includes `student-state.json`.
- **T2 negative — invalid input rejected at the boundary.** Three controls, one per guard this task adds:
  `pipeline/tests/test_contracts.py::test_node_state_remediated_must_be_boolean` (string value on
  `remediated`), `::test_marker_past_last_unit_must_be_boolean` (integer value on `past_last_unit`), and
  `DecodeRoundTripTests.remediatedNonBooleanValueFailsDecode` (string value, `Core`-side `DecodingError`).
- **T3 error-taxonomy.** Nothing to assert: this task registers no error code and raises none. Recorded
  explicitly so the omission is a decision, not a gap (mirrors task 06.1's T3 disposition).
- **T4 conformance.** `test_schema_is_valid_2020_12`, `test_example_validates["student-state.json"]`,
  `test_every_schema_has_an_example`, and `test_data_bundles_validate` (empty `data/`, PASS by contract) are
  the conformance instruments for the amended schema and example; no new parametrization is needed — they
  already run over every schema and example file.
  `test_transmitted_shapes_reject_identifier_keys["student-state"]` re-proves I5's closed-key guard now that
  the example carries a third node entry and two new schema properties: it walks every object in the mutated
  example and asserts each blocklisted key is rejected at every nesting level, so it exercises the new
  `matrix-multiplication` object too, without any test-file edit.
- **T5 negative control for every regression guard:**
  - Guard "both new properties are typed `boolean`, not left open": the T2 controls above are the negative
    controls — a schema fragment written as `"remediated": {}` (accepting any type) would make
    `test_node_state_remediated_must_be_boolean` FAIL to fail (i.e., it would pass validation and the test's
    `assert errors` would red).
  - Guard "neither field is in its object's `required` array": if an implementer mistakenly added
    `remediated` or `past_last_unit` to a `required` array, the pre-existing `exponent-laws` node entry (no
    `remediated` key) and the pre-existing `marker` object (no `past_last_unit` key) would themselves fail
    schema validation — `test_example_validates["student-state.json"]` reds immediately, with no edit needed
    to prove it: the fixture already is the negative control.
  - Guard "Core types are `Bool?`, not a looser type": `DecodeRoundTripTests.remediatedNonBooleanValueFailsDecode`
    is the negative control — a `NodeState.remediated` typed as `String?` or as a custom lenient decoder would
    accept the mutated `"true"` string and the `#expect(throws:)` would fail to observe a throw.
- **T6 idempotency / no-leak.** Not applicable: `StudentState` is not one of the seven files `BundleIO.write`
  re-encodes (`contracts/data-model.md` § Collections lists it as the separate `(state)` row, not among the
  bundle files `manifest.json` names), and this task adds no runtime writer of any kind. Recorded as a
  decision, not a gap — `BundleIO`'s existing `bundleWriteIsIdempotent` test is unaffected because it never
  touches `StudentState`.

## §6 Decision defaults

- IF the example's `marker` should also carry `"past_last_unit": true` (to mirror the Q-A "Example." bullet's
  positive-case pattern) THEN it should not. Q-A's normative text has an explicit "**Example.**" bullet; Q-F's
  does not (§3, both quoted in full) — the arbiter drew that distinction deliberately, and adding an
  unruled positive-case value would go beyond the normative text. The optional-absent case for
  `past_last_unit` is exercised by the pre-existing `marker` object unchanged, and its presence-and-type
  guard is exercised by AC6/T2's negative control instead.
- IF a node id is needed for the new `remediated: true` example entry THEN use `matrix-multiplication`
  (`contracts/examples/nodes.json:148`) — it is a real node id already present in the sibling example bundle
  and is not yet referenced anywhere in `contracts/examples/student-state.json`, so the addition invents no
  id and collides with neither `exponent-laws` nor `exponential-functions`.
- IF `schema_version`'s own JSON Schema fragment (`{"type": "integer", "minimum": 1}`,
  `contracts/schemas/student-state.schema.json:7-10`) needs to change THEN it does not — it already admits
  the value `2`; only the example document's literal value moves from `1` to `2`.
- IF either new field should be added to its object's `required` array THEN it must NOT be — both arbiter
  rulings state this explicitly ("It is not in `required`" / "It is not required", §3), and the identity
  migration ("a version-1 document is a valid version-2 document with every `remediated` absent") depends on
  absence remaining a fully valid state for both fields.
- IF `IdentifierBlocklistParityTests.swift` or `pipeline/tests/test_contracts.py`'s `IDENTIFIER_BLOCKLIST`
  literal should gain an entry for `remediated` or `past_last_unit` THEN it should not — neither name
  identifies a person, device, account, install or session, and both are already confirmed absent from both
  blocklists (`Packages/Core/Tests/CoreTests/IdentifierBlocklistParityTests.swift:17-19`,
  `pipeline/tests/test_contracts.py:26-36`). Adding them would make the I5 guard reject legitimate state.
- IF a `Core`-side migration function for `schema_version` 1 → 2 should be written in this task THEN it
  should not — `contracts/data-model.md` § Versioning already states `StudentState.schema_version` "is
  migrated forward only (platform W3)", a separate, later task's scope; this task's only obligation is that a
  version-1 document (both new fields absent) remains schema-valid as a version-2 document, which the
  optional-not-required shape already guarantees without any code.
- IF the two schema/type/example edits (step 2, 3, 4) should land in separate commits from their tests (step
  5, 6, 7) THEN they must not — `additionalProperties: false` on both objects means a commit adding the
  schema requirement without a conforming example, or an example key without the schema property, leaves
  `pipeline/tests/test_contracts.py` red; the change is atomic by construction (mirrors task 06.1 §6's "why
  this is not split" reasoning), and only one writer touches each file in this PR.

Standing defaults: identifiers and timestamps are untouched by this task (no id or timestamp field is added);
no model-calling path exists, so no confidence threshold or Tier-0 fallback applies; telemetry is untouched;
no field anywhere identifies a person, device, install or session; no Ministry text, verbatim or paraphrased,
is added by this task.

## §7 Done definition

The task is done when ALL gates pass:

- `cd pipeline && uv run ruff check . && uv run ruff format --check .` clean
- `cd pipeline && uv run pyright` clean (strict) over `tests/test_contracts.py`
- `swift-format lint --strict` clean over `Packages/Core/Sources/Core/Model/StudentState.swift`,
  `Packages/Core/Tests/CoreTests/OptionalAbsentTests.swift`,
  `Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift`
- `cd pipeline && uv run pytest -q` green — including the two new negative controls of §4 step 7
- `Core` build + test green on the iOS simulator (`swift build`; `xcodebuild test -scheme Core-Package`),
  including the new/modified tests of §4 steps 5 and 6 and the unmodified `decodeRoundTrip`
- `contracts/data-model.md` reads `Contract version: v1.3.0`; the commit carries the `contract(data-model)`
  scope named in §4 step 10
- tests green for every case in §5
- conforms to every contract section cited in §3 and §4, and to every invariant listed in §1
