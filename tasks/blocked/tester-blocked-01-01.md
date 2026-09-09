# TESTER BLOCK: epic 01 task 01

**Class**: testability-gap
**Implementer commit**: 891ada59bfb952d98709db8f4e512b9c7940c4b1

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
