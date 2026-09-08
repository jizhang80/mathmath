# Contracts

Machine-checkable, single-source-of-truth contracts. **This directory is populated in bootstrap Phase 6**
(after the Phase 5 stack lock); nothing here is authored yet. Agents may name these files, but must not
assume their content exists.

## Planned set

| Contract | Covers |
|---|---|
| `domain-glossary.md` | One agreed term per concept: node, edge, course, depth, expectation code, error type, probe, hypothesis, remediation, session, tier |
| `data-model.md` | Node/edge schema (brief §5); ID policy; IndexedDB stores; versioning of shipped assets |
| `graph-constraints.md` | The L0 structural rules plus the in-degree outlier threshold (set empirically at M2) |
| `runtime-tiers.md` | Confidence thresholds, fallback rules, the "never guesses a diagnosis" rule, model-output JSON schemas |
| `content-policy.md` | The paraphrase rule (no verbatim Ministry text), `[SOURCED]`/`[ESTIMATE]` tagging, attribution and link-out |
| `telemetry.md` | Anonymous event schema, opt-in, aggregate-only, the single write path |
| `error-codes.md` | App-level error registry |
| `interaction-contract.md` | Brief §7 expressed as a machine-checkable state machine |
| `ai-usage.md` | Offline content generation: prompts versioned, outputs schema-validated, multi-run intersection for graph edges |

## Enforcement ladder

Wire each contract at the **cheapest rung that actually holds it**:

**type system → static analysis / lint → schema / config check → runtime contract test**

Higher rungs are preferred: they surface failures as build or lint errors at the owner's review layer,
rather than needing a runtime test to expose them.

## Lock-first rule

`data-model`, `graph-constraints`, `content-policy`, `telemetry`, `domain-glossary` and `runtime-tiers`
**lock before any dependent EPIC starts** — retrofitting them corrupts shipped data, the graph, or the
compliance position. Discovery-zone contracts stay open and are finalized just-in-time. A change to a
locked contract is a **versioned** change: it ripples to every conforming EPIC and is flagged by commit
scope so the ripple is auditable.
