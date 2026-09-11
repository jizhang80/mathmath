# Epic 04 · Task 01: Contract v0.9.3 — answer-card timing, summary tint, in-run log entry (arbiter-04 Q-A/Q-D/Q-G; glossary v1.0.1, Q-B reconciled)

---
epic: 04
task: 01
slug: contract-interaction-card-timing-summary-tint
kind: feat
risk: seam
depends_on: [none]
model: sonnet
---

## §1 Goal & acceptance criteria

Goal: bump `contracts/interaction-contract.md` from v0.9.2 to v0.9.3, closing the two remaining
§ Finalization items ("the timing of the answer card; whether the summary shows region tint deltas") with
arbiter-04's exact ruling text (Q-A), and recording the in-run write-ahead log-entry behaviour (Q-G) as a
third new § 2 bullet, with no `docs/domains/expedition.md` edit (Q6's ratified text already says "a
terminated run is logged as abandoned and the next launch starts fresh" and needs no change — confirmed by
direct read below). In the same task, bump `contracts/domain-glossary.md` from v1.0.0 to v1.0.1, landing the
Remediation clarification and the new Error-type definition in the text reconciled by
`arbiter-04-hint-fallback-reconciliation.md` Rule 5 (which supersedes the "generic tier-1 hint" wording of
arbiter-04 § Q-B, but not its remediation-selection order, its I6/I3 notes, or its instruction not to touch
`Classify.swift` or 02.11 — those parts stand). This cascades three edits to `docs/domains/diagnosis.md` (W3
step 1's copy fix, Q-D; § Core entities Remediation and § UI surfaces, both Q-B as amended by Rule 5) and
five spelling/definition edits plus a changelog row to `docs/domains/learning-objects.md` (Rule 5). It lands
two `docs/DEFERRED.md` entries (region tint deltas, Q-A; hint tiers 2–3, Q-F) — this task is the single EPIC
04 writer of `docs/DEFERRED.md`. This is a documentation/contract-only, code-free change: no schema, no
`Core` type, no pipeline module, no `data/demo` file, and no `contracts/error-codes.json` entry is touched.

**Pre-state.** This task runs on branch `epic-04a-door-core`, after EPIC 03 has merged and its task 03.1 has
landed `contracts/interaction-contract.md` v0.9.2. The v0.9.2 pre-state text this task edits in place is
quoted verbatim in §3 below, sourced from `tasks/epic-03-task-01-contract-interaction-marker-unit-list.md`
(the spec that lands it) — not from the pre-EPIC-03 v0.9.1 text on `main` today. `contracts/domain-glossary.md`
is unaffected by EPIC 03, so its pre-state is the current v1.0.0 text on `main`, read directly and quoted in
§3.

Invariants in play:

- **I2** — not engaged as a model-calling path (this task ships no code). The landed text matters to I2
  downstream: the domain-glossary Remediation clause and the `docs/domains/learning-objects.md` W2 edit state
  that the hint fallback is `hint_tree["none-of-these"][0]`, else the `paraphrase`, and **never another
  ErrorType's hint** — so task 04.3's `Core` resolver is not misdirected into a guessed diagnosis by a stale
  doc.
- **I3** — the landed "Answer card (timing)" bullet states explicitly that no next item, probe item,
  hypothesis card, remediation, terminal line or summary is reachable before the continue tap; the reconciled
  Remediation text keeps a non-empty piece on every path (paraphrase alone when no hint key resolves), so
  nothing is ever withheld.
- **I5** — not engaged: no field, no identifier is added or changed by any edit in this task.
- **I6** — not engaged directly (no `paraphrase` field is touched), but the landed Remediation text is
  precise that the fallback piece is the node's own `paraphrase`, never Ministry text.
- **I14** — the landed "Answer card (timing)" bullet fixes that "continue" is a `Core` façade entry point, not
  an App-only presentation flag, keeping the I3 guard assertable in `CoreTests` by downstream tasks; this task
  itself writes no second implementation of anything.
- **I15** — not engaged: no landmark field is touched.

Acceptance criteria (each independently verifiable):

- AC1: `contracts/interaction-contract.md`'s `Contract version` line reads `v0.9.3`, and the Source sentence
  is appended (not replaced) with the exact v0.9.3 resolution clause, per §4 step 1. Instrument: `rg -n
  "Contract version" contracts/interaction-contract.md`.
- AC2: § 2 Expedition carries a new bullet, **byte-identical** to
  `tasks/arbitration/arbiter-04-predispatch.md:79-82`, inserted immediately after the existing `answer(item)`
  bullet and before the "Numeric normalisation" bullet. Instrument: `rg -n "Answer card \(timing\)"
  contracts/interaction-contract.md`.
- AC3: § 2 Expedition carries two new bullets, **byte-identical** to
  `tasks/arbitration/arbiter-04-predispatch.md:86-92`, inserted immediately after the existing `end` bullet
  and before the "**Properties (CoreTests):**" paragraph. Instrument: `rg -n "Summary content|In-run log
  entry" contracts/interaction-contract.md` returns one match each.
- AC4: § Finalization owed by the Demo EPIC is replaced with the exact paragraph of
  `tasks/arbitration/arbiter-04-predispatch.md:96-98`, ending "Bump to v1.0.0 on wrap." with no item left
  listed as owed. Instrument: `rg -n "Nothing remains owed" contracts/interaction-contract.md`; `rg -n "the
  timing of the answer card; whether the summary" contracts/interaction-contract.md` returns no match (the
  old open-item sentence is gone).
- AC5: `contracts/domain-glossary.md`'s `Contract version` line reads `v1.0.1` and matches
  `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:111` exactly (the reconciled header, not
  arbiter-04 § Q-B's superseded header). Instrument: `rg -n "Contract version" contracts/domain-glossary.md`.
- AC6: `contracts/domain-glossary.md` § Diagnosis (Door A), the **Remediation** sentence reads exactly
  `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:115`, with the following **Backtrack level**
  sentence on the same line unchanged. Instrument: `rg -n "when one resolves, one tier-1 hint"
  contracts/domain-glossary.md`.
- AC7: `contracts/domain-glossary.md` § Diagnosis (Door A), the **Error type** sentence reads exactly
  `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:118`, with the following **Distractor tag**
  and **Hint tier** sentences on the same line unchanged. Instrument: `rg -n "never a catalogue id or a
  \`hint_tree\` key" contracts/domain-glossary.md`.
- AC8: `docs/domains/diagnosis.md` W3 step 1 reads "two quick checks, about a minute" (not "two quick
  questions"). Instrument: `rg -n "two quick checks, about a minute" docs/domains/diagnosis.md`; `rg -n "two
  quick questions" docs/domains/diagnosis.md` returns no match.
- AC9: `docs/domains/diagnosis.md` § Core entities, Remediation, reads exactly the Rule 5 text of
  `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:121`. Instrument: `rg -n "when one resolves,
  one tier-1 hint \(DEMO-BRIEF §3.6\) — then return" docs/domains/diagnosis.md`.
- AC10: `docs/domains/diagnosis.md` § UI surfaces, the Remediation parenthetical, reads exactly the Rule 5
  text of `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:122`. Instrument: `rg -n "else the
  paraphrase and, when one resolves, one tier-1 hint" docs/domains/diagnosis.md`.
- AC11: `docs/domains/learning-objects.md` carries all five Rule-5 edits (catalogue-id spelling at the
  ErrorType definition, the `none_of_these`→`none-of-these` fix at the enum-null sentence, the enum-closure
  step, the hint-coverage step, and the W2 step 1 rewrite) and the new changelog row, each byte-identical to
  `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:125-132`. Instrument: `rg -n "catalogue id;
  \`classify\`'s abstention outcome is the token|a \`none-of-these\` entry is optional|hint_tree\[.none-of-these.\]\[0\]|never another ErrorType's hint \(I2\)|Catalogue id spelled" docs/domains/learning-objects.md`
  shows one match per pattern.
- AC12: `docs/DEFERRED.md` carries two new entries, appended in order after the current last entry, in the
  C6 template: `D-15 — Region tint deltas on the expedition summary` (byte-identical body to
  `tasks/arbitration/arbiter-04-predispatch.md:108-115`, id substituted) and `D-16 — Hint tiers 2–3 ("ask for
  the next hint") on Door A screens` (byte-identical body to
  `tasks/arbitration/arbiter-04-predispatch.md:360-367`, id substituted). Instrument: `rg -n "### D-15|### D-16"
  docs/DEFERRED.md`.
- AC13: `git diff --stat` touches exactly five files: `contracts/interaction-contract.md`,
  `contracts/domain-glossary.md`, `docs/domains/diagnosis.md`, `docs/domains/learning-objects.md`,
  `docs/DEFERRED.md` — all landed in **one** commit whose subject carries a combined scope,
  `contract(interaction-contract,domain-glossary): …`, so both locked-contract bumps are flagged in the scope tag
  (§4 step 13; §6 decision default; precedent commit `bc12158`).
  `contracts/error-codes.json` and `docs/domains/expedition.md` are absent from the diff.

## §2 File scope

In-scope (the implementer touches EXACTLY these five files; nothing else):

- `contracts/interaction-contract.md` — MODIFY. Version line append; § 2 three new bullets; § Finalization
  owed paragraph replacement (§4 steps 1–4).
- `contracts/domain-glossary.md` — MODIFY. Version line replace; § Diagnosis (Door A) Remediation sentence
  replace; § Diagnosis (Door A) Error type sentence replace (§4 steps 5–7).
- `docs/domains/diagnosis.md` — MODIFY. W3 step 1 copy fix; § Core entities Remediation replace; § UI
  surfaces Remediation parenthetical replace (§4 steps 8–10). No other line in this file changes.
- `docs/domains/learning-objects.md` — MODIFY. Five spelling/definition edits; one new changelog row (§4 step
  11). No other line in this file changes.
- `docs/DEFERRED.md` — MODIFY. Append two new entries, `D-15` and `D-16`, after the current last entry (§4
  step 12). No existing entry's text changes.

Out-of-scope (do not touch even if tempted):

- `docs/domains/expedition.md` — **confirmed no edit needed.** Its Q6 text already reads (verified by direct
  read, `docs/domains/expedition.md:203-205`) "a terminated run is logged as abandoned and the next launch
  starts fresh", which is exactly what the new "In-run log entry (expedition Q6)" contract bullet cites and
  narrows to a persistence mechanism; the ratified domain text needs no wording change.
- `contracts/error-codes.json`, `contracts/error-codes.md`, `Packages/Core/Sources/Core/CoreError.swift` —
  `error-codes.json` gains no entry in this task (arbiter-04 § Q-B: "`error-codes.json` gains no entry.");
  `LO_HINT_NOT_FOUND` is already registered internal; the additive `CoreError.loHintNotFound` case lands in
  task 04.3, not here.
- `data/demo/**` — no data edit in task 04.1. The Rule-4 `hint_tree["none-of-these"]` content addition is a
  separate task, 04.1b, planned after this one (`docs/plans/epic-04-plan.md`: `04.1b … Depends 04.1`).
- `Packages/Core/**`, `App/Sources/**` — this task ships contract/docs text only; no `Core` type, no App
  code, no pipeline module.
- `pipeline/**` — no executable surface; nothing under `pipeline/` changes, though its test
  (`pipeline/tests/test_contracts.py`) is re-run as a regression check (§5, §7).
- `docs/DEFERRED.md` entries `D-1`…`D-14` — read-only precedent for the C6 template; none of their text
  changes.
- `docs/epics/epic-04-app-expedition-diagnosis-acceptance.md`, `tasks/arbitration/*.md` — normative/narrative
  sources this task's edits realise; this task's file scope does not include editing them.

## §3 Inputs (verbatim — do not paraphrase)

### Binding contract rules

- `contracts/README.md` — heading `## Lock-first rule`:
  > `data-model`, `graph-constraints`, `content-policy`, `telemetry`, `domain-glossary`, `runtime-tiers` and
  > `deployment-model` **lock before any dependent EPIC starts** — retrofitting them corrupts shipped data, the
  > graph, or the compliance position. Discovery-zone contracts stay open and are finalized just-in-time. A
  > change to a locked contract is a **versioned** change: bump `Contract version`, ripple to every conforming
  > EPIC, and flag the commit scope (`contract(<name>)`) so the ripple is auditable.

  Binds this task: `domain-glossary.md` is LOCK-FIRST, so its v1.0.1 bump is a versioned change whose commit
  scope must be flagged; `interaction-contract.md` is discovery-zone, finalized just-in-time by this EPIC, and
  follows the same versioning discipline by its own `Contract version` line and its own § Finalization owed
  section (precedent: `tasks/epic-03-task-01-contract-interaction-marker-unit-list.md` § 3).

- `contracts/content-policy.md` — heading `## Voice`:
  > Teacher, not chatbot: one thing at a time, no persona, no filler, no scores or percentages on student
  > surfaces; a node is named, the student never is (diagnosis §7 stance).

  Binds this task: this is why arbiter-04 § Q-A rejects the "per-region fraction" alternative for the summary
  — the landed "Summary content" bullet shows no region tint delta and no fraction.

### Normative texts to land (exact — re-read and byte-verified from source immediately before this spec was written)

**A. `contracts/interaction-contract.md` version-line append**
(`tasks/arbitration/arbiter-04-predispatch.md:74-75`):
```
; v0.9.3 resolves the answer-card timing and summary-tint finalization items and records the in-run
abandoned log entry (arbiter Q-A, Q-G, `tasks/arbitration/arbiter-04-predispatch.md`)
```

**B. § 2 Expedition — "Answer card (timing)" bullet**, inserted after the `answer(item)` bullet
(`tasks/arbitration/arbiter-04-predispatch.md:79-82`):
> - **Answer card (timing):** after every checked item — expedition item, retry or probe item — the answer card
>   (correct/incorrect, the correct answer, `why`) stays on screen until the student taps an explicit continue
>   control. There is no timer and no auto-advance. No next item, probe item, hypothesis card, remediation,
>   terminal line or summary is reachable before that tap (I3).

**C. § 2 Expedition — "Summary content" and "In-run log entry" bullets**, inserted after the `end` bullet
(`tasks/arbitration/arbiter-04-predispatch.md:86-92`):
> - **Summary content:** the summary lists the nodes cleared this run, the fog lifted, the nodes marked
>   `blocked`, and offers "Start another" and "Back to the map". It shows no region tint delta and no fraction;
>   the re-derived map shows the tint on return (map W6).
> - **In-run log entry (expedition Q6):** while a run is in progress, the persisted `StudentState` carries that
>   run's `expedition_log` entry exactly as `end` with `abandoned = true` would write it at that moment; `end`
>   replaces it with the final entry. A run the OS terminates is therefore logged as abandoned and never
>   resumed. No field is added.

**D. § Finalization owed by the Demo EPIC — full replacement**
(`tasks/arbitration/arbiter-04-predispatch.md:96-98`), heading kept:
> Nothing remains owed. Resolved in v0.9.2: the marker is set from the unit list only — § 3; no drag. Resolved
> in v0.9.3: the answer card stays until the student continues, and the summary shows no region tint deltas —
> § 2. Bump to v1.0.0 on wrap.

**E. `contracts/domain-glossary.md` version-line replacement** (reconciled header, superseding arbiter-04 §
Q-B's own header; `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:111`):
```
**Contract version:** v1.0.1 · Source: `docs/domains/*.md`, `docs/idea.md` (D1–D49); v1.0.1 clarifies Remediation for nodes without an Explanation and the two none-of-these tokens (arbiter-04 Q-B; arbiter-04-hint-fallback-reconciliation)
```

**F. `contracts/domain-glossary.md` § Diagnosis (Door A), Remediation sentence** (reconciled, superseding
arbiter-04 § Q-B's own sentence; `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:115`):
> **Remediation** — one Explanation or WorkedExample for a confirmed candidate; when the node carries neither, its `paraphrase` plus, when one resolves, one tier-1 hint (DEMO-BRIEF §3.6).

**G. `contracts/domain-glossary.md` :45, Error type sentence** (new;
`tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:118`):
> **Error type** (`ErrorType`) — a member of a node's closed catalogue, incl. the none-of-these member, whose catalogue id is `none-of-these`; `classify` reports abstention as the outcome token `none_of_these`, which is never a catalogue id or a `hint_tree` key.

**H. `docs/domains/diagnosis.md` W3 step 1 cascade**
(`tasks/arbitration/arbiter-04-predispatch.md:251-252`):
> `docs/domains/diagnosis.md` W3 step 1: replace `("two quick questions, about a minute")` with `("two quick checks, about a minute")`.

**I. `docs/domains/diagnosis.md` § Core entities, Remediation** (reconciled, superseding arbiter-04 § Q-B's
own cascade text; `tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:121`):
> **§ Core entities, Remediation.** Replace "one `Explanation` or `WorkedExample` from **learning-objects**, then return." with "one `Explanation` or `WorkedExample` from **learning-objects** — or, when the node carries neither, its `paraphrase` plus, when one resolves, one tier-1 hint (DEMO-BRIEF §3.6) — then return."

**J. `docs/domains/diagnosis.md` § UI surfaces** (reconciled;
`tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:122`):
> **§ UI surfaces.** Replace "(W4, one explanation or worked example)" with "(W4, one explanation or worked example, else the paraphrase and, when one resolves, one tier-1 hint)".

**K. `docs/domains/learning-objects.md` edits** (`tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md:125-132`):
- **:41-42.** "with exactly one terminal `none_of_these`" → "with exactly one terminal member `none-of-these` (catalogue id; `classify`'s abstention outcome is the token `none_of_these`)".
- **:47-48.** "and `none_of_these` is always `null`: abstention, not diagnosis." → "and `none-of-these` is always `null`: abstention, not diagnosis."
- **:75.** "exactly one `none_of_these`" → "exactly one `none-of-these`".
- **:77.** "every ErrorType but `none_of_these` has a full tier list" → "every ErrorType but `none-of-these` has a full tier list (a `none-of-these` entry is optional; when present it is the node's generic hint)".
- **W2 step 1 (:92-93).** "a miss raises `LO_HINT_NOT_FOUND` and the session falls back to the node's generic tier-1 hint" → "a miss raises `LO_HINT_NOT_FOUND` (internal data) and the session falls back to the node's generic tier-1 hint, `hint_tree["none-of-these"][0]`, else the node's `paraphrase`; never another ErrorType's hint (I2)".
- Add changelog row (line 2026-09-10): `| 2026-09-10 | Catalogue id spelled \`none-of-these\`; W2 generic hint defined (arbiter-04-hint-fallback-reconciliation). |`

**L. `docs/DEFERRED.md` — region-tint entry** (`tasks/arbitration/arbiter-04-predispatch.md:108-115`, `D-n`
→ `D-15` per §6):
```
### D-15 — Region tint deltas on the expedition summary
**Observed:** interaction-contract v0.9.3 § 2 resolves the summary to nodes cleared, fog lifted, blocked marked,
"Start another" / "Back to the map", with no region tint delta (arbiter-04 Q-A). A per-region fraction on a
student surface would conflict with content-policy § Voice ("no scores or percentages on student surfaces").
**Configuration:** Demo (`data/demo`); the map re-tints on return (map W6).
**Revisit trigger:** Demo observations (DEMO-BRIEF §7 items 2 and 3).
**Hypothesis (unverified):** none.
```

**M. `docs/DEFERRED.md` — hint-tiers entry** (`tasks/arbitration/arbiter-04-predispatch.md:360-367`, `D-n`
→ `D-16` per §6):
```
### D-16 — Hint tiers 2–3 ("ask for the next hint") on Door A screens
**Observed:** EPIC 04 shows only tier 1 of the resolved hint (arbiter-04 Q-F, per DEMO-BRIEF §3.6 "one
level"); `data/demo` carries three tiers per `hint_tree` entry (schema minItems/maxItems 3).
**Configuration:** Demo, Tier 0, iOS app.
**Revisit trigger:** Demo observations, or EPIC 12 (M3 screens on real data).
**Hypothesis (unverified):** none.
```

### Prior text this task edits in place (pre-state, read directly and quoted verbatim)

`contracts/interaction-contract.md` v0.9.2 version line (pre-state per
`tasks/epic-03-task-01-contract-interaction-marker-unit-list.md:244-249`; this task's predecessor spec, which
lands v0.9.2 before this task runs on `epic-04a-door-core`):
```
**Contract version:** v0.9.2 (discovery zone — finalized just-in-time by the Demo EPIC) · Source: brief v2
§7, D23, D27, D44–D48, v2.7 §3; `map.md`, `expedition.md`, `diagnosis.md`; v0.9.1 adds the numeric
normalisation rule (expedition Q4), the `remediated(p)` predicate and its two ripples (arbiter Q-A,
`tasks/arbitration/arbiter-02-predispatch.md`), the `past_last_unit` marker text (arbiter Q-F), and the
probe "available" definition (arbiter Q-G); v0.9.2 resolves the marker-drag finalization item (arbiter Q-B,
`tasks/arbitration/arbiter-03-predispatch.md`)
```

`contracts/interaction-contract.md` v0.9.2 § Finalization owed (pre-state per
`tasks/epic-03-task-01-contract-interaction-marker-unit-list.md:265-268`):
```
## Finalization owed by the Demo EPIC
The timing of the answer card; whether the summary shows region tint deltas. Bump to v1.0.0 on wrap.
(Resolved in v0.9.2: the marker is set from the unit list only — § 3; no drag.)
```

`contracts/interaction-contract.md` § 2 Expedition, the `answer(item)` and `end` bullets this task inserts
around (unchanged by EPIC 03 task 03.1, confirmed present on `main` today at
`contracts/interaction-contract.md:38-39, 56`, and therefore also the v0.9.2 pre-state on
`epic-04a-door-core`):
```
- `answer(item)`: deterministic check (expedition Q4: normalised exact match, per-item tolerance; `mc` by
  choice id); always show correct answer + `why` (I3); log `probe_log`; emit `item_answered`.
```
```
- `end`: summary; log entry; a run left mid-way is `abandoned` (expedition Q6), never resumed item-by-item.
```

`contracts/domain-glossary.md` v1.0.0 version line (current on `main`,
`contracts/domain-glossary.md:3`):
```
**Contract version:** v1.0.0 · Source: `docs/domains/*.md`, `docs/idea.md` (D1–D49)
```

`contracts/domain-glossary.md` § Diagnosis (Door A), Remediation and Error type lines (current on `main`,
`contracts/domain-glossary.md:43, 45`):
```
- **Remediation** — one Explanation or WorkedExample for a confirmed candidate. **Backtrack level** — distance from the origin node (≤ 2, I4).
```
```
- **Error type** (`ErrorType`) — a member of a node's closed catalogue, incl. `none_of_these`. **Distractor tag** — the error type an `mc` distractor or anticipated wrong numeric answer carries (diagnosis Q1). **Hint tier** — one of three levels of a `HintTree` branch.
```

`docs/domains/diagnosis.md` W3 step 1, § Core entities Remediation, and § UI surfaces (current on `main`,
`docs/domains/diagnosis.md:41-42, 69, 108`):
```
- **Remediation** — the minimal piece for a confirmed gap: one `Explanation` or `WorkedExample` from
  **learning-objects**, then return.
```
```
### W3 — Probe the candidate
**Pre:** a `Diagnosis`; two items available. **Steps:** 1. State the cost up front ("two quick questions,
about a minute") and let the student decline (Q2).
```
```
Native: **Hypothesis card** (W1–W2, a sheet over the expedition or map); **Probe** (W3, two items in the
expedition item view); **Remediation** (W4, one explanation or worked example); return is implicit (W5).
```

`docs/domains/learning-objects.md` lines this task edits (current on `main`,
`docs/domains/learning-objects.md:41-42, 47-48, 75, 77, 92-93, 169-174`):
```
**ErrorType** — a member of the node's closed catalogue (brief §5 `error_catalogue[]`): per-node, with
exactly one terminal `none_of_these`. Canonical example, the M4′ node *logarithmic equation solving*, six
```
```
at the exponential-functions node of the D14 chain, "arithmetic slip" nowhere, and `none_of_these` is
always `null`: abstention, not diagnosis.
```
```
2. **Enum closure** — each enum non-empty, exactly one `none_of_these`.
```
```
4. **Hint coverage** — every ErrorType but `none_of_these` has a full tier list, else `LO_HINT_TIER_MISSING`.
```
```
**Steps:** 1. Resolve `(node, error_type) → tiers`; a miss raises `LO_HINT_NOT_FOUND` and the session
falls back to the node's generic tier-1 hint. 2. Tiers issue one at a time on request. 3. Tier 1 may
re-word; below threshold or on adapter failure the stored wording is used (Tier 0 fallback, I2).
```
```
| 2026-09-08 | Drafted (Phase 3b). |
| 2026-09-08 | Phase 3b consistency fixes (event consumers aligned with telemetry's four event kinds). |
| 2026-09-08 | Open questions ratified by owner (all defaults; see docs/plans/phase3b-open-questions.md). |
| 2026-09-09 | v2 re-cut: ProbeItem typed `numeric | mc` with distractor `ErrorType` tags, `why`, SymPy verification in the pipeline (D41) and SwiftMath renderability; Landmark entity and validation (D22, I15); consumers renamed (expedition, diagnosis, map); milestone M6 → M5. Q2 carries a v2 note; no new open questions. |
```

`docs/DEFERRED.md`'s own C6 entry template (`docs/DEFERRED.md:9-15`):
```
### D-n — <item>
**Observed:** what was actually measured or decided, and where that is recorded.
**Configuration:** the environment/config under which that observation holds.
**Revisit trigger:** the condition that brings this item back.
**Hypothesis (unverified):** any diagnosis or proposed remedy — or "none".
```

`docs/DEFERRED.md`'s last entry, confirmed `D-13` on `main` today (`docs/DEFERRED.md:135`); EPIC 03 task
03.1 lands `D-14` (`tasks/epic-03-task-01-contract-interaction-marker-unit-list.md` § 4 step 6) before this
task runs. The next free ids on `epic-04a-door-core`, after EPIC 03 merges, are therefore `D-15` and `D-16`.
If a concurrently-landed task has already claimed either id by the time this task is implemented, re-read
`docs/DEFERRED.md` and take the next free ids instead — the entries' content does not depend on their
numbers.

## §4 Implementation outline

This is a documentation/contract-only edit. There is no boundary schema, no error code, no storage/asset
access and no model-calling path in this task. The thirteen ordered edits below are applied in place, in one
commit.

1. **`contracts/interaction-contract.md` — version line.** Change `v0.9.2` to `v0.9.3` in the header
   (`**Contract version:** v0.9.3 …`), and append input **A** (§3) to the end of the existing Source
   sentence, immediately after `` `tasks/arbitration/arbiter-03-predispatch.md`) `` with no period before the
   append (match the existing sentence's punctuation style, which has none at its current end). Resulting
   full version-line block:
   ```
   **Contract version:** v0.9.3 (discovery zone — finalized just-in-time by the Demo EPIC) · Source: brief v2
   §7, D23, D27, D44–D48, v2.7 §3; `map.md`, `expedition.md`, `diagnosis.md`; v0.9.1 adds the numeric
   normalisation rule (expedition Q4), the `remediated(p)` predicate and its two ripples (arbiter Q-A,
   `tasks/arbitration/arbiter-02-predispatch.md`), the `past_last_unit` marker text (arbiter Q-F), and the
   probe "available" definition (arbiter Q-G); v0.9.2 resolves the marker-drag finalization item (arbiter Q-B,
   `tasks/arbitration/arbiter-03-predispatch.md`); v0.9.3 resolves the answer-card timing and summary-tint
   finalization items and records the in-run abandoned log entry (arbiter Q-A, Q-G,
   `tasks/arbitration/arbiter-04-predispatch.md`)
   ```
   The `v0.9.1 adds …` and `v0.9.2 resolves …` clauses are history and stay untouched — only the header's
   version number and the sentence's tail change.

2. **`contracts/interaction-contract.md` § 2 — "Answer card (timing)" bullet.** Insert input **B** (§3) as a
   new bullet immediately after the `answer(item)` bullet quoted in §3, before the "Numeric normalisation"
   bullet. Byte-identical to `tasks/arbitration/arbiter-04-predispatch.md:79-82`.

3. **`contracts/interaction-contract.md` § 2 — "Summary content" and "In-run log entry" bullets.** Insert
   input **C** (§3) as two new bullets immediately after the `end` bullet quoted in §3, before the
   "**Properties (CoreTests):**" paragraph. Byte-identical to `tasks/arbitration/arbiter-04-predispatch.md:86-92`.

4. **`contracts/interaction-contract.md` § Finalization owed.** Replace the section quoted in §3 (v0.9.2
   pre-state) with input **D** (§3), keeping the `## Finalization owed by the Demo EPIC` heading. Resulting
   full section:
   ```
   ## Finalization owed by the Demo EPIC
   Nothing remains owed. Resolved in v0.9.2: the marker is set from the unit list only — § 3; no drag. Resolved
   in v0.9.3: the answer card stays until the student continues, and the summary shows no region tint deltas —
   § 2. Bump to v1.0.0 on wrap.
   ```

5. **`contracts/domain-glossary.md` — version line.** Replace the v1.0.0 line quoted in §3 with input **E**
   (§3) in full (a whole-line replacement, not an append — the reconciled header is the entire new line).

6. **`contracts/domain-glossary.md` § Diagnosis (Door A) — Remediation sentence.** Within the line quoted in
   §3 (`- **Remediation** — one Explanation or WorkedExample for a confirmed candidate. **Backtrack level** —
   distance from the origin node (≤ 2, I4).`), replace only the **Remediation** sentence (up to and including
   the following period) with input **F** (§3), leaving the **Backtrack level** sentence untouched. Resulting
   full line:
   ```
   - **Remediation** — one Explanation or WorkedExample for a confirmed candidate; when the node carries neither, its `paraphrase` plus, when one resolves, one tier-1 hint (DEMO-BRIEF §3.6). **Backtrack level** — distance from the origin node (≤ 2, I4).
   ```

7. **`contracts/domain-glossary.md` § Diagnosis (Door A) — Error type sentence.** Within the line quoted in
   §3 (`- **Error type** (\`ErrorType\`) — a member of a node's closed catalogue, incl. \`none_of_these\`.
   **Distractor tag** — … **Hint tier** — …`), replace only the **Error type** sentence (up to and including
   the following period) with input **G** (§3), leaving the **Distractor tag** and **Hint tier** sentences
   untouched. Resulting full line:
   ```
   - **Error type** (`ErrorType`) — a member of a node's closed catalogue, incl. the none-of-these member, whose catalogue id is `none-of-these`; `classify` reports abstention as the outcome token `none_of_these`, which is never a catalogue id or a `hint_tree` key. **Distractor tag** — the error type an `mc` distractor or anticipated wrong numeric answer carries (diagnosis Q1). **Hint tier** — one of three levels of a `HintTree` branch.
   ```

8. **`docs/domains/diagnosis.md` W3 step 1.** Per cascade **H** (§3), replace `("two quick questions, about a
   minute")` with `("two quick checks, about a minute")` in the W3 step 1 sentence quoted in §3. No other
   word in the sentence changes.

9. **`docs/domains/diagnosis.md` § Core entities, Remediation.** Per cascade **I** (§3), replace the full
   Remediation entry quoted in §3 with:
   ```
   - **Remediation** — the minimal piece for a confirmed gap: one `Explanation` or `WorkedExample` from
     **learning-objects** — or, when the node carries neither, its `paraphrase` plus, when one resolves, one
     tier-1 hint (DEMO-BRIEF §3.6) — then return.
   ```

10. **`docs/domains/diagnosis.md` § UI surfaces.** Per cascade **J** (§3), replace "(W4, one explanation or
    worked example)" with "(W4, one explanation or worked example, else the paraphrase and, when one
    resolves, one tier-1 hint)" within the sentence quoted in §3. No other word in the sentence changes.
    Resulting full sentence:
    ```
    Native: **Hypothesis card** (W1–W2, a sheet over the expedition or map); **Probe** (W3, two items in the
    expedition item view); **Remediation** (W4, one explanation or worked example, else the paraphrase and,
    when one resolves, one tier-1 hint); return is implicit (W5).
    ```

11. **`docs/domains/learning-objects.md` — five edits and a changelog row.** Apply input **K** (§3) in place,
    each targeting the exact pre-state string quoted in §3:
    - the ErrorType definition sentence, `:41-42`;
    - the enum-null sentence, `:47-48`;
    - the enum-closure step, `:75`;
    - the hint-coverage step, `:77`;
    - the W2 step 1 sentence, `:92-93`.

    Then append the new changelog row as the file's new last row, immediately after the existing last row
    (`| 2026-09-09 | v2 re-cut: … |`):
    ```
    | 2026-09-10 | Catalogue id spelled `none-of-these`; W2 generic hint defined (arbiter-04-hint-fallback-reconciliation). |
    ```

12. **`docs/DEFERRED.md` — two new entries.** Append, after the current last entry (`D-14`, landed by EPIC 03
    task 03.1; re-read the file and take the next free ids if that has changed by implementation time), a
    blank line then input **L** (§3) as `D-15`, then a blank line then input **M** (§3) as `D-16`. Follow the
    file's existing separator convention: a single blank line before each `### D-n` heading, no `---` rule
    (the file's only `---` at line 25 separates the intro block from `### D-1`; none precedes any later
    entry).

13. **Commit.** **One** commit, subject `contract(interaction-contract,domain-glossary): answer-card timing,
    summary tint, in-run log entry (v0.9.3); Remediation and Error-type clarification (v1.0.1)`, touching
    exactly the five files of §2. The combined scope tag flags both locked contracts, which meets
    `contracts/README.md` § Lock-first rule ("flag the commit scope (`contract(<name>)`)"). This follows the
    repo precedent for a two-contract change, commit `bc12158` `contract(data-model,content-policy): …`
    (orchestrator correction after review).
    The PR description names every ruling this task carries out: arbiter-04 § Q-A, § Q-D, § Q-G
    (`tasks/arbitration/arbiter-04-predispatch.md`) and the reconciliation's Rule 5
    (`tasks/arbitration/arbiter-04-hint-fallback-reconciliation.md`).

14. **Smoke check.** `rg -n "Contract version|Answer card \(timing\)|Summary content|In-run log entry|Nothing
    remains owed|when one resolves, one tier-1 hint|never a catalogue id or a \`hint_tree\` key|two quick
    checks, about a minute|then return\.|else the paraphrase and, when one resolves|Catalogue id spelled|###
    D-15|### D-16" contracts/interaction-contract.md contracts/domain-glossary.md docs/domains/diagnosis.md
    docs/domains/learning-objects.md docs/DEFERRED.md` — must show every new/changed string present in its
    target file. `rg -n "two quick questions|the timing of the answer card; whether the summary|the node's
    generic tier-1 hint\.|none_of_these\." contracts/interaction-contract.md docs/domains/diagnosis.md
    docs/domains/learning-objects.md` must return no match against the superseded phrasings (the last pattern
    is scoped to a trailing period so it does not false-match the still-correct `:75`/`:77` uses that this
    task itself rewrites — run the check only after step 11 completes). `git diff --stat` shows exactly five
    files changed. `git diff -- contracts/error-codes.json docs/domains/expedition.md` is empty.

## §5 Test plan (seam risk — full plan)

This task ships no code, so its "tests" are the verifiable textual assertions below — the cheapest rung that
actually holds prose contract and domain-doc text (`contracts/README.md` § Enforcement ladder: "type system →
static analysis / lint → schema / config check → runtime contract test"; a grep-based content assertion is
the lint rung). The rule's *behavioural* conformance (the façade honouring the answer-card timing, the
write-ahead sequencing, the hint resolver) is proven at the runtime-contract-test rung by EPIC 04a tasks 04.2
and 04.3, which this task's text is normative input to, not the instrument for.

- **T1 happy path.** Run the smoke check of §4 step 14. Every grepped string is present exactly where §4
  places it (verified by a full read of all five files after edit, not just the grep match count).
  `pipeline/tests/test_contracts.py` (the registry ⇔ domain-docs round-trip) is run and stays green — this
  task touches no error-registry row, so the run is a regression check. `scripts/check-no-time-estimates.sh`
  is run and stays green — no edit in this task introduces an untagged quantitative claim (every string
  landed is copied verbatim from a ruling that already carries no bare time estimate).
- **T2 negative — invalid input rejected at the boundary.** Not applicable in the schema/code sense (this
  task validates no runtime input). The prose equivalent: confirm the *old* text each edit replaces no longer
  appears unmodified —
  - `rg -n "the timing of the answer card; whether the summary shows" contracts/interaction-contract.md`
    returns no match;
  - `rg -n "^- \*\*Remediation\*\* — one Explanation or WorkedExample for a confirmed candidate\.
    \*\*Backtrack" contracts/domain-glossary.md` returns no match (the un-clarified Remediation sentence, with
    a period directly after "candidate", is gone);
  - `rg -n "incl\. \`none_of_these\`\." contracts/domain-glossary.md` returns no match (the un-clarified Error
    type sentence is gone);
  - `rg -n "two quick questions" docs/domains/diagnosis.md` returns no match;
  - `rg -n "from \*\*learning-objects\*\*, then return\." docs/domains/diagnosis.md` returns no match (the
    un-clarified Core-entities Remediation sentence is gone);
  - `rg -n "\(W4, one explanation or worked example\)" docs/domains/diagnosis.md` returns no match (the
    un-clarified UI-surfaces parenthetical, closed immediately after "worked example", is gone);
  - `rg -n "exactly one terminal \`none_of_these\`\." docs/domains/learning-objects.md` returns no match;
  - `rg -n "and \`none_of_these\` is always \`null\`" docs/domains/learning-objects.md` returns no match;
  - `rg -n "exactly one \`none_of_these\`\." docs/domains/learning-objects.md` returns no match;
  - `rg -n "every ErrorType but \`none_of_these\` has a full tier list, else" docs/domains/learning-objects.md`
    returns no match;
  - `rg -n "falls back to the node's generic tier-1 hint\. 2\." docs/domains/learning-objects.md` returns no
    match (the un-clarified W2 step 1 sentence is gone).

  A diff that leaves any old text duplicated alongside the new one is a FAIL.
- **T3 error-taxonomy.** Nothing to assert: this task registers no error code in `contracts/error-codes.md` /
  `error-codes.json` and touches no registry row. `git diff -- contracts/error-codes.json` is empty (§4 step
  14). Recorded explicitly so the omission is a decision, not a gap.
- **T4 conformance per §B.1 / cited contract and invariants.** Re-read all five edited files top to bottom and
  confirm: (a) each of the thirteen edits in §4 appears verbatim as specified, with no adjacent text altered;
  (b) `interaction-contract.md`'s version line names v0.9.3 and the exact resolution clause (AC1); (c) § 2's
  three new bullets are byte-identical to their arbiter-04 sources (AC2, AC3); (d) § Finalization owed is
  byte-identical to the ruling (AC4); (e) `domain-glossary.md`'s version line, Remediation and Error-type
  sentences are byte-identical to the **reconciliation's** Rule 5 texts, not arbiter-04 § Q-B's superseded
  versions (AC5–AC7); (f) all three `diagnosis.md` edits and all five `learning-objects.md` edits plus its
  changelog row are byte-identical to their sources (AC8–AC11); (g) both `DEFERRED.md` entries follow the C6
  template with all four fields present and non-empty, numbered `D-15` and `D-16` (AC12); (h) I3 holds — the
  landed "Answer card (timing)" bullet's reachability list (next item, probe item, hypothesis card,
  remediation, terminal line, summary) is complete and unmodified from the source; (i) I2 holds in the landed
  hint-fallback text — no landed sentence says a sibling ErrorType's hint may be shown.
- **T5 negative control for every regression guard.** The regression guard this task installs is the grep set
  of §4 step 14. Its negative control: temporarily revert one edit (e.g. re-insert "two quick questions, about
  a minute" into `docs/domains/diagnosis.md` W3 step 1) and confirm the smoke check of §4 step 14 fails (the
  "two quick checks" grep no longer matches at that location, and the T2 negative check's "two quick
  questions" grep now matches). Perform this once per edit during review, not as a committed test file — there
  is no test harness for `contracts/*.md` or `docs/*.md` prose in this repository today (confirmed absent by
  the precedent task `tasks/epic-03-task-01-contract-interaction-marker-unit-list.md` § T5, which records the
  same finding). `pipeline/tests/test_contracts.py`'s registry-round-trip test is the one committed test this
  task's diff runs against, and it is unaffected by any of these thirteen edits (T3), so it is not itself a
  regression guard for this task's new text.
- **T6 idempotency / no-leak.** Re-applying the same thirteen edits to the post-edit files is a no-op: each
  target string, once present, is not matched again by its own insertion instruction (every insertion in §4
  targets a string from the *pre*-edit files, quoted in §3, which no longer exists post-edit).
  `docs/DEFERRED.md`'s entry insertion targets "after the current last entry", and `D-16` is itself the new
  last entry, so a second application would append `D-17`/`D-18` with identical content rather than
  duplicating `D-15`/`D-16` — flagged here so the implementer does not run the edit twice. No side file is
  touched; `git diff --stat` after the commit shows exactly five files.

## §6 Decision defaults

- IF the two contract bumps (`interaction-contract` v0.9.3 and `domain-glossary` v1.0.1) and their doc
  cascades should land as two separate commits, as the task-context bundle's §I framing suggests, THEN they
  must not: this task lands **one** commit, subject `contract(interaction-contract,domain-glossary): …`, with
  both contracts in the scope tag (§4 step 13; precedent `bc12158`). Rationale: the brief's own §3
  groups the `docs/domains/diagnosis.md` cascade (Core entities, UI surfaces **and** W3 step 1) under the
  single `domain-glossary` v1.0.1 "Cascade in the same task" paragraph
  (`docs/epics/epic-04-app-expedition-diagnosis-acceptance.md` § 3), and this task is the sole EPIC 04 writer
  of all five files in one file scope — landing them as one commit avoids a partially-landed intermediate
  state where one file cites a companion bump (e.g. the interaction-contract's `arbiter Q-A, Q-G` clause and
  the glossary's `arbiter-04 Q-B; arbiter-04-hint-fallback-reconciliation` clause) that has not yet landed on
  the same branch.
- IF the version-line append (interaction-contract) or replace (domain-glossary) should follow a different
  convention THEN: interaction-contract's own § Finalization precedent (v0.9.1 → v0.9.2, EPIC 03 task 01) is
  **append** to the Source sentence, so v0.9.2 → v0.9.3 also appends; domain-glossary has never been bumped
  before this task (still v1.0.0 on `main`), and the reconciliation's own instruction is "replacing Ruling A's
  header text" (`arbiter-04-hint-fallback-reconciliation.md:109`) — a whole-line **replace**, not an append.
- IF § 2's three new bullets should be merged into the existing `answer(item)`/`end` bullets (since each
  describes a related aspect of the same state transition) THEN they must not: the ruling's own instruction is
  to insert each "after the `answer(item)` bullet" / "after the `end` bullet" as its own bullet
  (`arbiter-04-predispatch.md:77, 84`), not folded into the existing text.
- IF the domain-glossary Remediation/Error-type edits should use arbiter-04 § Q-B's own wording ("one tier-1
  hint", no "none-of-these"/"none_of_these" distinction) rather than the reconciliation's Rule 5 wording THEN
  they must not: `arbiter-04-hint-fallback-reconciliation.md` § "Parts of Ruling A (arbiter-04 § Q-B)
  superseded" explicitly marks the Q-B glossary text and diagnosis.md cascade "**AMENDED** to the Rule 5 texts
  ("plus, when one resolves, one tier-1 hint")" — Rule 5 wins.
- IF this task should also land the Rule-4 `data/demo/nodes.json` `hint_tree["none-of-these"]` content change
  (since it is discussed in the same reconciliation file) THEN it must not: the reconciliation names this "a
  **new task**… Route: EPIC 04 planner / spec-architect" (`arbiter-04-hint-fallback-reconciliation.md` § Rule
  4), and the plan places it as `04.1b`, depending on `04.1`, not folded into it.
- IF `docs/DEFERRED.md`'s two new entries should be numbered something other than `D-15`/`D-16` because a
  concurrent task has already claimed one of those ids by the time this task runs THEN take the next free ids
  by re-reading the file — the entries' content (name, Observed, Configuration, Revisit trigger, Hypothesis)
  does not depend on their numbers, per §3's note.
- IF `docs/domains/expedition.md` should be edited to add a cross-reference to the new interaction-contract
  bullet THEN it must not: confirmed by direct read (`docs/domains/expedition.md:203-205`) that Q6's ratified
  text already states the exact behaviour the new bullet documents; the contract cites Q6, not the reverse,
  and no ruling instructs an expedition.md edit for Q-G.

Standing defaults: identifiers and timestamps are unaffected by this task (no schema, no field touched). No
model call exists in this task, so no confidence threshold or Tier-0 fallback applies (I2 not engaged as a
code path); the landed text is precise about the Tier-0 hint fallback for downstream tasks. Telemetry is
unaffected — no event, no payload field is added or changed. No field anywhere is added that could identify a
person, device or session — this task adds prose only. No node's `paraphrase` field is touched; every landed
sentence about `paraphrase` describes existing schema-required behaviour, never invents new Ministry text.

## §7 Done definition

The task is done when ALL gates pass:

- `scripts/gate.sh` green end-to-end (a docs/contract-only change; no gate reads code this task touches, so
  this is a regression check that the change introduced no stray edit elsewhere)
- `pipeline/tests/test_contracts.py` green (registry ⇔ domain-docs round-trip; regression check per T1/T3)
- `scripts/check-no-time-estimates.sh` green
- `git diff --stat` shows exactly five files changed: `contracts/interaction-contract.md`,
  `contracts/domain-glossary.md`, `docs/domains/diagnosis.md`, `docs/domains/learning-objects.md`,
  `docs/DEFERRED.md`; `git diff -- contracts/error-codes.json docs/domains/expedition.md` is empty
- the smoke check and T1/T2/T5 checks of §5 pass
- `contracts/interaction-contract.md`'s `Contract version` reads `v0.9.3`; `contracts/domain-glossary.md`'s
  `Contract version` reads `v1.0.1`; the single commit's subject is scoped
  `contract(interaction-contract,domain-glossary)` (instrument: `git log -1 --format=%s` starts with that
  scope)
- conforms to every contract section cited in §3 and §4, and to every invariant listed in §1
