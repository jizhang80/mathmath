# Domain — verification

Prefix: `VERIFY`. Layer ④ (brief §4.1). Ground truth: `PROJECT-BRIEF-v1.md`, invariants I1–I13.

## Purpose

The only authority on mathematical correctness. It parses the student's LaTeX (MathLive, D9/I10) into
SymPy in a Pyodide web worker, decides each written Step against the one before, reports the first failing
step, and solves the problem so the answer can always be shown (D5, I3). It owns **I1: step correctness is
decided by CAS, never by a language model** (D6). Milestone **M3**; the Pyodide + SymPy first-load
measurement is taken at M4′ (brief §8, §11).

Every verdict reaches the Student through tutoring-session. Offline, it also answers learning-objects'
bundle check of whether a ProbeItem answer is CAS-decidable.

**Seam — verification↔tutoring-session:** one call in, one machine-readable trace out. tutoring-session
sends a Problem and the ordered Steps; verification returns a StepVerdict per step, the FirstFailure (or
none), DomainCheck results and the solved answer. tutoring-session decides what to *do* with a verdict —
classify, hint, backtrack, probe — while verification never sees a node id, ErrorType or Session. No model
output can enter or alter this trace.

## Actors and roles

| Actor | What they can do here | What they cannot |
|---|---|---|
| Student | Submit a problem and steps through the editor; see verdicts and the answer | Override a verdict or loosen the rules |
| Owner | Run the M4′ latency measurement; product-test the flow | Mark a step correct by hand |
| System | Parse, test equivalence, run DomainChecks and solve, in the worker | Accept an unparseable expression as equivalent |
| Local model (Tier 1) | Nothing; it has no code path into this domain (I1) | Produce, adjust, veto or rank a StepVerdict |
| Generation model (offline) | Nothing at runtime | Anything here |

## Core entities

**Problem** — the original question in LaTeX, normalised, with its variable set and derived domain
constraints. Immutable once verification starts.

**Step** — one student-written expression or equation, in submission order, index 0…n; the unit of
judgement. The sequence is what the student wrote, not a model solution.

**StepVerdict** — the decision for one Step against its predecessor, from a closed set: `equivalent`,
`not_equivalent`, `not_parseable`, `domain_violation`. One per Step, carrying the method used (symbolic,
or numeric sampling — Q1) so the trace is reproducible.

**FirstFailure** — the smallest index whose StepVerdict is not `equivalent`, plus that verdict; `none` if
every step holds. This is localisation in brief §7, and it is deterministic.

**DomainCheck** — constraints a valid transformation must respect: log arguments > 0, denominators ≠ 0,
even radicands ≥ 0, plus any the Problem introduces. Computed from the Problem, re-evaluated per Step; a
step dropping or violating one gets `domain_violation`, not `not_equivalent`, because the M4′ error type
"missed domain restriction" depends on that distinction (brief §8).

## Workflows

### W1 — Warm up the CAS

**Pre:** the app has started; platform reports a supported environment (D8).
**Steps:** 1. Platform loads the Pyodide + SymPy assets and owns the visible "loading CAS" state.
2. verification imports SymPy in the worker and runs a trivial round-trip. 3. It publishes readiness;
failure after the retry budget raises `VERIFY_CAS_UNAVAILABLE`.
**Post:** ready or explicitly unavailable, never ambiguous — platform owns the loader UI, verification the
readiness signal. First-load latency is measured at M4′ (brief §8, §11).

### W2 — Verify a step sequence

**Pre:** CAS ready; a Problem and Steps 0…n in LaTeX. Tier 0 throughout; no tier decision exists (I1).
**Steps:** 1. Normalise and parse the Problem, then each Step; a parse failure yields `not_parseable` and
stops the scan. 2. Derive DomainCheck constraints. 3. For each Step *i*, test equivalence against Step
*i−1* (Step 0 against the Problem) under those constraints; a breach yields `domain_violation`. 4. Record
FirstFailure at the first non-`equivalent` verdict; later steps are reported unevaluated. 5. Each step is
bounded by a timeout (Q3); on expiry `VERIFY_TIMEOUT` is raised and the trace returns partial.
**Post:** a trace of StepVerdicts, FirstFailure and DomainCheck results reaches tutoring-session. Bounded
by n steps, each timed out, so it always terminates.

### W3 — Solve for the answer

**Pre:** a parsed Problem. Runs however W2 ended, since answers are never withheld (D5, I3).
**Steps:** 1. Solve symbolically under the DomainCheck constraints. 2. Discard extraneous roots violating
a constraint. 3. If the construct is unsupported, report `VERIFY_UNSUPPORTED`.
**Post:** an answer in LaTeX, or an explicit unsupported result; tutoring-session shows it with the
diagnosis.

## UI surfaces

None owned here. Verdicts render in tutoring-session (`/student/session/...`); the "loading CAS" state
belongs to the platform shell. Confirmed in Phase 4.

## Notifications produced

- `verification.cas_ready` — readiness, load duration. Consumers: platform, tutoring-session.
- `verification.trace_ready` — step count, FirstFailure index or `none`, verdicts and methods. Consumer:
  tutoring-session.
- `verification.unsupported_construct` — construct class. Consumer: tutoring-session.

## Errors produced

| Code | When it fires | User sees | Recoverable |
|---|---|---|---|
| `VERIFY_CAS_UNAVAILABLE` | Pyodide/SymPy fails to load, or the worker dies | "The checker could not start" | Yes, on reload |
| `VERIFY_PARSE_FAILED` | LaTeX cannot be parsed | Step marked unreadable, nudge to re-enter | Yes |
| `VERIFY_TIMEOUT` | A step exceeds the per-step bound | That step undecided, rest of trace stands | Yes, on retry |
| `VERIFY_UNSUPPORTED` | Matrices, MCV4U calculus notation, other out-of-scope constructs | Answer-only mode | No, for that problem |
| `VERIFY_DOMAIN_UNDECIDABLE` | A constraint is not symbolically decidable | Internal; numeric sampling | Yes |

## Invariants enforced here

- **I1 (CAS decides correctness)** — primary owner. The file scope holds no model adapter, no
  `runtime-tiers` import and no network call; StepVerdict comes only from the CAS path and its closed enum
  has no "model says" variant. A spec introducing a model here — ranking verdicts, "helping" the parser,
  explaining a failure inside the trace — is **BLOCKed on I1**; no confidence threshold or fallback makes
  it acceptable, because I1 admits none. Enforced by a typed boundary (one StepVerdict constructor), a
  dependency test over the module graph, and a seam test on the trace.
- **I3 (answers never withheld)** — W3 runs whatever W2's outcome.
- **I10 (structured editor only)** — input is LaTeX from MathLive; no OCR path, no free-text parser.
- **I2** — verification is pure Tier 0, which is why a Tier 0 product is usable at all.

## Open questions

**Q1 — Equivalence strictness.** **Default:** symbolic first (`simplify(a − b) == 0` under the Problem's
assumptions); if inconclusive, numeric sampling at a fixed seed over the constrained domain, the method
recorded in the verdict. **Trade-off:** sampling rescues what SymPy cannot settle, but a sampled
`equivalent` is probabilistic; the fixed seed and recorded method keep it reproducible.
**Ratified 2026-09-08:** default accepted.

**Q2 — A step that is correct but skips ahead.** **Default:** accept it — equivalence to the previous step
is the test, not step size, so three manipulations at once are `equivalent`. **Trade-off:** matches "reads
like a teacher, not an interrogator" (brief §7), but a big leap hides where a later error was seeded.
**Ratified 2026-09-08:** default accepted.

**Q3 — Per-step timeout.** **Default:** 2 s per step, 10 s per problem [ESTIMATE: keeps a 6-step problem
inside the interaction loop; re-set from the M4′ latency measurement]. **Trade-off:** a tight bound turns
hard-but-valid steps into `VERIFY_TIMEOUT`; a loose one stalls the UI with no verdict.
**Ratified 2026-09-08:** default accepted.

**Q4 — Unsupported constructs.** **Default:** report `VERIFY_UNSUPPORTED` and fall back to answer-only
mode — answer shown, step checking off for that problem, no diagnosis. Matrices and MCV4U calculus
notation fall outside M3's starting chain (D14). **Trade-off:** honest under I1/I2, but that student gets
the weakest experience; guessing at partial support would produce wrong verdicts.
**Ratified 2026-09-08:** default accepted.

## Change log

| 2026-09-08 | Drafted (Phase 3b). |
| 2026-09-08 | Phase 3b consistency fixes (event consumers aligned with telemetry's four event kinds). |
| 2026-09-08 | Open questions ratified by owner (all defaults; see docs/plans/phase3b-open-questions.md). |
