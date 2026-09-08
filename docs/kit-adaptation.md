# Kit adaptation — bitebyte v3 → mathmath

> Planning output of the dev-environment bootstrap session (2026-09-08, authored on Fable; execution
> delegated to Opus/Sonnet/Haiku agents per the model policy below). This file is the **spec** every
> ported file was written against, and the ledger of what was changed, kept, dropped, and deferred.
> It is the mathmath analogue of bitebyte's `docs/kit-adaptation.md`.
>
> Source kit: `/Users/jimmyz/Dev/bitebyte` — `CLAUDE.md`, `bootstrap.md` (v0.4),
> `claude-tech-stack-preferences.md`, `.claude/agents/*` (11), `.claude/commands/*` (5),
> `docs/carry-forward.md`, `docs/lessons.md`, `docs/kit-verification-rebalance.md`.

---

## 0. Canonical project identity (paste verbatim into every agent's "Project context")

> **mathmath** (working name; placeholder `mathpath` in the brief) — an Ontario grade 9–12 math
> learning system for students and parents. A student brings a current homework problem; the system
> verifies each step with a CAS, locates the first wrong step, classifies the error against a fixed
> per-node error catalogue, walks a cross-grade **concept dependency graph** to the deepest unmastered
> prerequisite, confirms that hypothesis with a ~60-second probe, remediates the minimum piece, and
> returns to the original problem. Parents get a read-only view of where the student is stuck and why.
> It is a **static-hosted PWA** (no server-side application logic in MVP; the only write path is an
> opt-in anonymous telemetry endpoint). Four logical layers: ① curriculum spine (Ministry expectation
> codes) → ② concept graph (DAG, the core asset) → ③ learning objects (batch-generated explanations,
> error catalogues, hint trees, probe items) → ④ interaction (the §7 flow) + parent view. Three runtime
> tiers: Tier 0 deterministic (MathLive + Pyodide/SymPy + graph queries + pre-generated content),
> Tier 1 local model (Chrome Prompt API, WebLLM fallback), Tier 2 cloud (queued, not built).
> Ground truth: `PROJECT-BRIEF-v1.md` (decisions D1–D19, all locked).

## 1. Hard invariants (agents enforce these; a spec that contradicts one is BLOCKed)

| # | Invariant | Source |
|---|---|---|
| I1 | **Step correctness is decided by CAS, never by a language model.** No code path lets a model output decide whether a step is right. | D6 |
| I2 | **Tier 0 alone must be a usable product.** Any model call has a confidence threshold and a deterministic fallback (offer candidates / generic hint). The system never guesses a diagnosis. | D7, §4.2 |
| I3 | **Answers are never withheld; diagnosis always accompanies the answer.** | D5 |
| I4 | **Remediation is just-in-time: backtrack ≤ 2 levels per session**; deeper gaps go to the record/parent view only. | D4 |
| I5 | **No PII, no accounts.** Telemetry is anonymous, aggregate, opt-in, account-less. No field that identifies a person. | D17, D19 |
| I6 | **No verbatim Ministry curriculum text is stored or shipped.** Nodes carry expectation codes + the project's own paraphrase, and link out to the official page. | D18, §10 |
| I7 | **One cross-grade graph; a course is a node subset + depth marker.** Never 11 separate syllabi. | D3 |
| I8 | **Every accepted graph passes the L0 structural checks** (acyclic; no later→earlier course edge; code↔node coverage both ways; in-degree outliers flagged; starting chain connected). | §5 |
| I9 | **Zero human content review.** Graph and learning objects are generated + machine-verified; disputed edges ship at low confidence and are settled by probe data. Do not add "owner reviews content" steps. | D10, D12, D13 |
| I10 | **Input is a structured math editor (MathLive → LaTeX).** No OCR/handwriting paths. | D9 |
| I11 | **Docs: quantitative claims carry `[SOURCED: …]` or `[ESTIMATE: …]`; no time estimates anywhere.** | §12 |
| I12 | **Documentation and code in English; conversation with the owner in Chinese.** | §12 |
| I13 | Priority order: **quality > token conservation > speed.** (This overrides bitebyte's "rapid" second place.) | §12 |

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
├── CLAUDE.md                        # Phase 1 — this session
├── PROJECT-BRIEF-v1.md              # owner's locked brief (Phase 2 input; ratified)
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

`package.json`, `pnpm-workspace.yaml`, `.nvmrc`, `.prettierrc`, eslint, vitest, playwright, CI
workflows, commitlint, husky/pre-commit — **all Phase 5.** Do not create them now.

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
| 2 Idea capture | ✅ satisfied by `PROJECT-BRIEF-v1.md`; `docs/idea.md` is the structured extract |
| 3 Domain decomposition | **next** — proposed domain list for owner ratification: `curriculum-spine`, `concept-graph`, `learning-objects`, `content-generation` (offline pipeline, D12/L2), `interaction` (the §7 flow: editor, CAS verification, localisation, hints, probes, remediation, session record), `runtime-tiers` (Tier-1 adapters + fallback), `parent-view`, `telemetry` |
| 4 UI/prototype | after 3 |
| 5 Tech stack lock | after 4 (web-validate every pin) |
| 6 Contracts | after 5 (planned set in §7) |
| 7 EPIC plan | milestones M4′, M1, M2, M3, M4, M5, M6 map to EPIC groups |

## 10. Deferred at seed (→ `docs/DEFERRED.md`)

- D-1 UI i18n (English-only MVP). Trigger: a French-language user request or M6 scope review.
- D-2 Tier 2 cloud inference. Trigger: M4′ fails the 80 % bar (D15) or post-release demand.
- D-3 Chromebook / mobile / Safari / Firefox / OCR (brief §9). Trigger: post-release.

## Change log

| Date | Change |
|---|---|
| 2026-09-08 | Initial adaptation spec; kit ported per §3–§8. |
