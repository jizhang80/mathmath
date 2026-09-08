# Carry-forward — the seed for the next project

> **What this is.** The distilled, model-generation-independent residue of BiteByte v3's Phase-8 capture
> (`docs/lessons.md`, 25 lessons). It is the **only** part of that capture a new project should inherit.
>
> **What this is not.** It is not `lessons.md`, and the next project must not start with a copy of one.
> `lessons.md` is a *capture* — an append-only record of what this build learned, including things that
> were true only of this stack, this agent kit, or this model generation. This file is a *seed* — six
> principles, the controls that enforce them, and the bar that keeps the next capture from growing back
> into 25 unreviewed rules.
>
> **How to use it.** At bootstrap, install §2's controls. Start `lessons.md` empty and admit new entries
> only through §3. Re-read §4–§7 at each Phase-8 capture.

---

## 1. The six principles

Each one survived the filter *"would a stronger model make this stop happening?"* — **no**. These are
information-architecture failures, not attention failures: an agent cannot see what nothing asked it to
look at, and no increase in reasoning quality changes that. Frequency falls with model capability; the
class does not.

### P1 — Evidence must enter at the seam, not below it
A test that constructs internal state directly is not evidence the feature works. Every EPIC that adds a
client↔server, composition-root, queue or auth seam owns **one** test that drives the real composition
across it — real entry, real wiring, real DB, no injected state.
*Why it does not expire:* the defect lives in the wiring between two correct components; a test standing on
the same assumption as the code cannot see it, however well written.
*Source: lessons 11, 23.*

### P2 — An oracle that cannot fail is decoration
A test that exists to prevent a specific regression is run against a simulation of that regression before
it is trusted — a positive/negative control pair. A source-scan, an allowlist sweep or a "never reverts to
X" guard is presumed decorative until it has been proven to go red.
*Why it does not expire:* the failure is that nobody asked the question, not that the answer was hard.
*Source: lesson 15.*

### P3 — State the instrument beside the claim, and name what it cannot see
Any claim resting on a search, a count, a health check or a suite run states the instrument used and what
that instrument excludes. Any check that can return empty declares **in advance** whether empty is PASS or
FAIL. Absence of evidence never reads as evidence of absence.
*Why it does not expire:* a query that cannot see its subject returns empty, and empty is indistinguishable
from a pass. This is epistemics, not diligence.
*Source: lesson 18 (thirteen such claims in one EPIC, four of them the orchestrator's own).*

### P4 — Every shipped artifact is exercised by a gate in the EPIC that ships it
An image, compose file, CLI entry, migration path or runbook command that no task consumes is protected by
no gate. If nothing depends on it, nothing forces it to be true — and it will be green and broken
simultaneously for as long as that holds.
*Why it does not expire:* this is the one failure mode that produces **no signal at all** while it lasts.
*Source: lesson 25 — a `Dockerfile` that could not build survived 34 EPICs with every gate green.*

### P5 — A spec asserts only on rows it created
In any suite sharing state across parallel workers, an assertion on a global aggregate is order-dependent
by construction, whatever the fixture hygiene. Deltas over shared counters are banned. Where the domain
genuinely requires mutual exclusion, serialize with an explicit named mutex — never by relaxing the
runner's parallelism.
*Why it does not expire:* it is a property of the execution model, not of the author's care.
*Source: lesson 24.*

### P6 — A deferral records a measurement and its conditions, never a diagnosis
Any "not now" ledger entry records **what was observed, under what configuration**, plus the revisit
trigger. A diagnosis or a prescribed remedy goes under an explicit `hypothesis (unverified)` label, and the
consuming work re-measures before planning against it.
*Why it does not expire:* the recorded diagnosis is read as ground truth by whoever picks the item up later,
and it is the one part of the entry nobody re-derives.
*Source: lessons 17 and the deferral-discipline pattern. Three of one entry's carried "facts" were false.*

---

## 2. Controls to install at bootstrap

A principle that lives only as prose is re-paid in full by every project. Install these as executable
controls; then the prose above is documentation, not a dependency.

| # | Control | Where it lives | Enforces |
|---|---|---|---|
| C1 | Every EPIC adding a named seam must land one real-composition test before it can wrap | wrap-gate | P1 |
| C2 | Every regression guard ships with its negative control (proof it reds against the broken shape) | tester rule | P2 |
| C3 | Wrap reports and audit findings state instrument + exclusions; every emptiness-capable check declares empty=PASS or empty=FAIL | wrap-gate + agent rule | P3 |
| C4 | CI exercises every shipped artifact (build the image, run the CLI entry, execute the runbook's commands) | CI | P4 |
| C5 | Fixture identity is unique per spec; a lint/grep guard bans global-aggregate assertions and hardcoded date literals | test lint | P5 |
| C6 | The deferral ledger's entry template has an `observed / configuration / trigger` block and a separate `hypothesis (unverified)` block | ledger template | P6 |

Two further controls are cheap and pay for themselves regardless of principle:

- **C7 — derived artifacts are audited against source before use.** Any bundle, summary or context pack
  that quotes a source file is byte-compared before it is consumed, and anything reconstructed is labelled
  inference. *(Mechanize it; do not carry lesson 16's prose. See §5.)*
- **C8 — commit-message and formatting gates run pre-commit, not at wrap.** Every gate-miss of this class
  in Phase 7 was caught late and fixed with a message-only rewrite. Cost is entirely preventable at
  authoring time.

---

## 3. Admission bar for new lessons

A capture session admits an entry only if **both** hold:

1. **No current gate could have caught it.** If an existing control would have caught it and did not fire,
   the finding is a broken control, not a lesson — fix the control.
2. **It has a named graduation target.** A file, a prompt section, a CI line. "Be careful about X" is not a
   target.

And one consequence: **admission implies graduation.** An entry that cannot be turned into a control within
the same session is recorded as an open question with an owner, not as a rule. Without this, the file grows
back to 25 entries that nobody re-reads and nobody can falsify.

Entries that graduate are marked `✅ APPLIED <date>` with the operative site named, and are **not**
carried forward again — the control is the carrier from that point on.

---

## 4. Gates measure the thing, not a proxy — and are audited for it

A gate is a measurement, and measurements drift onto proxies. Phase 7's cascade bar counted `fix:` commits
as a proxy for rework; it fired three times and **none** of those was rework — spec corrections caught
before implementation and a bug-fix EPIC's commissioned repairs both land as `fix:`. The bar was redefined
to count rework only.

*Rule:* at each capture, every quantitative gate states what it actually counts and what it is meant to
detect, and any divergence is closed or the gate is removed. A gate that has never fired truly is as
suspect as one that fires falsely.
*Source: lesson 20.*

---

## 5. What is deliberately not carried

| Not carried | Why |
|---|---|
| Fabricated-quote discipline, stale line-number citations, commit-message gotchas (lessons 16, 13, 10 + addendum) | **Attention failures.** A stronger model plus C7/C8 drives them to near-zero. The durable residue is one sentence: *a derived artifact that diverges from source will be consumed as fact.* That is C7; the war stories are not needed. |
| Pipeline-shaped process rules (lessons 1, 2, 3, 5, 12, 21, 22) | They are meaningful only under the same planner/writer/reviewer/arbiter/architect kit. If that kit is reused, they belong in the **agent prompts** — as lessons 16, 19 and 22 already were on 2026-09-05 — not in a lessons file. If it is not reused, they are noise. |
| Stack facts (lessons 6, 7, 8, 9) | These expire with the toolchain. They belong in the tech-stack preferences file with a review date, and their testkit is inherited as code. |
| Anything already marked graduated (6, 9, 20, 21) | The control is the carrier. Re-carrying the prose duplicates the rule and lets the two drift. |

---

## 6. Known tension to resolve at authoring time

Lesson 19 (*"mirror the existing pattern exactly" copies the pattern's bugs* — a defect shipped in the
first EPIC survived 34 more because a spec said to mirror its shape) points the opposite way from the
reuse-and-freeze rules (settle a shared shape before quoting it; derive allowlists from the registry).

Both are right, and the resolution is 19's own: **cite a precedent for its shape, and state separately the
invariant the new code must satisfy on its own.** This must be an explicit rule in whatever authors specs,
because "follow the existing implementation" is the default habit it has to override.

---

## 7. Produce blind-spot findings deliberately

Every lesson in the Phase-8 capture except P4's came from a wrap report or an audit — that is, from things
that **were caught**. Selection bias guarantees the most expensive class is under-represented: the artifact
nobody looked at emits no signal to capture. Two habits counteract it.

- **Ask the P4 question on a schedule**, not at capture time: *which shipped artifacts and which reachable
  paths have no gate touching them?* Enumerate from the artifact list, not from the test list — the test
  list is exactly the set that is already covered.
- **Require at least one cost-side finding per capture.** Phase 7 produced 25 lessons and not one said an
  activity was not worth its cost. A 34-EPIC run with one owner-stop and nine green audits is consistent
  with a healthy process *and* with gates that are too loose or an escalation bar that is too high; only a
  deliberate look distinguishes them. Absence of a "we did too much" finding is a finding about the capture,
  not about the process.
