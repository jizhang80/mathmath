# Arbitration: cross-EPIC audit 01–03, finding F1 ("attempt" in `Core`)

**Date**: 2026-09-10
**Arbiter**: spec-arbiter (Q4)
**Subject**: `docs/audits/cross-epic-01-03.md` F1 (row at line 18) versus CC13 (line 182)
**Verdict**: **(B) A real violation.** F1 stands and its RED holds. Its suggested fix (`probe` / `FailedProbe`) is **rejected**. The corrective task is `tasks/epic-03-task-13b-rename-failed-probe-attempt.md`.

## Ground truth read in this run

- `contracts/domain-glossary.md` (v1.0.0), header block, lines 5–7:
  > One agreed term per concept. Every EPIC, type, JSON key, screen label and doc uses the same word. Code
  > identifiers are the term in `PascalCase` (types) / `camelCase` (Swift members) / `snake_case` (JSON,
  > Python). **Banned synonyms** are listed so the grep gate can catch drift.
- `contracts/domain-glossary.md` § Expedition (Door B), line 34:
  > **Retry** — the second item on the same node after a miss (D27). **Miss** — an incorrect answer. **Clear** — reaching the clear rule (two correct on distinct items). *Banned:* "fail" for an item (fail is a probe outcome), "pass a node".
- `contracts/domain-glossary.md` § Diagnosis (Door A), line 40:
  > **Diagnosis event** — one Door A occurrence, from an expedition second miss or "Check me here". *Banned:* "tutoring session", "attempt".
- `contracts/domain-glossary.md` § Diagnosis (Door A), line 42:
  > **Probe** — two items on the candidate, ~60 s; outcome **pass / fail / declined** → diagnosis outcome **refuted / confirmed / unconfirmed / capped**.
- `docs/domains/diagnosis.md` § W1, lines 54–56: "2. (Tier 0) Classify the miss deterministically: the failed items' `distractor_error_types` (learning-objects) name an `ErrorType` when the wrong answer matches a tagged distractor; otherwise `none_of_these` (abstention)."
- `Packages/Core/Sources/Core/Diagnosis/Classify.swift:3-7`: "One failed probe attempt: the `ProbeItem` the student got wrong, and the value they submitted for it …", then `public struct FailedProbeAttempt: Equatable {`.
- `Packages/Core/Sources/Core/Diagnosis/DiagnosisEvent.swift:134-138`: `start(event:failedAttempts:…)` takes `[FailedProbeAttempt]`. Under `expedition_second_miss`, the caller fills it with the two missed **expedition** items (`Packages/Core/Tests/CoreTests/ExpeditionDiagnosisSeamTests.swift:85-98`; spec 02.11 § decision defaults: "it builds `failedAttempts` from the two missed …"). Inside a probe, `DiagnosisEvent.swift:207-209` appends one value per incorrectly answered probe item.

## The orchestrator's four points, verified

| # | Claim | Verification | Classification |
|---|---|---|---|
| 1 | The header makes a banned word banned *as a synonym for its term*, here the diagnosis event. | Header lines 5–7 (quoted above): the list exists "so the grep gate can catch drift". The ban's origin supports the synonym reading. `docs/plans/phase3b-domain-doc-spec.md:45` lists the v1 `tutoring-session` domain's entities as "Session, Attempt, Diagnosis …". So "tutoring session" and "attempt" are the retired v1 names for a Door A occurrence. | **VALID as to line 40's intent, but not dispositive.** The header's *first* rule ("one agreed term per concept … Code identifiers are the term") governs independently of the synonym lists (see the ruling). |
| 2 | `FailedProbeAttempt` is one wrong item plus the submitted value, not a diagnosis event. | `Classify.swift:3-9`; `DiagnosisEvent.swift:207-209`. | **VALID.** It is not a synonym for "diagnosis event". |
| 3 | No contract or schema uses "attempt". No mechanical "attempt" gate exists. The glossary-related test hits are unrelated. | Case-insensitive grep of `contracts/` for `attempt` gives one hit, glossary line 40. The Core glossary guards scan other words only: `MapLaunchGapTests.swift:152` `["session", "profile", "cursor", "save", "start marker"]`; `MapPanelsPickersHandOffStructuralTests.swift:407-410` and `AppShellStructuralTests.swift:521-524` scan `session/Session/start marker/cursor/profile/progress file/save`, over `App/Sources` only. The `pipeline/tests` "banned" hits are distractor tags (`test_verify_distractors_contract.py`), registry codes (`test_verify_cross_module_conformance.py:29`) and the `verbatim` key (`test_contracts.py:163`). | **VALID.** No test gate exists. However, a *wrap* grep gate does exist (see the EPIC 02 plan below). |
| 4 | The audit contradicts itself: CC13 says WARNING, F1 says RED. | `cross-epic-01-03.md:182` "**WARNING** (not RED)", against line 18 "RED" and line 211 "RED — next EPIC BLOCKED until F1 is resolved". | **VALID.** The report is internally inconsistent. This ruling resolves the severity (see below). |

## The counter-argument, verified

| # | Claim | Verification | Classification |
|---|---|---|---|
| 5 | The glossary defines a term for "one wrong answer to an item". | Yes: **Miss** — "an incorrect answer" (line 34). The diagnosis domain doc uses the same word for exactly this input: "Classify the miss deterministically" (`diagnosis.md:54`). | **VALID. This is decisive.** |
| 6 | Project practice treats "attempt" as a word-level identifier ban, not only a meaning-level one. | `docs/plans/epic-02-plan.md:90-91`: "no \"session\", \"start marker\", \"attempt\" in new identifiers (wrap grep)". This plan governed task 02.10, which coined `FailedProbeAttempt` (`docs/audits/epic-02-acceptance.md:39`, commit `addb1a1`). The wrap grep `grep -wiE "frontier\|attempt\|session"` is recorded in `docs/audits/epic-02a-acceptance.md:22`. The 02b wrap's glossary row (`epic-02-acceptance.md:22`) reports only `frontier` and misses the `-w` hit on `for attempt in attempts` (`Classify.swift:24`). | **VALID.** The name slipped past a gate the EPIC 02 plan itself set. |
| 7 | EPIC 02 or later records already ruled the name acceptable. | No arbitration rules on the name. `tasks/arbitration/arbiter-02-11-stepwise-api.md` uses `failedAttempts: [FailedProbeAttempt]` only as a signature and does not adjudicate the glossary. The only "ruling" is `docs/plans/epic-04-plan.md:96-97`: "The landed 02.11 names `FailedProbeAttempt` and `FurtherLevelOffer`/`levelBudget` are grandfathered, so the wrap grep scopes to new identifiers and copy." | **INVALID as a defence.** A planner note ranks below `contracts/*` and cannot license a contract-banned usage (CLAUDE.md RULE 5; arbiter ground-truth order). EPIC 04's reviewed specs would also coin *new* identifiers on the same stem (`pendingHandoffAttempts`, `thisAttempt`: `tasks/epic-04-task-04-*`, `-05-*`, `-08-*`), so the grandfather clause does not even contain the spread. |

## Ruling

1. **`FailedProbeAttempt` violates `contracts/domain-glossary.md`**, and it does so on the contract's own text, independent of how line 40 is read:
   - **Header rule.** "One agreed term per concept … Code identifiers are the term in `PascalCase`." The concept, an incorrect answer to an item, has the agreed term **Miss** (line 34). The type names it with a different word.
   - **Explicit ban at line 34.** "fail" for an item is banned ("fail is a probe outcome"). `FailedProbeAttempt`, `failedAttempts` and the doc comment "One failed probe attempt" all describe item-level misses as "failed".
   - **Wrong term.** "Probe" is two items on a candidate (line 42). Under `expedition_second_miss` the values are expedition misses, not probe items (`ExpeditionDiagnosisSeamTests.swift:85-98`), so "Probe" in the name is also a wrong glossary term.
2. **Line 40's "attempt" ban.** In the contract it is meant as a synonym ban, and the orchestrator's reading of intent is correct. But the header says the list exists for a *grep* gate. The EPIC 02 plan applied it as a word-level identifier ban in exactly this code's EPIC, and a Door A type called "…Attempt" sits next to the diagnosis event it was banned to protect. In `Core` identifiers, "attempt" is therefore treated as banned in any sense. Swift and Python code outside Door A that uses the English verb or a transport retry count (`pipeline/src/mathmath_pipeline/verify/landmarks.py:45-48,85`; test prose in `L0CheckerContractTests.swift:275` and `StudentStateStoreConformanceTests.swift:171,179`) names no glossary concept and is **not** in violation.
3. **The audit's suggested fix is rejected.** Renaming the loop variable to `probe` and the type to `FailedProbe` swaps one glossary drift for another: a single missed item is not a **Probe** (line 42), and "Failed" is the line-34 ban.
4. **Glossary-conformant names**, used by task 03.13b:

   | Old | New | Why |
   |---|---|---|
   | `FailedProbeAttempt` | `ItemMiss` | **Item** (line 30) + **Miss** (line 34), in `PascalCase` |
   | `Classify.classify(_ attempts:)`, loop `attempt` | `classify(_ misses:)`, loop `miss` | line 34; `diagnosis.md` W1 "Classify the miss" |
   | `DiagnosisProbeResult.incorrectAttempts` (public) | `misses` | line 34 |
   | `ProbeInProgress.incorrectAttempts`, `FurtherLevelOffer.incorrectAttempts` (internal) | `misses` | line 34 |
   | `DiagnosisRun.start(event:failedAttempts:…)`, `run(…failedAttempts:…)` | `misses:` | line 34 |
5. **Severity: RED stands, and CC13's "WARNING (not RED)" is superseded.** The violation is in public `Core` API, and EPIC 04's reviewed specs would build on it and extend it. Renaming before EPIC 04 dispatch costs 2 source files, 6 test files and a finite spec edit list. Renaming after EPIC 04 costs that plus every landed Door façade and App view (I13: quality first).

## Is a contract edit needed?

**No contract edit is needed to decide this case**: lines 5–7 and 34 already decide it. To stop future audits from re-litigating the synonym-versus-word question on line 40, `spec-architect` may propose the following clarifying edit to the owner. **It is a proposal only; this arbiter has no contract write authority, and no task depends on it.** It would go into `contracts/domain-glossary.md`'s header block, after "…so the grep gate can catch drift.":

> A banned word is banned in code identifiers and student copy in every sense, not only as a synonym of the
> term it is listed under; a concept the glossary names (e.g. **Miss** for an incorrect answer) is always
> named with that term. Plain English in prose comments that names no glossary concept is not drift.

It would be a patch bump to v1.0.1 with no identifier change. If it is adopted, task 03.13b's guard test already enforces its identifier half for `Packages/Core/Sources/Core`.

## Resolution record

- **F1** is resolved when `tasks/epic-03-task-13b-rename-failed-probe-attempt.md` lands green (`scripts/gate.sh`) **and** the orchestrator applies that spec's §8 EPIC 04 edit list. After both, the audit's RED lifts and EPIC 04 may dispatch. It is resolved by the rename, not by this ruling.
- `docs/plans/epic-04-plan.md:96-97` (the grandfather clause) is superseded by this ruling. Updating the plan text is for the owner or planner, since `docs/*` is outside arbiter authority.
- There is a stale v1 residue in `docs/domains/learning-objects.md:95` ("returns for the Attempt record"), outside this task's scope. It is recorded here so the next doc pass can fix it.
