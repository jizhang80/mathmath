# TESTER BLOCK: epic 03 task 05
**Class**: bug-found
**Implementer commit**: bbe09c2

## What you tried to test

AC4's closed-key-set boundary: `read(at:)` must throw `CoreError.platformStateUnreadable` for a document
that is otherwise well-formed but carries an **unknown top-level key** — the fourth variant of "undecodable
bytes / schema_version 3 / missing required key / an unknown extra key (closed key set)" this dispatch
asked to verify, and the case `contracts/data-model.md:41-43`'s "Every object schema sets
`additionalProperties: false` — a new field is a versioned change" and I5's "the schema's closed key set is
the guard" require.

Test: `Packages/Core/Tests/CoreTests/StudentStateStoreConformanceTests.swift::readUnknownTopLevelKeyThrows()`
— seeds a `schema_version: 2` document with one extra key
(`"totally_unrecognized_extra_field": "smuggled-value"`) alongside `student-state.schema.json`'s ten
required keys, then asserts `read(at:)` throws `platformStateUnreadable` and leaves the file byte-for-byte
unchanged.

## Why it failed

`read(at:)`'s decode step is `CoreCoding.decoder.decode(StudentState.self, from: originalData)`
(`Packages/Core/Sources/Core/Platform/StudentStateStore.swift:37`). `StudentState` (`Packages/Core/Sources/
Core/Model/StudentState.swift`) is a plain `Codable` struct with **no custom `init(from:)`** — it relies on
Swift's synthesized `Decodable` conformance. Synthesized `Decodable` only reads the keys it declares; it
does **not** reject a container that additionally carries a key it does not recognize. I verified this
directly against a minimal reproduction (isolated, outside the test suite, matching `StudentState`'s own
shape and `CoreCoding`'s `.convertFromSnakeCase` decoder):

```swift
struct StudentState: Codable { let schemaVersion: Int; let formatVersionSeen: String; /* ... */ }
// JSON: {"schema_version":2, ..., "totally_unknown_key":"x"}
try decoder.decode(StudentState.self, from: data)  // succeeds — the extra key is silently dropped
```

So a document with a smuggled top-level key **decodes successfully** and `read(at:)` returns `.loaded`
normally — it never throws. The task spec's own implementation outline (§4 step 2) asserts the opposite as
an established fact: "`CoreCoding.decoder` decode failure (missing required key, wrong type, unknown enum
value, unknown `additionalProperties` — **all already enforced** by `student-state.schema.json`'s shape
mirrored in the Swift `Codable` types)". That claim is incorrect for a `Codable` struct with no explicit
`CodingKeys`/custom decoder — Foundation's `JSONDecoder` has no "reject unknown keys" mode at all (unlike,
e.g., `JSONSchema` validators). The implementer followed the spec's outline exactly (the shipped `read(at:)`
is essentially byte-identical to the spec's own code block); the gap is in the spec's assumption, not a
deviation by the implementer.

- Expected (contracts/data-model.md:41-43, I5): "Every object schema sets `additionalProperties: false` —
  a new field is a versioned change" / "the schema's closed key set is the guard" — an unrecognized
  top-level key should make the document unreadable (`PLATFORM_STATE_UNREADABLE`), not silently pass
  through with the field dropped.
- Actual: `read(at:)` returns `.loaded(state, migratedFrom: nil)` for a document carrying an extra,
  unrecognized top-level key; the smuggled key is simply absent from the decoded `StudentState` (and would
  be silently stripped for good on the next `write(_:to:)`, since the encoder only ever emits declared
  fields) — no error, no signal that the on-disk document did not conform to the closed schema.
- Repro: `git commit b3b941f`; run
  `xcodebuild test -scheme Core-Package -destination "$(scripts/pick-simulator.sh)"
  -only-testing:CoreTests/StudentStateStoreConformanceTests/readUnknownTopLevelKeyThrows`
  (or the whole `Core-Package` test scheme — this is the only failing test in the suite). Committed red and
  unmodified per the hard rules; do not soften the assertion.

## Note

This does not affect I5's PII guarantee in the persisted-forward sense (the extra key never reaches
`StudentState` and is never re-emitted), but it does violate the schema's own closed-key-set contract as an
input-validation guarantee, and it means a truly newer/corrupt document with extra fields is silently
accepted rather than refused per platform W3's "the old file is kept ... nothing deleted, `PLATFORM_STATE_
UNREADABLE`" semantics. Routing back to the implementer/spec-arbiter to decide whether the fix belongs in
`StudentStateStore` (an explicit top-level-keys check before/alongside decode) or is accepted as an
out-of-scope, lower-priority gap given `StudentState.swift` is this task's read-only dependency.
