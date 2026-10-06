---
description: Wrap-gates for an EPIC — verify green, audit conformance, write the acceptance report, merge to main on green.
---

# /wrap-epic <NN>

Gate an EPIC before it advances. **No green, no advance.** All gates run on the EPIC branch.

## Gates (all must pass)
- **(a) Typecheck** — `pnpm typecheck` and `pnpm gen:check` (generated contract types up to date) clean; `pyright` strict over `pipeline/` clean.
- **(b) Lint** — `pnpm lint` (zero warnings) clean; `ruff check pipeline` clean.
- **(c) Format** — `pnpm format:check` and `ruff format --check pipeline` clean.
- **(d) Tests** — the **full suite runs once here**: `pnpm test` (Vitest); `pnpm e2e` (Vite build + Playwright on Chromium, WebKit iPad, WebKit iPhone); `pytest` over `pipeline/` — all green (whole repo, including tasks that ran only a scoped suite per-task), including the module's **B.1 conformance tests** (per its domain doc). Suite is fast + deterministic (no flakes/hangs). The Demo/M3 acceptance is the owner's product test on a **physical device** (D29) — agents verify with Playwright only and record here that no agent claims device verification.
- **(e) Commit messages + CI** —
  - **(e1) commit-message lint, locally, before merge:** the `conventional-pre-commit` commit-msg hook (pre-commit) enforces lowercase-leading Conventional Commit subjects on every commit as it is made — there is no separate commitlint job to re-run over a range; confirm the branch's commits already passed the hook (no `--no-verify` was used). Task/spec/brief commit subjects must be conventional commits (e.g. `test(x): add B.1 conformance suite`, **not** `B.1 conformance suite`).
  - **(e2) CI run green:** push the EPIC branch and open a PR (`gh pr create --fill --base main`); `gh pr checks --watch` until **every** CI job — `Web (Core + app, Chromium + WebKit)`, `Python pipeline` and the frozen `Swift (Core + App, iOS simulator)` — is green on that PR run (the required set is `scripts/branch-ruleset.json`). After merging to `main`, also confirm the push-to-`main` run is green on every job.
- **(f) Contract conformance (lightweight, every wrap):** conformance is gated against every contract in `contracts/` (Phase 6; planned set in `contracts/README.md`). Grep gates over the source and asset tree defined by `docs/tech-stack.md` —
  - no `console.` in `web/*/src` outside `web/core/src/cli.ts`, no `print(` in `pipeline/src` outside CLI entry points; no `TODO|FIXME|XXX`; no `any`, non-null assertion or reasonless `@ts-ignore`/`@ts-expect-error`/`eslint-disable` in TypeScript; no bare `# type: ignore` (without a reason) in Python; nothing under `Packages/` or `App/` changed (D50);
  - **(I5)** no identifying fields in any persisted or transmitted schema — `grep -rniE '\b(name|email|phone|address|student_id|ip|device_id|install_id)\b\s*[:?]'` over schema, storage, and telemetry-payload definitions; a hit that is a real person-identifying field fails the gate;
  - **(I6)** no `verbatim` / Ministry-text field in spine or graph artifacts, and every node carries a `paraphrase`;
  - **(I8)** the L0 checker (the `Core` CLI — the Swift `core-cli` until the v2.8 §5 switch) is green on every graph artifact under version control (acyclic; no later→earlier course edge; code↔node coverage both ways; in-degree outliers flagged; starting chain connected);
  - **(I14)** `web/core/tsconfig.json` has no DOM lib and no ambient `types`, and `web/core/test/boundary.test.ts` is present and green; L0/layout have exactly one implementation, in `Core`;
  - **(I15)** every landmark in a shipped `data/**` bundle carries a non-empty `source_url`;
  - **(R-6)** no hardcoded ISO-date literals in test fixtures — `grep -rE '20[0-9]{2}-[0-9]{2}-[0-9]{2}'` over the test files; fixtures use the injected clock / relative offsets;
  - **(I11)** in every doc this EPIC touched, each quantitative claim carries `[SOURCED: …]` or `[ESTIMATE: …]`, and there are no time estimates anywhere.
- **(g) Cross-EPIC audit (every 3 EPICs):** dispatch **integration-auditor** → must return GREEN. RED blocks the wrap (fix findings, re-run).
- **(h) Contract version bump:** if this EPIC changed a contract, the change is committed with `chore(contract): …` and the contract's change log updated (a locked-contract change is a versioned change).
- **(i) DEFERRED.md:** any item deferred during the EPIC is recorded in `docs/DEFERRED.md` with a trigger.
- **(j) C1 seam test:** if this EPIC added a named seam (pipeline↔`Core` CLI, `Core`↔app render layer, expedition↔diagnosis, map↔expedition, telemetry client↔endpoint, bundle loader↔`Core` validation, persistence adapter↔`Core` state, or any other), exactly one real-composition test exercises it with both real sides — no double-mock. Name the seam and the test path in the acceptance report. No seam, no gate.
- **(k) C4 artifact coverage:** every artifact this EPIC ships — the `Core` package, the app build and its service worker, the `Core` CLI, a content-generation CLI, the L0 checker, a shipped data asset, a runbook command — is exercised by a gate. List them in the acceptance report with the gate that exercises each; an artifact with no gate blocks the wrap.
- **(l) C3 instrument beside claim:** every claim in the acceptance report names the instrument that produced it and what that instrument excludes; every emptiness-capable check declares `empty=PASS` or `empty=FAIL`.

## Acceptance report
Write `docs/audits/epic-<NN>-acceptance.md`: gate results, tasks completed, contracts touched, conformance-test summary, the (j) seam list, the (k) artifact→gate table, any deferrals, and — **(R-7)** — a **`fix:`-commit table** (for cascade tracking): each `fix:` commit classified by **cause** (`logic | seam | contract-gap | gate-miss | test-infra`) **and** by the **`risk` tier** of the task it corrects (`mechanical | seam`); also list any **tester tier-upgrades** (mechanical→seam, per R-3). No time estimates in the report.

## Merge & tag
- On all-green: push the EPIC branch, `gh pr create --fill --base main`, `gh pr checks --watch` (if it reports "no checks reported", the run has not registered yet — wait for `gh run list --branch <branch>` to show it, then re-run) until every CI job is green, then `gh pr merge --merge --delete-branch` (a merge commit — equivalent to `--no-ff`). The branch ruleset on `main` requires the PR and the checks in `scripts/branch-ruleset.json`; do not force-push or delete `main`. The owner may pull `git log --oneline` / the acceptance report / `scripts/gate.sh` as their review surface.
- Tag an owner-confirmed deploy state when the owner confirms (Done condition).

## Cascade detection
If this and the previous EPIC each landed with **> 3 rework `fix:` commits**, surface a **Q5** — the loop itself may need adjustment (per the provisional process-validation bar).

**A rework `fix:` corrects earlier work from the same EPIC, against shipped code.** It does NOT count:
spec/document corrections caught before implementation (they touch only `tasks/**` or `docs/**`), or a
Bug-fix EPIC's own commissioned repairs (which land as `fix:` by design). Count rework, not output —
the raw count fires on every Bug-fix EPIC by construction (owner-ratified 2026-09-05, `docs/lessons.md` §20).
The `fix:`-commit table above stays complete; mark each row **rework** or **output** and state both totals.
