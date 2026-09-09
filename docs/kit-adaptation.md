# Kit adaptation — bitebyte v3 → mathmath

> Planning output of the dev-environment bootstrap session (2026-09-08, authored on Fable; execution
> delegated to Opus/Sonnet/Haiku agents per the model policy below). This file is the **spec** every
> ported file was written against, and the ledger of what was changed, kept, dropped, and deferred.
> It is the mathmath analogue of bitebyte's `docs/kit-adaptation.md`.
>
> Source kit: `/Users/jimmyz/Dev/bitebyte` — `CLAUDE.md`, `bootstrap.md` (v0.4),
> `claude-tech-stack-preferences.md`, `.claude/agents/*` (11), `.claude/commands/*` (5),
> `docs/carry-forward.md`, `docs/lessons.md`, `docs/kit-verification-rebalance.md`.
>
> **2026-09-09 — v2 pivot.** The product moved to a three-door map form on a native iOS app
> (`PROJECT-BRIEF-v2.md` + `AMENDMENT-v2.1`–`v2.5`). §0 and §1 below are updated to the v2 identity and
> point at `CLAUDE.md` for invariants; §4–§7 still describe the *web* port done on 2026-09-08 and are
> re-anchored at Phase 5 (stack lock) together with every agent definition and command — see §9.

---

## 0. Canonical project identity (paste verbatim into every agent's "Project context")

> **mathmath** (working name; candidate *Upstream*; never `mathpath`) — an Ontario grade 9–12 math
> learning system for students. One cross-grade **concept dependency graph** is rendered as a **map**
> organised by math's own taxonomy (Door C); students cross it in ~3-minute **expeditions** of probe
> items that lift fog (Door B); a blocked node triggers an in-map **diagnosis** — hypothesis, ~60-second
> probe on the upstream node, minimal remediation, return (Door A). Courses are trails over the map;
> landmarks are real, sourced things linked to nodes. A **single-user native iOS/iPadOS app in Swift 6 /
> SwiftUI** (no accounts, no parent view); a Swift Package `Core` (Foundation only) owns graph data, L0,
> layout, scheduler and state; Android is a later port. **No application server**: static hosting of
> versioned content JSON plus one anonymous telemetry endpoint (on by default, one-tap off, no
> identifiers). The offline content pipeline is Python. Four logical layers: ① curriculum spine → ②
> concept graph (with regions, coordinates, trails) → ③ learning objects (+ landmarks) → ④ interaction
> (three doors). Runtime tiers: Tier 0 deterministic (in-code item checking, graph queries, pre-generated
> content); Tier 1 on-device Foundation Models (iOS 26+, availability-gated); Tier 2 cloud (queued). The
> desktop web homework mode (structured editor + CAS) is deferred to M5.
> Ground truth: `PROJECT-BRIEF-v2.md` + `AMENDMENT-v2.1`–`v2.5` (decisions D1–D49 locked; D30, D37
> unassigned); consolidated in `docs/idea.md`.

## 1. Hard invariants (agents enforce these; a spec that contradicts one is BLOCKed)

The authoritative table is `CLAUDE.md` § Hard invariants — **I1–I15** as of 2026-09-09 (I1, I4, I5, I7, I8,
I10 amended for v2; I14 `Core` separation and I15 sourced landmarks added). This file no longer duplicates
it; agents read `CLAUDE.md`. Gate (f) in §6 is restated against the v2 table at Phase 5.

## 2. Model policy (owner directive, 2026-09-08)

- **Fable** is used **only** by the owner's interactive sessions for project planning and design
  (bootstrap Phases 1–6 decisions, EPIC plans, Phase-8 lessons capture, process changes). It never
  runs `/run-epic`, `/run-task`, or any agent.
- **Opus** — the reasoning tier of the agent ladder: `planner`, `epic-scoper`, `spec-arbiter`,
  `spec-architect`, `brief-amender`. Also the recommended model for the **orchestrating session**
  that runs `/run-epic` / `/run-epics` (the owner switches the session model before invoking them).
- **Sonnet** — execution tier: `implementer`, `tester`, `task-writer`, `task-reviewer`.
- **Haiku** — mechanical tier: `task-context-compiler`, `integration-auditor`, file inventories, greps.
- Same tiering as bitebyte's `bootstrap.md` §Phase 7b; the only change is the explicit Fable rule.
  `CLAUDE.md` carries a short "Model policy" section so every session sees it.

## 3. Directory layout (Phase 0 scaffold — created this session)

```
/
├── CLAUDE.md                        # Phase 1 — rewritten 2026-09-09 for v2
├── PROJECT-BRIEF-v2.md + AMENDMENT-v2.1…v2.5.md   # owner's locked brief and deltas (ground truth)
├── DEMO-BRIEF.md                    # the map form-test Demo (D26), as amended
├── PROJECT-BRIEF-v1.md              # superseded; history only
├── bootstrap.md                     # playbook v0.5 (v0.4 + carry-forward controls)
├── claude-tech-stack-preferences.md # copied unchanged
├── docs/
│   ├── idea.md                      # Phase 2 output — structured extract of the brief + pointer
│   ├── kit-adaptation.md            # this file
│   ├── carry-forward.md             # copied unchanged (the seed; §2 controls installed below)
│   ├── lessons.md                   # EMPTY body + admission-bar header (carry-forward §3)
│   ├── DEFERRED.md                  # ledger with the C6 entry template; seeded with 3 entries
│   ├── domains/ design-system/ prototype/   # Phases 3–4 (empty)
│   ├── epics/ audits/ blocked/ plans/       # Phase 7 (empty)
│   ├── tech-stack.md                # Phase 5 (not yet)
│   └── epic-plan.md                 # Phase 7a (not yet)
├── contracts/                       # Phase 6 (README only)
├── tasks/{context,blocked,arbitration}/     # Phase 7 (empty)
├── modules/                         # optional reusable modules (empty)
└── .claude/
    ├── agents/                      # 11 agents, re-anchored (§5)
    ├── commands/                    # run-epic, run-epics, run-task, wrap-epic (§6)
    └── settings.json                # project permissions (minimal)
```

Xcode project / Swift package manifests, `pyproject.toml`, linters, CI workflows, pre-commit hooks —
**all Phase 5.** Do not create them now. (The 2026-09-08 text named the web equivalents; superseded by
D31–D34, D41.)

## 4. Strip list — bitebyte identity that must NOT appear in any mathmath file

| Strip | Replace with |
|---|---|
| `BiteByte`, `v3`, restaurant / inventory / supplier / scheduling / reservation / storefront / staff-web | the §0 identity paragraph |
| `@siclab/base`, sicbase, `/sicbase-issue`, local-fix rule, `docs/sicbase-local-fixes.md`, "Layer-0 library", vendored tarball | nothing (mathmath consumes no base library). `modules/` remains "prefer over building from scratch" per bootstrap. |
| single-tenant / multi-tenant / per-client instance / `tenantId` / `clientId` / feature-flag "no code forks" | nothing — mathmath is one static PWA. Keep "variation is config, never a fork" only if a spec introduces a config surface. |
| Hono, Drizzle, Postgres, PGlite testkit, Redis, BullMQ, pino, Zod 4 pinned versions, Node 24 / TS 6 / pnpm 11 pins, Tailwind/shadcn, TanStack | "Stack is locked in `docs/tech-stack.md` (bootstrap Phase 5). Until then: TypeScript strict; boundary validation with a schema library; tests via the runner named in tech-stack.md; gates are `pnpm typecheck && pnpm lint && pnpm format:check && pnpm test`." Agents must read `docs/tech-stack.md` for the concrete toolchain and BLOCK if a spec pins a tool that file does not name. |
| `apps/*` / `packages/*` layout, `apps/api`, `apps/staff-web`, `apps/storefront`, `packages/contracts`, `packages/ui`, `packages/i18n` | "the file layout is defined by `docs/tech-stack.md`; a spec's §2 file scope is authoritative" |
| the "13 contracts" list, READ-ONLY inherited contracts, `ports-kernel`, `observability`, `rbac-matrix`, `audit-event-set`, `event-catalog`, `i18n-conventions` grep gates, `APP_CONFIG_INVALID` / `*_REGISTRY_INVALID` guard set | "conform to every contract in `contracts/` (populated in Phase 6; see `contracts/README.md` for the planned set)" — see §7 for the planned mathmath contract set and gates. Keep the **generic** guard-set rule (lesson 1) rephrased: "enumerate every config/registry-bearing module's startup-failure guard set before planning." |
| E2E "authed + storefront surfaces", RBAC, auth, login, JWT | "the ratified core workflow(s) of the §7 interaction contract, plus the parent view once M5 lands" |
| Docker compose infra, image build in CI | none in MVP (static hosting). C4 still applies: every shipped artifact (the PWA build, the service worker, the content-generation CLI, the L0 checker CLI, any runbook command) is exercised by a gate in the EPIC that ships it. |
| i18n / Loi 101 / `fr` fallback | UI locale is English-only for MVP → `docs/DEFERRED.md` entry. No hardcoded-string lint rung. |

## 5. Agents — port map (`.claude/agents/`)

All 11 bitebyte agents are ported **1:1, same names, same tools, same model tier**, with (a) the §0
identity paragraph replacing every BiteByte context paragraph, (b) §1 invariants inserted as hard
rules where the agent makes decisions (`implementer`, `tester`, `task-writer`, `task-reviewer`,
`planner`, `epic-scoper`), (c) the §4 strip list applied, (d) every rule that is process-generic
**kept verbatim in substance** — Q-protocol, BLOCK protocol, quote-fidelity (lesson 16), "never
mirror an existing file exactly" (lesson 19), guard-tests-for-shell-then-fill (lesson 22),
companion-test ownership (lesson 12), risk tiers `mechanical | seam` (R-2), tester depth by tier
(R-3 option A), never re-verify the happy path (R-4), scoped vs full test runs (R-5), the four
gates (R-1), instrument-beside-claim (lesson 18 / C3), real-composition seam test (P1 / C1),
negative control for every regression guard (P2 / C2), cite sibling specs by heading not line
(lesson 13), interface-defining tasks before consumers (lesson 3), split at brief seams (lesson 5).

| Agent | Model | mathmath-specific additions |
|---|---|---|
| `planner` | opus | (1) every EPIC that adds a seam — editor↔CAS worker, graph query↔UI, Tier-1 adapter↔Tier-0 fallback, telemetry client↔endpoint, generation pipeline↔asset loader — owns one real-composition test (C1); (2) any EPIC touching graph data schedules the L0 checker as a gate (I8); (3) flag shell-then-fill decompositions (lesson 22 planner half, previously unapplied); (4) BLOCK if a brief scopes a model-calling component without its confidence threshold + Tier-0 fallback named (I2). |
| `epic-scoper` | opus | brief checklist must state: which milestone (M1–M6, M4′) and which layer(s) ①–④ the EPIC serves; which invariants I1–I13 it can violate and how the EPIC prevents that; the guard-set enumeration (generic form); the P4/C4 artifact list ("what this EPIC ships that a gate must exercise"). |
| `spec-arbiter`, `spec-architect`, `brief-amender` | opus | identity only. Brief-amender's Q5 stop must cite the D-number or brief section it would change; changing a locked decision D1–D19 is **always** Q5. |
| `task-writer` | sonnet | keep the full Quote-fidelity + mirror-rule sections. Add: every spec §1 lists which invariants I1–I13 apply; specs touching `[SOURCED]/[ESTIMATE]`-bearing docs keep the tags (I11); no time estimates (I11). |
| `task-reviewer` | sonnet | BLOCK on any spec that lets a model decide correctness (I1), stores verbatim Ministry text (I6), adds an identifying field (I5), adds a human-review step (I9), or pins a tool absent from `docs/tech-stack.md`. |
| `implementer` | sonnet | hard rules I1, I2, I5, I6, I10 verbatim; gates generic (§4); `console.log` ban stays (use the project logger named in tech-stack.md, or none until locked); no `TODO/FIXME/@ts-ignore` stays. |
| `tester` | sonnet | Depth-by-tier + R-4 kept. Add C2 (negative control for every regression guard) as a **required coverage item**; add "a Tier-1 adapter test must prove the Tier-0 fallback fires below threshold" (I2); fixtures use clock-relative dates (lesson 8). |
| `task-context-compiler` | haiku | keep the mandatory byte-compare quote audit (C7). Identity only otherwise. |
| `integration-auditor` | haiku | audit set = `contracts/**`, `docs/domains/**`, source per tech-stack.md, plus **graph/content artifacts** (run the L0 checker; every node has ≥1 expectation code and a `paraphrase`; no `verbatim` field; every edge has `sources[]` + `confidence`). Every empty-capable check declares empty=PASS or empty=FAIL (C3). |

Frontmatter format is unchanged: `name`, `description`, `tools`, `model`.

## 6. Commands — port map (`.claude/commands/`)

- `run-epic.md`, `run-epics.md`, `run-task.md` — ported with the strip list; halt conditions and the
  **rework**-only cascade rule (lesson 20) kept verbatim.
- `wrap-epic.md` — gates (a)–(e) generic; gate (f) becomes the mathmath conformance set below;
  (g) auditor every 3 EPICs; (h) contract bump; (i) DEFERRED; **new (j) C1 seam test present for any
  EPIC that added a named seam; new (k) C4 every artifact this EPIC ships is exercised by a gate
  (list them in the acceptance report); new (l) C3 every claim in the acceptance report names its
  instrument and exclusions.** Acceptance report keeps the `fix:` table with rework/output marking.
- `sicbase-issue.md` — **dropped.**

Gate (f) — mathmath conformance greps (finalized in Phase 6; ship these now as the baseline):
- no `console.log` in source; no `TODO|FIXME|XXX|@ts-ignore|@ts-expect-error`;
- no identifying fields in any persisted or transmitted schema (`name|email|phone|address|student_id|ip`
  as field keys) — I5;
- no `verbatim` / Ministry-text field in spine or graph artifacts; every node has `paraphrase` — I6;
- L0 checker green on every graph artifact under version control — I8;
- no hardcoded ISO-date literals in test fixtures (R-6);
- docs touched by the EPIC: every number carries `[SOURCED]`/`[ESTIMATE]`; no time estimates — I11.

## 7. Planned contract set (Phase 6 — listed here so agents can name them; NOT authored yet)

`domain-glossary.md` (node, edge, course, depth, expectation code, error type, probe, hypothesis,
remediation, session, tier), `data-model.md` (node/edge schema from brief §5; ID policy; IndexedDB
stores; versioning of shipped assets), `graph-constraints.md` (L0 rules + the empirically-set
in-degree threshold), `runtime-tiers.md` (confidence thresholds, fallback rules, the "never guesses"
rule, model-output JSON schemas), `content-policy.md` (I6 paraphrase rule, `[SOURCED]/[ESTIMATE]`,
attribution/link-out), `telemetry.md` (anonymous event schema, opt-in, aggregate-only, the single
write path), `error-codes.md` (app-level error registry), `interaction-contract.md` (brief §7 as a
machine-checkable state machine), `ai-usage.md` (offline content generation with the Claude API:
prompts versioned, outputs schema-validated, multi-run intersection for graph edges — D12/L2).

## 8. bootstrap.md v0.4 → v0.5 (edits applied on port)

1. Constants gain **"Every shipped artifact is exercised by a gate in the EPIC that ships it"** (P4).
2. Constants gain the **DEFERRED entry template** (`observed / configuration / trigger` +
   `hypothesis (unverified)`) (P6 / C6).
3. Version-control constant: commit-message and formatting checks run **pre-commit** (C8), wired in
   Phase 5.
4. Phase 5: "Containerize infrastructure services" becomes conditional ("if the project has any");
   deployment-model text made conditional (single-tenant per client applies only to multi-client
   products). Static-hosted projects skip Docker entirely.
5. Phase 7b model-tiering table gains the Fable row from §2.
6. Goals order stays as bitebyte's (quality > rapid > token) in the generic playbook; **mathmath's
   project override (quality > token > speed) lives in `CLAUDE.md`**, since the playbook is meant to
   be reusable.
7. Changelog entry for v0.5.

## 9. Phase status after this session

| Phase | Status |
|---|---|
| 0 Scaffold | ✅ this session (`git init`; first commit pending owner) |
| 1 CLAUDE.md | ✅ this session |
| 2 Idea capture | ✅ `docs/idea.md` re-cut 2026-09-09 as the consolidated extract of `PROJECT-BRIEF-v2.md` + `AMENDMENT-v2.1`–`v2.5` |
| 3 Domain decomposition | ✅ v1 ten domains ratified 2026-09-08; **v2 re-cut 2026-09-09**: `map` and `expedition` added, `tutoring-session` → `diagnosis`, `parent-view` removed (D38), `platform` / `telemetry` / `runtime-tiers` rewritten for native iOS, `verification` moved to M5, the rest edited. **v2 open questions ratified by owner 2026-09-09 (all defaults)** — `docs/plans/phase3b-open-questions-v2.md` |
| 4 UI/prototype | v1 web prototype (25 pages) is **superseded** for student and parent surfaces; per v2.2 §D the **native Demo is the Phase 4 artifact for Doors B and C** (built as one EPIC after Phase 5). `student-session-*` pages remain reference for the M5 homework mode; `owner-*` reports remain valid; `parent*` pages void |
| 5 Tech stack lock | ✅ 2026-09-09 — `docs/tech-stack.md` (Swift 6 / SwiftUI / `Core` package / SwiftMath 1.7.3 / Foundation Models; Python 3.14 + uv + ruff + pyright + SymPy + anthropic SDK; GitHub Actions macos-26; pre-commit; `main` ruleset; Cloudflare for content + no-IP telemetry endpoint at M3). Scaffold: `App/`, `Packages/Core`, `pipeline/`, `scripts/gate.sh`, CI. Agents and commands re-anchored per v2.4 §2 (see change log) |
| 6 Contracts | **next** — planned set in §7, extended by `map-data`, `student-state`, `expedition-scheduling`, `landmarks`; `Core` data shapes from the Demo feed them |
| 7 EPIC plan | Demo (first), M4′, M1, M2, M3, M4, M5 map to EPIC groups (v2.3 §B renumbering) |

## 10. Deferred at seed (→ `docs/DEFERRED.md`)

- D-1 UI i18n (English-only MVP). Trigger: a French-language user request or M5 scope review.
- D-2 Tier 2 cloud inference. Trigger: re-rationalised by v2.1 A4 — see `docs/DEFERRED.md`.
- D-3 … D-7 re-cut 2026-09-09 for v2 (Android, desktop homework mode, Firefox/Prompt API, parent view,
  Game Center, OCR) — see `docs/DEFERRED.md`.

## Change log

| Date | Change |
|---|---|
| 2026-09-08 | Initial adaptation spec; kit ported per §3–§8. |
| 2026-09-09 | Phase 5 locked (`docs/tech-stack.md`); `.claude/agents/*` and `.claude/commands/*` re-anchored to the v2 stack per v2.4 §2 (gates → `scripts/gate.sh`; wrap-epic merges via PR + green CI; I14/I15 in BLOCK lists). |
| 2026-09-09 | v2 pivot: §0 identity rewritten (three doors, native iOS, no parent view, Python pipeline); §1 now points at `CLAUDE.md` I1–I15; §3 layout note; §9 status re-cut (Phase 3 v2 done, Phase 4 superseded by the native Demo, Phase 5 next incl. agent re-anchoring); §10 deferrals re-cut. §4–§7 unchanged pending Phase 5. |
