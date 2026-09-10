# Contract write authorization — task 01.7a (orchestrating session, 2026-09-09)

Task 01.7a amends `contracts/data-model.md` § Probe answer derivation to v1.2.0. `contracts/` is READ-ONLY
to every task except where an authorization like this one is recorded, on the precedent of task 01.6.1
(which carried the owner's Q5 ruling, `tasks/blocked/Q5-RULING-01-07.md`).

## What authorizes it

A security defect in the shipped implementation of the algorithm that contract describes, found by the 01.7
tester and **reproduced directly by the orchestrating session** before any fix was designed:

```
().__class__.__bases__[0].__subclasses__()
```

parses and executes through `sympy.parse_expr` under the shipped `ALLOWED_NAMES` and `TRANSFORMATIONS`,
returning 520 live classes including `subprocess.Popen`. The tester confirmed one further lookup reaches a
real shell command executed through `derive_from_check`'s own parse path. The vector uses **zero**
allow-listed names — `()` is a bare tuple literal — so it is independent of the separate `Symbol`/`Integer`
question, and a name allow-list cannot gate it.

Mechanism, confirmed by the spec-architect against the pinned sympy 1.14 source: `parse_expr` is
`eval(code, global_dict, local_dict)`, and `auto_symbol` carries an explicit `# Don't convert attribute
access` guard, so a dotted chain reaches `eval` untouched.

## Why it could not wait for the owner

This is not a product decision. The contract states a security property — "any other name parses to a free
symbol; calling one raises" — that its own described mechanism does not deliver. Correcting a contract that
misdescribes its algorithm's safety is engineering, not business judgment, and the owner has directed that
technical questions be resolved without a Q5 stop.

Severity is not academic: `check` strings are hand-authored today, but the generated-content EPICs (05–09)
produce them with a model. A model-generated `check` reaching an escapable parser would let model output
execute arbitrary code — a worse breach of I1 than the problem `check` was introduced to solve.

## Scope of the authorization

`contracts/data-model.md` § Probe answer derivation ONLY — the two passages pinned verbatim in task 01.7a's
§4 step 1. Version → **v1.2.0** (MINOR: two of the three deltas are new normative rules changing which
inputs are accepted, which is not editorial; no schema, example, `Core` type, error code or D-number
changes). Commit scope `contract(data-model)` per `contracts/README.md`. No other contract, and nothing
under `contracts/schemas/` or `contracts/examples/`, may be touched.

The second, smaller delta rides along: the contract named **nine** allowed names where the algorithm needs
**eleven** — the nine semantic names plus the structural constructors `Symbol` and `Integer`, which
`standard_transformations` mechanically injects for every bare name and integer literal. The tester
reproduced the `NameError` that the literal nine-name version raises on all 20 checks. An implementer
working from the uncorrected contract would fail.
