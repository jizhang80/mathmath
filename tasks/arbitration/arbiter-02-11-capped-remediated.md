# ARBITER RULING: task 02.11 — `remediated` on the `capped` branch

**Date**: 2026-09-10
**Spec**: `tasks/epic-02-task-11-diagnosis-machine-seam.md`
**Trigger**: Q4 reconciliation before implementation, dispatched by the orchestrating session. The step-wise ruling
flagged the conflict itself: the spec set `remediated = true` on a `capped` candidate.
**Prior rulings kept intact**: `tasks/arbitration/arbiter-02-11-probe-completed.md` (the `probe_completed` emission
rule and the declined-probe representation) and `tasks/arbitration/arbiter-02-11-stepwise-api.md` (Rulings 1–4:
step-wise API, internal helpers, thin driver, cumulative depth). The operative part of the budget rule that the
step-wise ruling carried over also stays unchanged: a `confirmed` probe at an exhausted budget constructs no
`FurtherLevelOffer`, and the further-level decision is never read.

## Ruling

1. **A `capped` node never has `remediated` written.** `remediated` is set `true` only by the confirmed branch of
   `answerProbeItem`, only on the probed candidate that failed (the internal `remediate` helper). The internal
   `capped` helper calls `MasteryTransitions.diagnosisBlocked` and nothing else. `remediated` passes through
   unchanged (`Packages/Core/Sources/Core/State/MasteryTransitions.swift:95`), so a fresh fog node stays absent
   (absent = false). No other path writes it: `refuted`, declined, unavailable, `noPrerequisite` and
   `decideFurtherLevel`.

2. **The `capped` node is W6's "deeper candidate". It is never the candidate that just failed its probe.** The spec's
   §6 reading ("the same, already-`confirmed`-and-remediated candidate, not a newly discovered one") is overturned.
   That reading makes the probe that failed at the last budgeted level both `confirmed` and `capped`, and that
   cannot satisfy the contracts:
   - If the failed candidate is remediated, it breaks `contracts/data-model.md` § StudentState ("A node blocked by
     `capped` … does not carry it").
   - If it is not remediated, it breaks `contracts/interaction-contract.md` § 4, `probe` bullet (every `fail` →
     "one remediation piece, candidate `remediated = true` once that piece is shown"). It also means the Demo
     (budget 1) would never show a remediation piece.

   The only reading consistent with every source is the one in the domain text:
   - The failed candidate always gets its W4 effects (`blocked`, one remediation piece, `remediated = true`).
   - If no budget remains, W6 runs in the same advance: `hypothesise(originId: candidateId, biasErrorTypeId:
     classify(incorrectAttempts), levelBudget: 1)`.
   - If that query finds a candidate, it is marked `blocked`: no probe, no remediation, no `remediated`, no
     `probeLog` row. It is appended to `blockedNodeIds`, and the terminal is `capped`.
   - If it finds none, the terminal is `confirmed`, because nothing further upstream exists to put on the map.

3. **Depth.** `depthReached` counts only the depth that was probed and remediated, and `depthReached ≤ levelBudget
   ≤ 2` still holds on every path. The W6 node sits one level beyond the budget by definition ("W2 or W4 would
   exceed 2 levels from the origin"). Marking it is "marked on the map only" (I4). It is not a backtrack.

4. **Fringe consequence (why the flag must stay off).** The landed guard is
   `Packages/Core/Sources/Core/State/Expedition.swift:187-194`: `mastery(of: p) == .cleared || (mastery(of: p) ==
   .blocked && isRemediated(p))`, with `isRemediated` = `state.nodes[nodeId]?.remediated ?? false` (`:183-185`).
   Under this ruling:
   - The remediated confirmed candidate unlocks its downstream nodes. On `data/demo`, `polynomials` is unlocked
     through `exponent-laws`.
   - The unremediated W6 node does not unlock its downstream nodes. It still enters the fringe itself through the
     unconditional `∪ {n : mastery(n) = blocked}` term (`contracts/interaction-contract.md` § 2 `compose`).

   The pre-ruling spec gave the capped node `remediated = true`. That opened the guard for a gap the student was
   never shown a remediation for, which is exactly what the contract guard excludes.

No contract text changes. No locked decision changes. Not a Q5.

## Findings analysis

| # | Claim | Verification | Classification |
|---|---|---|---|
| a | `arbiter-02-predispatch.md` § Q-A limits `remediated` to the remediation step, on a blocked node | `tasks/arbitration/arbiter-02-predispatch.md:49-52` (normative data-model text): "It is written `true` only by that step and only on a node whose `mastery` is `blocked` … A node blocked by `capped` … does not carry it"; `:35-37`: blocked sources "diagnosis W4 (confirmed, then remediated)" vs "W6 capped, with no remediation" | VALID |
| b | The EPIC 02 brief §4 item 5 says a capped candidate does not carry it | `docs/epics/epic-02-core-behaviour.md:226-227`: "A `confirmed` candidate carries `remediated = true` once its remediation piece is shown; a `capped` candidate does not (§9 Q-A)"; `:367-368`: "set `true` only by diagnosis W4's remediation step, on a `blocked` node" | VALID |
| c | The contract § 4 capped branch has no remediation piece | `contracts/interaction-contract.md:93-94`: "beyond the budget → `capped`: candidate `blocked`, "further upstream — it's on your map", returned (I4)". It names no remediation. `:86-88` (`probe` bullet): "`fail` → `confirmed` → candidate `blocked`, one remediation piece, candidate `remediated = true` once that piece is shown". The binding contract text on the field is `contracts/data-model.md:143-147` § StudentState, and it wins outright | VALID. Together these two bullets force Ruling 2: a `fail` candidate is always remediated, so the `capped` node must be a different node |
| d | `CLAUDE.md` I4: deeper gaps are marked on the map only | `CLAUDE.md` I4: "**backtrack ≤ 2 levels per session**; **deeper gaps are marked on the map only**"; `docs/domains/diagnosis.md:88-91` W6: "no probe, no remediation; the deeper candidate is marked `blocked` in `StudentState`"; `:79-80` W4 step 3: "If budget remains and the candidate itself has unmastered prerequisites, offer … beyond the cap, W6" | VALID. The W6 node is the next gap upstream, marked without a probe |
| e | The § 2 fringe guard needs the flag off on a capped prerequisite | `contracts/interaction-contract.md:32-37`; `Expedition.swift:183-194` (quoted in Ruling 4) | VALID |
| f | The remediation path still sets `remediated = true`, and unconfirmed/declined/unavailable never set it | Spec §4 step 3c: the declined and unavailable branches touch no node. §4 step 3d: the refuted branch leaves state unchanged, and `remediate` runs only in the ≥ 1-incorrect branch | VALID as stated. Kept, and now asserted explicitly (AC6b, AC7, AC9, T5) |
| g | (Found in P2) W6 on the real `data/demo` is reachable at budget 1 in both forms | `data/demo/edges.json:21-22` (`solving-linear-equations` → `exponent-laws`, the only edge into `exponent-laws`) and `:37-38` (`exponent-laws` → `polynomials`). A check at `polynomials` makes `exponent-laws` the candidate (0.95 against 0.7, `:229-230`). With `solving-linear-equations` fog, the terminal is `capped`; with it `cleared`, the terminal is `confirmed` | VALID. Pinned in AC6/AC6b/AC11 |

## Spec sections changed

- **§1**
  - I4 bullet.
  - AC6 (capped: `[c, d]`, `d` unremediated, exact event array now with `.graphPrerequisiteReturned` and a second
    `.diagnosisNodeBlocked`).
  - New AC6b (exhausted budget, no deeper gap → `confirmed`).
  - AC7 (asserts `remediated == true`).
  - AC8 and AC8b (three and two blocked ids, the capped node unremediated).
  - AC9 (rewritten).
  - AC11 (adds `confirmed`).
  - AC12 (the candidate is `remediated`).
  - AC13 (the Q-A property).
- **§3**
  - The capped-anchor paragraph is rewritten.
  - Added quotes: `data-model.md` § StudentState `remediated`, `interaction-contract.md` § 2 `compose` guard,
    `Expedition.swift:183-194`, `MasteryTransitions.swift:85-98` in full, `CLAUDE.md` I4, and this ruling.
- **§4**
  - Step 3d, exhausted-budget branch (W6 deeper query).
  - Step 4 note.
  - Step 5: `capped` helper.
- **§5**
  - T1 terminals and `remediated` assertions.
  - T4 I4.
  - T5: the `remediate` control is retargeted, and three new controls are added (capped writes `remediated`;
    capped applied to the probed candidate; always-capped).
  - T7 exhausted-budget sentence and the Q-A property.
  - T8 list.
  - T9 step 5 and asserts.
- **§6**
  - The exhausted-budget bullet is replaced.
  - New bullets: W6 query budget, W6 code mapping, an already-blocked W6 node, W6 depth.
  - `fogDefault` is extended to the W6 node.
  - The `remediated` standing default is tightened.

§2, §7, the step-wise API surface and the `probe_completed` rule are unchanged.
