# EPIC 01 — acceptance report

**EPIC:** 01 — Core data + L0 + layout + demo bundle + rendering spike (Foundation).
**Branch:** `epic-01-core-data-l0-layout-demo-bundle` · 42 commits · wrapped 2026-09-09.
**Brief:** [`docs/epics/epic-01-core-data-l0-layout-demo-bundle.md`](../epics/epic-01-core-data-l0-layout-demo-bundle.md), as amended 01.05.1 and 01.07.1.
**Plan:** [`docs/plans/epic-01-task-plan.md`](../plans/epic-01-task-plan.md).

Every claim below names the instrument that produced it and what that instrument excludes (C3).

## 1. Gate results

| Gate | Result | Instrument | Excludes |
|---|---|---|---|
| (a) Typecheck | PASS | `pyright` strict over `pipeline/` — 0 errors, 0 warnings | Swift's typecheck is the build in (d) |
| (b) Lint | PASS | `xcrun swift-format lint --strict --recursive` over `Packages`, `App/Sources`; `ruff check pipeline` | — |
| (c) Format | PASS | `ruff format --check pipeline` | — |
| (d) Tests | PASS, with one caveat in §7 | `swift build -c release --product core-cli`; `xcodebuild test -scheme Core-Package` (**82 tests, 13 suites**); `-scheme Rendering` (**35 tests, 6 suites**); `xcodebuild build -scheme mathmath`; `pytest` (**155 passed**) — all on `platform=iOS Simulator,name=iPhone Air,OS=26.5` | Simulator only. **No agent claims physical-device verification (D29)** — the Demo/M3 product test on a real device is the owner's and has not been performed |
| (e1) Commit-message lint | PASS | `conventional-pre-commit` commit-msg hook ran on every commit; no `--no-verify` was used | — |
| (e2) CI | see §8 | `gh pr checks --watch` on the PR | Pending at time of writing |
| (f) Contract conformance | PASS, one recorded judgment | greps below | — |
| (g) Cross-EPIC audit | N/A | Every 3 EPICs; this is EPIC 01 | — |
| (h) Contract version bump | PASS | §4 | — |
| (i) DEFERRED.md | PASS — nothing new deferred; see §6 | `docs/DEFERRED.md` unchanged this EPIC | — |
| (j) C1 seam test | PASS | §5 | — |
| (k) C4 artifact coverage | PASS | §3 | — |
| (l) C3 instrument beside claim | PASS | this document | — |

### (f) conformance greps

| Check | Result | Instrument |
|---|---|---|
| no `print(` outside CLI entry points | PASS (0 hits) | grep over `Packages/Core/Sources/Core`, `pipeline/src`, excluding `# noqa: T201` |
| no `TODO`/`FIXME`/`XXX` | PASS (0 hits) | grep over `Packages/*/Sources`, `pipeline/src`, `App/Sources` |
| no `try!` / `as!` | PASS (0 hits) | grep over `Packages/*/Sources`, `App/Sources` |
| no bare `# type: ignore` | PASS (0 hits) | grep over `pipeline/src`; every suppression is `# pyright: ignore[<rule>]` with an inline reason |
| **I5** no identifying fields | PASS (0 hits) | grep over `contracts/schemas/`; plus `IdentifierBlocklistParityTests` asserts the Swift blocklist equals `test_contracts.py`'s at test time |
| **I6** no `verbatim` key; every node has `paraphrase` | PASS | grep over `data/`, `contracts/examples/`; all 20 demo nodes carry a `paraphrase` |
| **I8** L0 green on every versioned graph artifact | PASS | `core-cli validate data/demo` → `passed: true`, 10 checks, every violation list empty. `core-cli validate contracts/examples` → `passed: true`, 10 checks |
| **I14** `Core` imports Foundation only | PASS | `grep '^import ' Packages/Core/Sources/Core` → `import Foundation` only. `CoreCLI` is a separate target and may import `Core`. Boundary test present and green, walking `Sources/Core` recursively |
| **I15** every shipped landmark has `source_url` | PASS | `data/demo/landmarks.json` — 1 landmark, `source_url` present, live-fetched 2xx in `pytest` |
| **R-6** no hardcoded ISO dates in test fixtures | PASS **by recorded judgment** — see below | grep over `Packages/*/Tests`, `pipeline/tests` |
| **I11** quantitative claims tagged; no time estimates | PASS | `no-time-estimates` pre-commit hook green on every commit |

**R-6 judgment.** The grep hits two things, neither of which is what R-6 targets. (1) `built_at` in the L0
manifest fixtures — a schema-**required** field of the bundle shape (`manifest.schema.json`), modelled as a
plain `String` on `Manifest` and never compared to anything; `grep -rE "Date\(\)|datetime\.now|utcnow|time\.time"`
over `Packages/Core/Sources/Core` and `pipeline/src` returns **zero hits**, so there is no clock dependency
anywhere and no injected clock to use instead. Also, `Fixtures/l0/valid/` is required to stay byte-identical
to `contracts/examples/` (task 02b AC4), so this literal cannot be changed on one side alone. (2) Dates in
docstrings and comments in `pipeline/tests/test_verify_allowlist_closure.py`, recording when a finding was
made — documentation, not assertions. R-6 targets fixtures whose **outcome** depends on a hardcoded date
rather than an injected clock; nothing here does.

## 2. Tasks completed

| Task | What it shipped |
|---|---|
| 01.1 | `Core` `Codable` types for all seven bundle files + `StudentState` + `CoreError` + `BundleIO` + `CoreCoding` (the single wire coder) |
| 01.2 | L0-1 … L0-10 in `Core` as one pure `validate`, the contract report shape, 14 negative-control fixtures |
| 01.3 | Deterministic region-constrained force layout — pure function, injected splitmix64 PRNG, one `LayoutConfig`, point-in-polygon clamping |
| 02b | Corrected L0-9 successor semantics (see §9) |
| 01.4 | `core-cli validate|layout|version`; pipeline wrappers `cli.py` and `bundle.py`; the C1 seam test |
| 01.5 | `data/demo/` — 14 regions (10 + 4 horizon), 20 nodes, 40 probe items, 19 edges, 2 courses, 1 landmark |
| 01.6 | `Rendering.RenderCheck` bundle scan + the spike outcome record |
| 01.6.1 | Contract v1.1.0 — `ProbeItem.check`, `Landmark.source_title` (owner Q5 ruling) |
| 01.7 | Pipeline content verification — CAS answer re-derivation, distractor tags, live landmark resolution |
| 01.7a | Contract v1.2.0 — closed the CAS parse sandbox (see §9) |

## 3. (k) C4 artifact → gate coverage

| Artifact | Gate that exercises it |
|---|---|
| `Core` library | `xcodebuild test -scheme Core-Package` — 82 tests |
| `core-cli` binary (`validate`, `layout`, `version`) | `swift build -c release --product core-cli`; exercised as a **real subprocess** by `pipeline/tests/test_core_seam.py` (25 tests) over real bundle directories |
| App build | `xcodebuild build -scheme mathmath` on the simulator |
| L0 checker | `core-cli validate` over `data/demo` and `contracts/examples`; 14 negative-control fixtures in `L0CheckerTests` / `L0CheckerContractTests` |
| Layout engine | `LayoutTests` + `LayoutRegressionTests` — containment per node, determinism both ways, splitmix64 known-answer vectors |
| `data/demo/*.json` (7 files) | `test_contracts.py::test_data_bundles_validate` (schemas); `core-cli validate`; `test_demo_bundle_shape.py` (counts, tags, landmark shape) |
| `Rendering.RenderCheck` | `xcodebuild test -scheme Rendering` — 35 tests; bundle scan over all 143 strings |
| Rendering spike outcome record | `BundleRenderCheckTests` asserts every id it names exists in the bundle |
| `pipeline` `verify/` package | `test_demo_bundle.py` + 5 contract suites — 155 pytest total |
| `contracts/schemas/*` | `test_contracts.py` — every schema valid Draft 2020-12, every example validates |

No artifact is without a gate.

## 4. Contracts touched

| Contract | Version | Change | Authorization |
|---|---|---|---|
| `contracts/data-model.md` | v1.0.0 → v1.1.0 → **v1.2.0** | v1.1.0 added `ProbeItem.check` and `Landmark.source_title`; v1.2.0 corrected § Probe answer derivation — an AST-shape allow-list, and the true name list | v1.1.0: owner Q5 ruling, `tasks/blocked/Q5-RULING-01-07.md`. v1.2.0: orchestrating session, `tasks/blocked/AUTHORIZATION-01-07a-contract-write.md` |
| `contracts/content-policy.md` | v1.0.0 → **v1.1.0** | answer re-derivation is now unqualified; § Landmarks asserts `source_title`, never `name` | owner Q5 ruling |
| `contracts/schemas/nodes.schema.json`, `landmarks.schema.json`, `contracts/examples/*` | — | `check`, `source_title` | same |
| `contracts/graph-constraints.md`, `error-codes.*`, `domain-glossary.md`, `ai-usage.md` | unchanged | — | — |

Commit scopes `contract(data-model)` / `contract(data-model,content-policy)` per `contracts/README.md`.

## 5. (j) C1 seams

| Seam | Test | Both sides real? |
|---|---|---|
| **pipeline ↔ `core-cli` (D42)** | `pipeline/tests/test_core_seam.py` | Yes — a real `core-cli` subprocess against a real bundle directory. No subprocess mock, no stub report; a missing binary FAILS rather than skips, asserted by `test_seam_fails_loudly_when_core_package_is_unbuildable` and a source scan for skip tokens |
| **pipeline ↔ the live landmark source (I15)** | `pipeline/tests/test_verify_landmarks_contract.py` | Yes — a real HTTPS fetch of `laws-lois.justice.gc.ca`. Negative control uses a real 404 |

The `Core` ↔ render-layer seam is **not crossed** in this EPIC and is asserted negatively by the recursive
import-boundary test. The bundle-loader ↔ `Core` validation seam is EPIC 03's and was not pulled forward.

## 6. Deferrals

Nothing new deferred. Two items are recorded in `docs/plans/epic-01-task-plan.md` as wrap-ledger entries
rather than deferrals, because each is a **statement of where enforcement lives**, not postponed work:
`manifest.files[].name`'s closed enum and `landmarks.region_ids`' horizon narrowing are enforced by pipeline
JSON-Schema validation, not by `Core`/L0.

**One item for the owner, not blocking, before the generated-content EPICs (05–09):**
`contracts/content-policy.md` promises hints a `render_fallback` escape hatch that the schema provides
nowhere — `render_fallback` exists only on the probe-item object. For hints and explanations the only remedy
is rewriting prose. Three options, all contract edits: add `render_fallback` at node level; narrow the
contract to prompts and choices and make "no LaTeX in hints" an enforced containment rule; or declare
prose-rewrite the sole remedy explicitly. Full wording in `tasks/blocked/RESOLVED-arbiter-01-06-latex-enumeration.md`.

## 7. Test-suite determinism — an honest caveat

Gate (d) requires the suite to be fast and deterministic. It is fast (pytest ~8s; Core 0.06s; Rendering 0.01s).
On determinism I record an unresolved observation rather than a clean bill:

**One `pytest` run reported `1 failed, 154 passed`.** I could not reproduce it. Twelve subsequent full-suite
runs — five in fixed order, five in default order, two under deliberate CPU contention with concurrent
`swift test` runs — were all `155 passed`. The failing test was not captured before the run scrolled, and
re-running with `-rf` did not reproduce it. The most likely cause is the live HTTPS fetch in the landmark
suite, which is the only non-hermetic test in the repo; twenty-three landmark-selected runs were green.

This is exactly the risk planner note [6] anticipated: a live network call inside the gate can red for a
non-code reason. **The design intent is deliberate** — I15 says an unresolvable landmark is a genuine
blocking signal and must never be mocked or skipped into vacuity. But that intent covers *the source being
gone*, not *the network blipping*, and the two are indistinguishable to the current assertion.
**Recommendation for EPIC 02 or the first CI flake, whichever comes first:** distinguish them — e.g. retry
a transport-level failure a bounded number of times while still failing hard on a 4xx/5xx or a missing
`source_title` — rather than weakening the assertion. Not fixed here: it is out of this EPIC's scope and I
would rather record it precisely than paper over it.

## 8. CI

Pending — see the PR. Both required jobs (`Swift (Core + App, iOS simulator)`, `Python pipeline`) must be
green on the PR run, and on the push-to-`main` run after merge.

## 9. (R-7) `fix:`-commit table and cascade check

| Commit | Subject | Cause | Task risk tier | Rework or output |
|---|---|---|---|---|
| `8e2e313` | `fix(core): L0-9 accepts non-resident next_courses targets` | `contract-gap` | seam (01.2) | **rework** |

**Totals: 1 `fix:` commit — 1 rework, 0 output.**

Three further commits corrected shipped code without carrying the `fix:` prefix. Counting them is the honest
reading of "rework", so they are listed rather than hidden by prefix:

| Commit | Subject | Cause | Task risk tier | Rework or output |
|---|---|---|---|---|
| `52387f4` | `refactor(core): single wire coder in CoreCoding, drop explicit CodingKeys` | `logic` (spec mandated two mutually exclusive decoding conventions) | seam (01.1) | rework |
| `6439815` | `test(core): tighten the AC6 bare-literal scan to match the criterion` | `gate-miss` (the shipped guard was weaker than its own acceptance criterion) | seam (01.3) | rework |
| `8320c0f` | `contract(data-model): close the CAS check parse sandbox with an AST-shape allow-list (v1.2.0)` | `contract-gap` (the contract asserted a security property its mechanism did not deliver) | seam (01.7) | rework |

**Substantive rework total: 4.** Spec and document corrections caught before implementation (touching only
`tasks/**` or `docs/**`) are excluded, per the counting rule.

**Cascade check: does not fire.** The rule requires *this and the previous EPIC* each to land with > 3
rework `fix:` commits. EPIC 01 is the first EPIC, so there is no previous EPIC and the two-EPIC condition
cannot be met. By prefix the count is 1; by substance it is 4 — recorded here so EPIC 02's wrap can compare
against a real number rather than a flattering one. **If EPIC 02 also lands 4 substantive rework commits,
surface the Q5 then.**

**Tester tier-upgrades (R-3):** none. Every task was scoped `seam` from the start.

## 10. Escalations during the run

| # | Raised by | Question | Resolved at | Owner needed? |
|---|---|---|---|---|
| 1 | planner | Brief named `data/demo/l0-report.json`, which breaks `test_data_bundles_validate` | `brief-amender` — the report is `core-cli validate` stdout, per `graph-constraints.md` § Report shape | No |
| 2 | tester (01.1) | Shared decoder and explicit `CodingKeys` are mutually exclusive in Foundation | `spec-arbiter` — one wire coder, `CoreCoding` | No |
| 3 | reviewer (01.4) | A `core_cli.py` submodule would shadow `__init__.py`'s `core_cli` function | `task-writer` retry — renamed the submodule to `cli.py` | No |
| 4 | reviewer (01.5) | L0-9 rejected the `next_courses` the brief mandates | `spec-arbiter` → `spec-architect`. Decided by `contracts/examples/courses.json` itself failing L0-9 under the shipped reading | No |
| 5 | reviewer (01.6) | `data-model.md` § Text vs `content-policy.md` naming hints | `spec-arbiter` — broad superset satisfies both; the EPIC brief states the scan scope | No |
| 6 | arbiter (01.7) | ProbeItem schema is closed; no CAS-checkable field; the brief's "all are simple" premise is false | **Q5 — owner ruled: extend the schema** | **Yes** |
| 7 | arbiter (01.7) | The landmark-name page assertion is unsatisfiable | **Q5 — owner ruled: assert `"Interest Act"`** | **Yes** |
| 8 | implementer (01.6.1) | Non-optional `sourceTitle` breaks 19 L0 fixtures the spec put out of scope | orchestrating session — 02b's AC4 requires the fixtures to follow `contracts/examples/` | No |
| 9 | **tester (01.7)** | **The CAS parse environment is escapable to arbitrary code execution** | `spec-architect` → task 01.7a, contract v1.2.0 | No |

Two owner stops, both genuine (they changed a contract and the product's verification model). The owner has
since directed that technical questions be resolved without a Q5 — recorded and applied from escalation 8
onward.

## 11. The finding worth carrying forward

Escalation 9 is the one to remember. `contracts/data-model.md` v1.1.0 specified a "closed name allow-list"
and asserted that "any other name parses to a free symbol; calling one raises". That is true of names and
says nothing about attribute access. `sympy.parse_expr` is `eval(code, global_dict, local_dict)`, and
sympy's `auto_symbol` carries an explicit `# Don't convert attribute access` guard, so a dotted chain reaches
`eval` untouched:

```
().__class__.__bases__[0].__subclasses__()
```

parsed and executed, reaching 520 live classes including `subprocess.Popen` — using **zero** allow-listed
names. Reproduced by the orchestrating session before any fix was designed.

It was found because the tester was charged to *attack* the allow-list with concrete escape attempts, not to
*test* it. The spec had passed review; the implementation was well-documented and defensible; the eleven
names were justified and harmless. The defect was in the shape of the idea — a name allow-list is not a
sandbox — and only an adversarial attempt surfaced it. **The generated-content EPICs (05–09) produce `check`
strings with a model**, so an escapable parser would have let model output execute arbitrary code: a worse
breach of I1 than the problem `check` was introduced to solve. Fixed in v1.2.0 with an AST-node whitelist,
verified independently: every attribute-chain variant is rejected, and all 20 `check` objects still derive
their recorded answers unchanged.

## 12. Physical-device verification

**Not performed, and not claimed.** Per D29 the Demo/M3 product test on a physical device is the owner's
delivery verification. Every result in this report is from the iOS Simulator (`iPhone Air`, OS 26.5) or the
host toolchain.
