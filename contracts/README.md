# Contracts

Machine-checkable, single-source-of-truth contracts (bootstrap Phase 6). Drafted 2026-09-09 from
`docs/domains/*.md`, `docs/idea.md` (D1–D49) and `docs/tech-stack.md`. **Ground truth order:** brief +
amendments → `CLAUDE.md` invariants → these contracts → domain docs → code. A contract never restates a
domain doc's narrative; it fixes the names, shapes, rules and codes every EPIC must conform to (RULE 5).

## The set

| Contract | Status | Enforcement rung (wired) | Covers |
|---|---|---|---|
| [`domain-glossary.md`](domain-glossary.md) | **LOCK-FIRST** | lint: grep gate for banned synonyms (wrap-epic (f)) | one term per concept across doors, graph, content, runtime, pipeline |
| [`data-model.md`](data-model.md) + [`schemas/`](schemas/) | **LOCK-FIRST** | schema: JSON Schema 2020-12 per bundle file, validated by `pipeline/tests/test_contracts.py` against `contracts/examples/` and every file under `data/`; type system: `Core` `Codable` types mirror the schemas (EPIC-time decode test) | ids, versioning, node/edge/region/course/unit/landmark/bundle, student state |
| [`graph-constraints.md`](graph-constraints.md) | **LOCK-FIRST** | runtime contract test: `core-cli validate` (L0) on every bundle, in the pipeline build step and at app load | L0-1 … L0-10, the in-degree outlier rule, trail-segment path rule |
| [`content-policy.md`](content-policy.md) | **LOCK-FIRST** | lint: grep gates (no `verbatim` field, `paraphrase` present, `source_url` on landmarks, `[SOURCED]`/`[ESTIMATE]`, no time estimates — pre-commit + wrap-epic (f)); schema: `source_ref`/`expectation_codes` at-least-one | I6, I11, I15, licensing by tier (D2, D18, D43) |
| [`telemetry.md`](telemetry.md) + `schemas/telemetry-batch.schema.json` | **LOCK-FIRST** | schema: closed batch schema with `additionalProperties: false`; test asserts no identifier-shaped key can validate; wrap-gate W5 endpoint check | D17/D36/D40 event set, allowlist, batch, endpoint |
| [`runtime-tiers.md`](runtime-tiers.md) | **LOCK-FIRST** | type system: `@Generable` result types (EPIC-time); test: adapter-absent suite (I2) | thresholds, fallback rules, "never guesses", availability gating |
| [`error-codes.md`](error-codes.md) + [`error-codes.json`](error-codes.json) | locked (additive) | test: registry ⇔ domain docs round-trip (`test_contracts.py`); type system: `Core` error enum mirrors the registry (EPIC-time) | every code, its domain, recoverability, user-facing text policy |
| [`interaction-contract.md`](interaction-contract.md) | discovery — finalize just-in-time (Demo EPIC) | runtime contract test: state-machine property tests in `CoreTests` (EPIC-time) | the three doors as state machines: expedition, diagnosis, marker/trail |
| [`ai-usage.md`](ai-usage.md) | locked (additive) | schema: `RunOutput` schemas per generation task (EPIC-time); lint: model id must be one named here | offline generation only, model ids, prompt versioning, intersection, verification before persistence |
| [`deployment-model.md`](deployment-model.md) | **LOCK-FIRST** | config check: CI workflow + ruleset JSON are the executable form; network-allowlist test in `App` (EPIC-time) | single deployment, hosts, the one write path, distribution |

Not needed for this project (bootstrap Phase 6 standard set): `api-conventions` (no API of ours),
`feature-flags` (no configurable surface — D24/D25), `rbac-matrix` (no roles), `i18n-conventions`
(English-only, DEFERRED D-1), `event-bus` (in-process notifications are named per domain doc and carried in
`interaction-contract.md`), `information-architecture` (three native screens plus panels; in `map.md`).

## Enforcement ladder

Wire each contract at the **cheapest rung that actually holds it**:

**type system → static analysis / lint → schema / config check → runtime contract test**

Higher rungs are preferred: they surface failures as build or lint errors at the owner's review layer,
rather than needing a runtime test to expose them. The "(wired)" column above names what exists today; a
rung marked *EPIC-time* is owed by the first EPIC that ships the corresponding code and is a wrap-gate item.

## Lock-first rule

`data-model`, `graph-constraints`, `content-policy`, `telemetry`, `domain-glossary`, `runtime-tiers` and
`deployment-model` **lock before any dependent EPIC starts** — retrofitting them corrupts shipped data, the
graph, or the compliance position. Discovery-zone contracts stay open and are finalized just-in-time. A
change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every conforming
EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

## Sign-off

| Contract | Drafted | Owner sign-off |
|---|---|---|
| all of the above | 2026-09-09 (Fable session, Phase 6) | pending |
