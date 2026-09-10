# TESTER BLOCK: epic 01 task 01

**Class**: testability-gap
**Implementer commit**: 891ada59bfb952d98709db8f4e512b9c7940c4b1
**Status**: RESOLVED by arbitration 2026-09-09 — see "Arbitration resolution" below. The spec
`tasks/epic-01-task-01-core-bundle-types.md` has been rewritten; the task returns to the implementer.

## What you tried to test

I tried to decode `StudentState` from product code using the same decoder configuration `BundleIO`
and every other `Model/*.swift` type uses — `JSONDecoder.keyDecodingStrategy = .convertFromSnakeCase`
— per `contracts/data-model.md` § Nulls and the task spec's own §4.1 ("`BundleIO` (and any
decoder/encoder built in tests) configures `JSONDecoder.keyDecodingStrategy =
.convertFromSnakeCase`... — no manual `CodingKeys` enum is written on any type except where §4.9
requires an explicit `CodingKeys`... for the I5 reflection guard"). §4.1 presents this as one shared
decoding convention for every bundle type, `StudentState` included.

## Why it could not be written / why it failed

I verified empirically (small standalone Swift script, `JSONDecoder.keyDecodingStrategy =
.convertFromSnakeCase` decoding a type with an explicit `CodingKeys` whose raw value is already
snake_case, e.g. `case courseCode = "course_code"`) that `.convertFromSnakeCase` transforms the
incoming JSON key *before* matching it against a `CodingKeys` raw value. `course_code` in the JSON is
converted to `courseCode`, which then fails to match the explicit raw value `"course_code"`, and decode
throws `keyNotFound`. This is exactly the failure the implementer's commit message and the
`DecodeRoundTripTests.swift` comment (lines 28–33) already document.

The implementer's fix is real and correct as far as it goes (`studentStateDecoder` in
`DecodeRoundTripTests.swift`, a `JSONDecoder()` with `.useDefaultKeys`), but it is **test-local**: it
exists only inside `DecodeRoundTripTests.swift`, a `private` computed property. There is no equivalent
in `Sources/Core`. Today this is latent because `BundleIO` never touches `student-state.json` (by this
task's own scope — `ContentBundle` excludes it). But `Core`'s two `Model/*.swift` decoding conventions
are now mutually incompatible for one of the eight bundle types, and the only correct recipe for that
type lives in a test file.

I wrote my own tests (`ModelDecodeNegativeTests.swift`'s
`outOfEnumMasteryFailsDecode`, `OptionalAbsentTests.swift`'s `nodeStateOmitsAbsentOptionalKeys`) by
constructing `JSONDecoder()` inline with a comment pointing at this block, per the instruction not to
invent a second test-local decoder as a way of papering over the gap — I reused the one convention
that is known to work (`.useDefaultKeys`) rather than adding a third. This lets the suite pass today,
but it does not close the gap: I am duplicating a decoder recipe that belongs in product code.

EPIC 02 (student-state read/write/mutation) and EPIC 03 (App-side bundle + state loading) will need to
decode and encode `StudentState` from `Sources/App` and other `Sources/Core` call sites, not from
`CoreTests`. Without a canonical decoder/encoder exposed by `Core`, each future call site either
silently rediscovers this same failure (a `keyNotFound` that is not obviously about key-decoding
strategy) or reimplements its own local `.useDefaultKeys` decoder, multiplying the workaround instead
of fixing it once — which is exactly what I14 / D42 ("`Core` is renderer-free and single-source" — "L0
and layout exist once, in `Core`") says should not happen for anything the app and pipeline must agree
on.

## Refactor request (testability-gap only)

Expose a canonical decoder/encoder pair for `StudentState` from `Core` product code, e.g.:

- `Packages/Core/Sources/Core/Model/StudentState.swift`: add
  `public static var decoder: JSONDecoder { let d = JSONDecoder(); /* .useDefaultKeys, matching the
  explicit snake_case CodingKeys */ return d }` and a matching `public static var encoder: JSONEncoder`
  on `StudentState` (or a small `StudentStateIO` enum alongside `BundleIO`, whichever shape a future
  01.x task's file scope prefers) — so every consumer (`CoreTests`, and later `App/Sources`,
  `pipeline/` via `core-cli`) decodes/encodes `StudentState` through one function instead of each
  rediscovering the `.convertFromSnakeCase`-vs-explicit-`CodingKeys` incompatibility independently.

This is a product-code change; per my remit I did not make it. I did not soften any test to route
around it — the suite decodes `StudentState` correctly today using the same `.useDefaultKeys` recipe
the implementer's own smoke test already established, and this block file records why that recipe
belongs in `Sources/Core`, not only in `Tests/CoreTests`.

---

## Arbitration resolution (spec-arbiter, 2026-09-09)

**Route**: resolved at the spec level. Not a decomposition problem, not a contract problem, no Q5.

### Findings

| # | Claim | Verification | Classification |
|---|---|---|---|
| 1 | Spec §4.1 (shared `.convertFromSnakeCase`) and §4.10 (explicit snake_case `CodingKeys`) are mutually exclusive; the shared decoder throws `keyNotFound` on `student-state.json`. | Foundation applies `keyDecodingStrategy` to the incoming key and only then initialises the `CodingKey`; an explicit case `schemaVersion = "schema_version"` can therefore never match the already-converted `schemaVersion`. Both mechanisms are present in the shipped code: `Packages/Core/Sources/Core/Model/StudentState.swift:20-31` (explicit snake_case `CodingKeys`) vs `Packages/Core/Sources/Core/BundleIO.swift:24-28` (`.convertFromSnakeCase`). Independently reproduced by the implementer and by the tester's standalone repro. | VALID |
| 2 | The only working `StudentState` recipe lives in a test file. | `Packages/Core/Tests/CoreTests/DecodeRoundTripTests.swift:34-36` (`private static var studentStateDecoder`); duplicated at `OptionalAbsentTests.swift:78` and `ModelDecodeNegativeTests.swift:117`. Nothing in `Sources/Core` decodes `StudentState`. | VALID |
| 3 | The gap violates I14/D42 ("implemented once, in `Core`") and will hit EPIC 02/03. | `CLAUDE.md` I14 and `contracts/data-model.md` opening: "The shapes every bundle file, the student state and `Core`'s `Codable` types share… `Core` decodes exactly these shapes." One shape set implies one coder. | VALID |
| 4 | (Not raised, found in arbitration) The round-trip test passed despite the mismatch because the *encode* side was also mismatched and silently harmless: `DecodeRoundTripTests` encodes `StudentState` with `.convertToSnakeCase`, which is a no-op on an already-snake_case key. | `DecodeRoundTripTests.swift:38-42` + `:87`. | VALID — records why the defect was invisible to the green suite. |
| 5 | (Not raised, found in arbitration) The old §4.1 carve-out pointed at "§4.9", which is `Model/Sources.swift`; the explicit `CodingKeys` were in §4.10. The cross-reference was already broken. | Previous revision of the spec, §4.1 and §4.9/§4.10. | VALID — fixed by removing the carve-out entirely. |
| 6 | A canonical **per-type** coder (`StudentState.decoder`) is the right shape (tester's suggested fix). | Rejected in favour of one coder for the whole wire format: the contract defines one shared shape set, and a per-type coder would institutionalise two conventions rather than remove one. | INVALID (shape only — the underlying request is VALID and granted) |

### Resolution chosen

**One wire format, one key strategy, one coder pair in product code.** The explicit snake_case
`CodingKeys` are removed from `StudentState` and every nested type; `.convertFromSnakeCase` /
`.convertToSnakeCase` are configured once in a new `Packages/Core/Sources/Core/CoreCoding.swift`
(`CoreCoding.decoder` / `CoreCoding.encoder`), used by `BundleIO`, by every test, and by EPIC 02/03.

This is safe for the whole wire format, verified key by key in this run and recorded in the spec's §3
"Wire-key evidence":

- The only dictionary-keyed positions are `StudentState.nodes` (node ids;
  `contracts/schemas/student-state.schema.json:42-44`, `propertyNames` pattern
  `^[a-z0-9]+(-[a-z0-9]+)*$`) and `Node.hintTree` (`error_type_id` slugs,
  `contracts/examples/nodes.json:37,113`). Kebab-case slugs contain no `_` and no upper-case letter, so
  both strategies pass them through unchanged.
- The only digit-bearing key in the seven `Core`-typed bundle files is `sha256`
  (`contracts/examples/manifest.json:15,20,25,30,35`) — all lower-case, no `_`, unchanged in both
  directions. The one digit-adjacent boundary key in `contracts/examples/`, `tier1_available`
  (`contracts/examples/telemetry-batch.json:55`), is in the one file with no `Core` type (AC2).
- No key anywhere in the eight documents contains an acronym run or any other construct the conversion
  cannot express. **No explicit `CodingKeys` is needed anywhere.**

The I5 guard could no longer reflect over `CodingKeys.allCases`, so it changed instrument — to the
**wire key set of the re-encoded document**, which is what `contracts/data-model.md` § StudentState
actually names: "the schema's closed key set is the guard". This is the stronger check (it inspects the
keys written to disk, in the same snake_case vocabulary as the blocklist) and it gains a real negative
control (inject `device_id` into the nested `marker` object; the collector must report the
intersection).

### Spec delta (`tasks/epic-01-task-01-core-bundle-types.md`)

- §2 **file-scope delta**: `Packages/Core/Sources/Core/CoreCoding.swift` added (one new file). Plus a
  standing instruction that any test file added under `Tests/CoreTests/` uses `CoreCoding` and declares
  no coder of its own.
- §4.1 rewritten as the settled convention; the "except where §4.9 requires an explicit `CodingKeys`"
  carve-out is gone. New §4.1.1 specifies `CoreCoding` (computed properties, not `static let` — Swift 6
  strict concurrency; `.sortedKeys` on the encoder carries `BundleIO.write`'s determinism).
- §4.10 `StudentState`: every `CodingKeys` block removed.
- §4.12 `BundleIO`: declares no coder; uses `CoreCoding`.
- §4.13: `studentStateDecoder` and the per-call `decoder:` override removed — all 8 files go through
  `CoreCoding`; the I5 wire-key guard specified here.
- §4.14: `contracts/error-codes.json` recorded as the declared non-wire exception (plain `JSONDecoder`).
- §4.17 (new): the AC9 single-coder scan over `Sources/Core`, with `Tests/CoreTests` explicitly excluded
  and the reason stated.
- §1: I5 and I14 bullets restated; AC1 and AC6 re-anchored; **AC9 new**.
- §5: T1 named as the real-composition test for this seam; T2 extended to the `mastery` mutation; T5
  gains the I5 injection negative control and the AC9 anti-vacuity control.
- §6: three new decision-defaults (no explicit `CodingKeys`, ever; all consumers use `CoreCoding`; no
  exclusion list on the I5 collector). The 01.1a/01.1b split default now places `CoreCoding.swift` in
  the first half.

### What the implementer does next

1. Add `Packages/Core/Sources/Core/CoreCoding.swift` per §4.1.1.
2. Delete every `enum CodingKeys` from `Packages/Core/Sources/Core/Model/StudentState.swift` and update
   its doc comment (the current one states the removed rationale).
3. Replace `BundleIO`'s `private static var decoder`/`encoder` with `CoreCoding.decoder`/`.encoder`.
4. In `DecodeRoundTripTests.swift`: delete `decoder`, `studentStateDecoder`, `encoder` and the
   `decoder:` parameter of `assertRoundTrip`; route all 8 rows through `CoreCoding`. Replace the
   `CodingKeys`-reflection I5 test with the wire-key guard of §4.13 plus its negative control.
5. In `OptionalAbsentTests.swift` and `ModelDecodeNegativeTests.swift`: replace the local
   `decoder`/`encoder` properties and the two bare `JSONDecoder()` calls with `CoreCoding`, and delete
   the comments pointing at this BLOCK.
6. Add the §4.17 single-coder scan to `CoreTests.swift`.
7. Run `scripts/gate.sh` gates 1 and 3.
