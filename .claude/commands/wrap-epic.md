---
description: Wrap-gates for an EPIC — verify green, audit conformance, write the acceptance report, merge to main on green.
---

# /wrap-epic <NN>

Gate an EPIC before it advances. **No green, no advance.** All gates run on the EPIC branch.

## Gates (all must pass)
- **(a) Typecheck** — `pnpm typecheck` clean.
- **(b) Lint** — `pnpm lint` clean.
- **(c) Format** — `pnpm format:check` clean.
- **(d) Tests** — the **full suite runs once here**: `pnpm test` green (whole repo, including tasks that ran only a scoped suite per-task), including the module's **B.1 conformance tests** (per its domain doc). Suite is fast + deterministic (no flakes/hangs). Plus **one Playwright E2E pass over each ratified core workflow of the §7 interaction contract the EPIC touches (plus the parent view once it exists)** — green.
- **(e) Commit messages + CI** —
  - **(e1) commitlint, locally, before merge:** `pnpm exec commitlint --from main --to HEAD` clean over the whole branch range. This is the same check CI runs on push to `main`, so it catches `subject-case` / `type-empty` / etc. *before* the merge instead of after. Merge commits are exempt (`commitlint.config.js` ignores `^Merge `). Task/spec/brief commit subjects must be lowercase-leading conventional commits (e.g. `test(x): add B.1 conformance suite`, **not** `B.1 conformance suite`).
  - **(e2) CI run green:** if a remote exists, the branch's CI run is green — and it must be a **push or PR** run, where the `commitlint` job lints a real commit range. A `workflow_dispatch` run has no commit range and so its `commitlint` job does **not** meaningfully lint anything — do **not** treat a green `workflow_dispatch` run as proof of a green CI. Confirm with `gh run view <run-id>` that **both** the `verify` **and** `commitlint` jobs passed (`gh run list --branch <branch> -L 5` to find a push/PR run; or push the branch and read that run). After merging to `main`, also confirm the push-to-`main` run is green on both jobs.
- **(f) Contract conformance (lightweight, every wrap):** conformance is gated against every contract in `contracts/` (Phase 6; planned set in `contracts/README.md`). Grep gates over the source and asset tree defined by `docs/tech-stack.md` —
  - no `console.log` in source; no `TODO|FIXME|XXX|@ts-ignore|@ts-expect-error`;
  - **(I5)** no identifying fields in any persisted or transmitted schema — `grep -rniE '\b(name|email|phone|address|student_id|ip)\b\s*[:?]'` over schema, storage, and telemetry-payload definitions; a hit that is a real person-identifying field fails the gate;
  - **(I6)** no `verbatim` / Ministry-text field in spine or graph artifacts, and every node carries a `paraphrase`;
  - **(I8)** the L0 checker is green on every graph artifact under version control (acyclic; no later→earlier course edge; code↔node coverage both ways; in-degree outliers flagged; starting chain connected);
  - **(R-6)** no hardcoded ISO-date literals in test fixtures — `grep -rE '20[0-9]{2}-[0-9]{2}-[0-9]{2}'` over the test files; fixtures use the injected clock / `Date.now()`-relative offsets;
  - **(I11)** in every doc this EPIC touched, each quantitative claim carries `[SOURCED: …]` or `[ESTIMATE: …]`, and there are no time estimates anywhere.
- **(g) Cross-EPIC audit (every 3 EPICs):** dispatch **integration-auditor** → must return GREEN. RED blocks the wrap (fix findings, re-run).
- **(h) Contract version bump:** if this EPIC changed a contract, the change is committed with `chore(contract): …` and the contract's change log updated (a locked-contract change is a versioned change).
- **(i) DEFERRED.md:** any item deferred during the EPIC is recorded in `docs/DEFERRED.md` with a trigger.
- **(j) C1 seam test:** if this EPIC added a named seam (editor↔CAS worker, graph query↔UI, Tier-1 adapter↔Tier-0 fallback, telemetry client↔endpoint, generation pipeline↔asset loader, or any other), exactly one real-composition test exercises it with both real sides — no double-mock. Name the seam and the test path in the acceptance report. No seam, no gate.
- **(k) C4 artifact coverage:** every artifact this EPIC ships — the PWA build, the service worker, a content-generation CLI, the L0 checker CLI, a shipped data asset, a runbook command — is exercised by a gate. List them in the acceptance report with the gate that exercises each; an artifact with no gate blocks the wrap.
- **(l) C3 instrument beside claim:** every claim in the acceptance report names the instrument that produced it and what that instrument excludes; every emptiness-capable check declares `empty=PASS` or `empty=FAIL`.

## Acceptance report
Write `docs/audits/epic-<NN>-acceptance.md`: gate results, tasks completed, contracts touched, conformance-test summary, the (j) seam list, the (k) artifact→gate table, any deferrals, and — **(R-7)** — a **`fix:`-commit table** (for cascade tracking): each `fix:` commit classified by **cause** (`logic | seam | contract-gap | gate-miss | test-infra`) **and** by the **`risk` tier** of the task it corrects (`mechanical | seam`); also list any **tester tier-upgrades** (mechanical→seam, per R-3). No time estimates in the report.

## Merge & tag
- On all-green: merge the EPIC branch to `main` (`--no-ff`). The owner may pull `git log --oneline` / the acceptance report / `pnpm test` as their review surface.
- Tag an owner-confirmed deploy state when the owner confirms (Done condition).

## Cascade detection
If this and the previous EPIC each landed with **> 3 rework `fix:` commits**, surface a **Q5** — the loop itself may need adjustment (per the provisional process-validation bar).

**A rework `fix:` corrects earlier work from the same EPIC, against shipped code.** It does NOT count:
spec/document corrections caught before implementation (they touch only `tasks/**` or `docs/**`), or a
Bug-fix EPIC's own commissioned repairs (which land as `fix:` by design). Count rework, not output —
the raw count fires on every Bug-fix EPIC by construction (owner-ratified 2026-09-05, `docs/lessons.md` §20).
The `fix:`-commit table above stays complete; mark each row **rework** or **output** and state both totals.
