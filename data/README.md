# data/

Content bundles consumed by `Core` (shared JSON formats, D33). Shapes: `contracts/data-model.md` +
`contracts/schemas/`. Every `*.json` here is validated by `pipeline/tests/test_contracts.py` against the
schema its filename names, and by `core-cli validate` (L0, `contracts/graph-constraints.md`).

- `demo/` — the Demo's hand-written bundle (DEMO-BRIEF §5; two trails' worth of courses with unit lists, ~20
  nodes, one landmark). Added by the Demo EPIC.
- later: pipeline output bundles, one directory per `bundle_id`, with the L0 report beside them.
