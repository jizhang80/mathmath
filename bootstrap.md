# Project bootstrap — process playbook

> **How to use**: drop this file into the root of a new Claude Code project. Also drop `claude-tech-stack-preferences.md` alongside it (and, if available, the framework doc for rationale). Tell Claude Code: *"Read `bootstrap.md` and follow it. Begin at Phase 0."*
>
> This file is the playbook for the entire lifecycle of the project, from idea to working software. It is read once at start and followed sequentially.
>
> This file is **not** `CLAUDE.md`. The project generates its own `CLAUDE.md` in Phase 1 from the reusable RULES foundation.
>
> Version: v0.5. Refine after each project based on what worked and what didn't. (Changelog at end.)

---

## Constants — read first, hold throughout

### The organizing principle: definition vs. convergence

The owner-involvement model below is not arbitrary. The owner is in the loop for **definition activities** (which create ground truth — what to build, for whom, how it should behave) and hands off **convergence activities** (which have a checkable right answer — turning contracts into code). The test for whether any step needs the owner: *is this defining ground truth, or converging on it?* Definition stays with the owner; convergence is Claude's.

### Goals (tie-breaking priority order)

1. **High-quality** — ships working, correct software
2. **Rapid** — minimize time-to-done; the owner's throughput is the durable constraint
3. **Token-efficient** — avoid wasteful token spend, but this is a depreciating cost and yields to (1) and (2)

When goals conflict, resolve by (1) over (2) over (3). The operative consequence: **when tokens and time trade off, spend tokens to save time** — more parallel agents, an extra verification pass, a higher model tier when it reaches done faster.

(Note: "spend cheap design tokens to avoid expensive correction tokens" is *not* a cost goal — it is the front-loading principle, which serves (1) and (2). It lives in its own constant below and is not subject to this tie-break.)

A project may override this order for its own run; the override belongs in that project's `CLAUDE.md`, not here — this playbook stays reusable.

### Every shipped artifact is exercised by a gate in the EPIC that ships it

An image, compose file, CLI entry, migration path, generated asset or runbook command that no task consumes is protected by no gate. If nothing depends on it, nothing forces it to be true — and it will be green and broken simultaneously for as long as that holds. This is the one failure mode that produces **no signal at all** while it lasts, so it is enumerated from the **artifact list**, never from the test list: at each EPIC wrap, list what this EPIC ships and name the gate that exercises each item.

### Deferral entries record a measurement, not a diagnosis

Every entry in `docs/DEFERRED.md` uses this template:

```
### D-n — <item>
**Observed:** what was actually measured or decided, and by whom/when.
**Configuration:** the environment/config under which that observation holds.
**Revisit trigger:** the condition that brings this item back.
**Hypothesis (unverified):** any diagnosis or proposed remedy — or "none".
```

A diagnosis or prescribed remedy never appears outside the `Hypothesis (unverified)` block, and **consuming work re-measures before planning against an entry**. The recorded diagnosis is otherwise read as ground truth by whoever picks the item up later, and it is the one part of the entry nobody re-derives.

### Owner involvement model

- **Phases 1–6 (design / definition)**: owner is in the loop. Answers questions, ratifies decisions, reviews prototypes. Synchronous and interactive.
- **Phase 7 (auto-execute / convergence)**: **nothing**. No daily summaries. No per-EPIC pushes. No progress reports. Claude Code runs end-to-end without owner involvement unless a Q5 fires.
- **The owner does not review code.** The owner's review surface is **wrap-reports + test results + the running UI** — not raw commit diffs. The owner pulls these when they choose. (Debugging, when needed, is Claude-assisted; see the review-surface constant below.)

### Review-surface constant (failures must surface where the owner looks)

Because the owner reviews at the test/UI layer and never at the code layer, the architecture must make failures **surface as build errors, test failures, or visible UI defects** — never as silent behavior hidden in unread code. This constant drives Phases 4–6: prefer compile-time typing and boundary validation over runtime-only behavior; prefer explicit state over hidden framework magic. The bound on what is buildable is: **Claude can diagnose and repair it, AND its failures are observable at the test/UI surface, AND there is an escalation path for the catastrophic case** (security incident, data loss → engage outside help).

### The only legitimate STOP is Q5

| Question type | Resolution |
|---|---|
| Q1: information | Read contracts/docs; answer self |
| Q2: tool error | Auto-retry |
| Q3: permission | `bypassPermissions` |
| Q4: spec drift | Route to spec-arbiter, not owner |
| Q5: owner decision | Stop and ask owner |

**If Q5 fires often during execution, the design phase didn't lock enough decisions. Fix upstream design, don't lower the threshold downstream.**

### Front-load over in-flight

Every decision deferred from design to execution becomes mid-execution rework — which costs quality and time (goals 1 and 2), not just tokens. Cheap, high-leverage decisions live in Phases 1–6; expensive corrections live in Phase 7. Pay upfront. (This is the engine: ambiguity is what the agent fills with guesses, and guesses compound across tasks.)

### Tech stack (two-tier)

- The **abstract stack principles** are durable and tool-independent (strict typing, explicit state, thin runtime, boundary validation, explicit data access, observability at the review surface). They live in the framework doc and do not change per project.
- The **concrete tool choices** are the per-project instantiation, derived in Phase 5 from `claude-tech-stack-preferences.md`.
- Choose what Claude does best, not what the owner is most familiar with — bounded by the review-surface constant above.
- Validate every version pin via web search at decision time. Do not assume "newer = better."
- **If the project has infrastructure services** (database, cache, object store, mail), containerize them from Phase 5. A project with no such services — e.g. a statically hosted client-only app — skips containers entirely.
- **Do not containerize the application for development.** Where an app image exists at all, it is built at deploy time only.

### Version control (Git from day 1)

Git discipline is what makes error recovery and cascade detection work; it is established at scaffold, not added later. Shaped for an agent-executed, no-human-code-review process:

- **Repo from Phase 0.** `git init` at scaffold, before any project content.
- **Commit = task.** One clean commit per completed, verified task (WIP commits allowed during a task, squashed to a single task-commit once the task's verify-check passes). The task-commit is the rollback unit: a derailed task reverts without touching adjacent work.
- **Conventional Commits, scoped to EPIC/contract** — `feat(scheduling): …`, `fix(...)`, `test(...)`, `chore(contract): …`. This is dual-purpose: human-scannable (the owner reads `git log --oneline` as a progress pull without opening diffs — fits the review surface) and machine-parseable (cascade detection counts `fix:`/hotfix commits mechanically; contract changes are flagged by scope so their ripple is auditable, per "a locked-contract change is a versioned change").
- **Commit-message and formatting checks run pre-commit, not at wrap.** Every gate-miss of this class is otherwise caught late and paid for with a message-only rewrite; the cost is entirely preventable at authoring time. Wire the pre-commit hook in Phase 5, alongside the commit linter.
- **Branch per EPIC; merge to `main` only on green.** The agent works on an EPIC branch and merges to `main` only when wrap-gates pass (matches "no green, no advance"). `main` is the known-good reference the owner confirms at the test/UI surface. A badly drifted EPIC is dropped at the branch, not unwound commit-by-commit.
- **Tag owner-confirmed states.** When the owner confirms a deployment works (Done condition), tag it — a known-good restore point and deploy marker.
- **Rollback policy** (operationalizes error recovery): task derails → revert to the last task-commit; EPIC derails badly → drop the EPIC branch and re-plan from `main`. Prefer cheap rollback over forward-fixing.

### Module and contract accumulation

If a `modules/` directory or sibling library exists, prefer those over building from scratch. **The same applies to contracts**: prefer a reusable Layer 0 contract library and *parameterize* it per project (Phase 6) rather than drafting every contract from scratch. Mark uses inline so they can be updated together later. Reusable contracts carry their own enforcement (types, lint rules, conformance tests).

### Lessons capture is manually triggered

No automatic mechanism. The owner initiates a review session when issues accumulate. `docs/lessons.md` starts empty and stays empty until manually populated.

### Process-validation metrics (when this run is also a process experiment)

When the goal of a project is partly to validate the process itself (e.g., a deliberate greenfield rebuild), define the pass/fail bar **before** Phase 7, so the experiment terminates on evidence rather than feeling: Q5 frequency, correction-rounds per feature, cascade count, contract coverage, and at least one module or contract graduating to the Layer 0 library. The project "done" condition is separate from this process bar.

---

## Phase 0 — Scaffold

Create the project skeleton. No owner input needed.

```
/
├── CLAUDE.md                        # Generated in Phase 1
├── bootstrap.md                     # This file
├── claude-tech-stack-preferences.md # Provided
├── docs/
│   ├── idea.md                      # Phase 2
│   ├── domains/                     # Phase 3
│   ├── design-system/               # Phase 4
│   ├── prototype/                   # Phase 4
│   ├── tech-stack.md                # Phase 5
│   ├── epic-plan.md                 # Phase 7
│   ├── lessons.md                   # Empty until manually triggered
│   └── DEFERRED.md                  # Entry template only; gets entries when items are deferred
├── contracts/                       # Phase 6 (seeded from reusable contract library)
├── .claude/
│   ├── agents/                      # If meta-process kit provides; otherwise empty
│   └── skills/                      # If meta-process kit provides; otherwise empty
├── modules/                         # Optional reusable modules
├── package.json                     # Phase 5
└── docker-compose.yml               # Phase 5 — only if the project has infrastructure services
```

Output: directory structure exists with empty placeholders. No project-specific content. Run `git init` and commit the empty scaffold (`chore: scaffold`) — the repo exists from the first commit.

---

## Phase 1 — Generate the initial `CLAUDE.md`

Goal: a minimal, durable `CLAUDE.md`. This file is loaded every session — every token has cost. Start from the reusable `CLAUDE.md` foundation (the portable RULES block) and add only the project-specific shell.

**`CLAUDE.md` contains only:**
- Project name + one-line purpose
- Principal language(s) and locale defaults
- Directory layout (so Claude Code can navigate)
- Pointer to `bootstrap.md` for the playbook
- Pointer to `claude-tech-stack-preferences.md` for stack rules
- Pointer to `contracts/` (once Phase 6 has populated it)
- Pointer to `docs/lessons.md` (once it has entries)
- A `RULES` section: the portable behavioral rules (from the reusable `CLAUDE.md` foundation), flagged visibly
- Any project-specific hard invariants and any project override of the goal order above

**`CLAUDE.md` does not contain:**
- Current project state ("EPIC 4 in progress", "next: ...")
- Time-anchored content ("as of 2026-05-06")
- Duplicate content from `contracts/`, `docs/`, or `lessons.md`
- Architectural overviews — those live in domain docs
- History or change log

If it goes stale fast, it does not belong in `CLAUDE.md`.

Output: `CLAUDE.md` at project root.

---

## Phase 2 — Idea capture (interactive Q&A)

Goal: turn the owner's informal ideas into a structured starting point. (Definition activity — owner-led.)

**Process:**
1. Owner provides an initial description (one sentence, a paragraph, a long ramble — whatever)
2. Claude Code asks **one focused question at a time** (never a wall of questions)
3. Question coverage:
   - Who uses it? (rough role categories)
   - What problem does it solve?
   - What does a user do day-to-day with it?
   - What existing applications does it resemble? (reference apps)
   - What does success look like?
   - What scale is expected?
   - What compliance / regulatory constraints?
   - What is explicitly **not** in scope?
4. After each owner answer, Claude Code summarizes what it now understands and confirms before asking the next
5. Iterates until Claude Code can write a coherent one-page idea document the owner ratifies

**Output**: `docs/idea.md` with sections:
- One-line description
- Who uses it
- Core problem it solves
- Reference applications
- Scale expectation
- Compliance constraints
- Explicit non-goals

---

## Phase 3 — Domain decomposition + per-domain design

Goal: carve the project into domains and write the structured design doc for each. (Definition activity — owner-led.)

### Sub-phase 3a — Domain decomposition

1. Claude Code proposes an initial domain list based on `docs/idea.md`
2. Owner reviews and adjusts (add, remove, rename, merge, split)
3. Iterate until owner ratifies

### Sub-phase 3b — Per-domain design

For each domain, write `docs/domains/<domain>.md` using this template:

- **Purpose** — what this domain is for, who it serves
- **Actors and roles** — who can do what (table)
- **Core entities** — narrative description of the data (not schema yet)
- **Workflows** — Pre / Steps / Post for each significant operation
- **UI surfaces** — page paths per role (placeholder; confirmed in Phase 4)
- **Notifications produced** — events emitted to other domains
- **Errors produced** — error codes this domain emits
- **Open questions** — explicit list with default proposals
- **Change log** — date-stamped entries

For each open question: Claude Code proposes a default with a one-line trade-off; owner ratifies or overrides. **Resolving open questions in design saves Q5 events in execution.**

Output: one markdown file per domain in `docs/domains/`.

---

## Phase 4 — UI/UX design and HTML prototype

Goal: validate the design through an interactive prototype before any business code is written. Catch missed functions, missed buttons, wrong processes here — not during a late EPIC. (Definition activity — owner-led.)

### Sub-phase 4a — Design system

- If a `docs/design-system/` is provided as input, use it
- Otherwise generate a basic design system (tokens, typography, color, primitive components) using the stack's defaults
- Owner ratifies the design system

### Sub-phase 4b — HTML prototype

- Generate clickable HTML mockups covering **every workflow in every domain doc**
- Use the design system
- **Every workflow must have an entry point in the prototype; every workflow must terminate.** No backend; data is mocked
- No business logic — the goal is interaction completeness, not function

### Sub-phase 4c — PDCA review

- **Plan**: Claude Code walks owner through each major scenario with the prototype
- **Do**: owner clicks through each workflow on the prototype
- **Check**: maintain a completeness checklist — for every workflow in every domain doc, is there a clickable entry point and a clear termination? Surface gaps (missing buttons, missing screens, ambiguous flows)
- **Act**: revise prototype based on findings; iterate

Loop until checklist is fully resolved or items are explicitly written to `docs/DEFERRED.md`.

Output: `docs/prototype/` with HTML files; `docs/design-system/` finalized.

---

## Phase 5 — Tech stack lock

Goal: commit to specific technology choices, validated. Phase 5 instantiates the abstract stack principles into concrete tools; it informs and is informed by Phase 6 (you pick a stack partly to enforce contracts cheaply — see the enforcement ladder).

**Process:**
1. Start from `claude-tech-stack-preferences.md` (the concrete-instantiation layer)
2. For each major dependency, web-search `<library> <version> issues` and `<library> recent regressions` to validate at decision time
3. Where the preferences doc lists competing options for a slot, pick its primary recommendation; if tied, pick the option with the better recent stability signal. Sanity-check against your own prior correction-round data where it exists — the principle is binding, the specific tool is not
4. Write `docs/tech-stack.md` with: choice, version, rationale, validation citation (search result URLs)
5. Set up:
   - `package.json` with locked versions
   - **If the project has infrastructure services**: a compose file bringing them up locally. A project with none skips this step and ships no container tooling
   - **CI configuration from day 1** (GitHub Actions or equivalent) — not "vendor deferred"
   - **Branch protection + commit-lint + pre-commit hook**: protect `main` so merges require green CI (the enforcement-ladder gates: type/lint/test); wire a Conventional Commits linter so the commit history stays machine-parseable for cascade detection; run the commit-message and formatting checks **pre-commit**
6. In dev: infra services (if any) come up via the compose file; the app runs directly on host or VM
7. Where a deploy-time app image is needed at all, its Dockerfile exists for deploy-time use but is not the dev runtime
8. **Deployment model** — state it explicitly for this project. For a multi-client product, the default is one image deployed per client as an isolated single-client instance with per-client config/flags supplied at deploy time, and no shared multi-client instance. For a single-deployment or statically hosted product, state the hosting target instead; the per-client model does not apply

Output: `docs/tech-stack.md`, `package.json`, CI config, branch protection + commit-lint + pre-commit, plus a compose file and Dockerfile only where the project actually has them.

---

## Phase 6 — Contracts

Goal: define machine-checkable single-source-of-truth contracts. **Start from the reusable Layer 0 contract library and parameterize per project**; draft from scratch only the few contracts with no portable skeleton (chiefly domain vocabulary and domain-specific business rules).

Standard set (add only what the project needs; a small single-purpose tool may need 2–3, a customizable product may need all):

- `api-conventions.md` — paths, pagination, envelopes, status codes, idempotency
- `error-codes.md` — error registry
- `data-model.md` — ID policy, soft-delete, audit columns, naming, money/units/timezone representation
- `deployment-model.md` — how the product is deployed and what isolation that implies (only where the project has a deployment model to constrain)
- `feature-flags.md` — the flag/config conventions where the product has a configurable surface: variation is flag/config-driven, **never a code fork**, one flag-check primitive used everywhere, a feature is either flag-gated or universal; flag naming, ownership, and removal-when-universal-or-dropped
- `rbac-matrix.md` — role × resource matrix (only where the product has roles)
- `i18n-conventions.md` — if multi-locale: default locale, plural rules, currency, timezone
- `event-bus.md` — event names, payload schemas, producer/subscriber rules
- `information-architecture.md` — NAV, route guards, role-based visibility
- `domain-glossary.md` — the ubiquitous-language glossary; one agreed term per concept, used by every EPIC/type/table/API

**Lock-first set** (retrofitting corrupts data, security, or the single-codebase model): data representation, deployment model, config/no-forks, domain glossary, i18n, and the AI-through-the-abstraction rule. Lock these before any dependent EPIC starts. Keep discovery-zone contracts open and finalize just-in-time. A change to a locked contract is a versioned change — it ripples to every conforming EPIC.

For each contract:
1. Claude Code drafts (parameterizing the reusable library) from Phase 3 domain docs and Phase 4 UI surfaces
2. Owner reviews and signs off
3. Wire enforcement at the **cheapest rung that holds the contract** — the ladder: **type system → static analysis / lint → schema / config check → runtime contract test**. Higher rungs are preferred because they surface failures at the owner's review layer (build/lint failure) rather than requiring a runtime test to expose them

Output: `contracts/` populated; enforcement wired in repo.

---

## Phase 7 — EPIC plan + auto-execute

Goal: build the project autonomously, EPIC by EPIC, with no owner involvement except Q5. (Convergence activity — Claude-led.)

### Sub-phase 7a — EPIC plan

1. Claude Code reads `docs/domains/`, `docs/prototype/`, `contracts/`
2. Generates `docs/epic-plan.md` with EPICs categorized:
   - **Foundation** — scaffolding, base infra
   - **Feature** — one domain or sub-domain each
   - **Bug-fix** — distinct category; gate set differs (regression test first; no new contracts; smaller scope)
   - **Process** — rare; only when the loop itself must change
3. **EPIC size cap**: if an EPIC's planned task count exceeds the cap, split it. EPICs do not grow unbounded
4. Owner signs off on EPIC plan. This is the **last synchronous owner interaction** before auto-execute begins

### Sub-phase 7b — Auto-execute

Claude Code dispatches the agent loop per EPIC. Owner involvement: **nothing** unless Q5.

**Agent loop per EPIC:**
- planner → implementer → tester → reviewer → integration-auditor → wrap-gates → next EPIC

**Q-protocol active throughout:**
- Q1/Q2/Q3/Q4 handled inside the loop
- Q5 fires owner-stop (rare; if frequent, design phase was insufficient)

**Per-EPIC wrap-gates must be green to advance.** No green, no advance. Every EPIC's wrap enumerates the artifacts it ships and the gate exercising each (see the shipped-artifact constant).

**Git behavior in the loop** (per the Version control constant): each EPIC runs on its own branch; the implementer commits one clean task-commit per verified task (Conventional Commits, scoped); the EPIC branch merges to `main` only when wrap-gates are green; a derailed task reverts to its last task-commit and a badly drifted EPIC drops its branch and re-plans from `main`.

**Model tiering** (per agent definition):

| Tier | Use for | Examples |
|---|---|---|
| Fable | Owner's interactive planning and design sessions only — never runs an agent or an EPIC | Phase 1–6 decisions, EPIC plans, Phase-8 lessons capture, process changes |
| Opus | Deep thinking, rare calls | spec-architect, epic-scoper, planner, brief-amender, spec-arbiter, cascade detection; the orchestrating session that runs the EPIC commands |
| Sonnet | Execution, frequent calls | implementer, tester, task-writer, task-reviewer |
| Haiku | Mechanical, very frequent | task-context-compiler, integration-auditor (mechanical checks), lint runs, file inventory |

The agent's scope must match its model tier. If a Sonnet agent needs Opus-level reasoning, the agent's scope is too broad — split it.

**Owner pulls when they want** — reads wrap-reports, test results, the running UI, or `docs/lessons.md`. Nothing is pushed. (Raw commit diffs are not the owner's review surface.)

**Cascade detection**: if two consecutive EPICs land with hotfix counts above the configured threshold, or wrap-gate retry counts above threshold, surface a Q5. The process itself may need adjustment.

Output: working software, EPIC by EPIC, until the project's scope is complete.

---

## Phase 8 — Lessons capture (owner-triggered, any time)

This is not a fixed phase. Owner initiates a review session whenever — typically after several EPICs, after a cascade, at project milestones.

**In a review session:**
1. Claude Code reads recent wrap-reports, hotfix history, Q5 events, any failed tests/lint runs
2. Drafts entries into `docs/lessons.md` with date stamps and source citations
3. Owner ratifies entries

**Lesson graduation**: if the same lesson appears across multiple projects, it graduates to a module candidate (`modules/`), a Layer 0 contract, or a refinement of this playbook / the framework doc. (Second-consumer rule applied to the process.)

---

## Done condition

The project is done when:
- All EPICs in the plan have wrapped green
- All workflows in domain docs have working implementations
- All contracts are enforced by their chosen rung (type/lint/schema/test)
- The owner has reviewed the deployment (at the test/UI surface) and confirmed it works

There is no automatic "project done" trigger. The owner declares done. (Where this run is also a process experiment, the process-validation bar is judged separately from this product "done" condition.)

---

## What this file does *not* do

- Does not specify the exact prompt for each phase — that's the job of skills/agents in `.claude/`
- Does not define agent behavior — those are in `.claude/agents/`
- Does not define contracts — those are in `contracts/`
- Does not capture project-specific decisions — those live in `docs/`
- Does not hold abstract rationale — that's in the framework doc

This file is the playbook. The artifacts live elsewhere.

---

## Version / changelog

- **v0.5** — carry-forward controls folded into the playbook: (1) new constant *"every shipped artifact is exercised by a gate in the EPIC that ships it"*, enumerated from the artifact list and checked at wrap; (2) new constant giving the `docs/DEFERRED.md` entry template (`Observed / Configuration / Revisit trigger` plus a separate `Hypothesis (unverified)` block, with re-measurement required before consuming an entry); (3) version-control constant now requires commit-message and formatting checks to run **pre-commit**, wired in Phase 5 alongside the commit linter; (4) containerization made conditional — infrastructure services are containerized only if the project has any, statically hosted projects ship no container tooling, and the deployment-model step now states that the per-client isolated-instance default applies only to multi-client products; (5) Phase 7b model-tiering table gains the Fable row (owner planning sessions only; never runs an agent or an EPIC) and names the orchestrating session's tier; (6) goal order left unchanged here (quality > rapid > token) with an explicit note that a project's override belongs in its own `CLAUDE.md`, keeping this playbook reusable; (7) this changelog entry.
- **v0.4** — set the deployment model to single-codebase / per-client single-tenant instances + feature flags (replacing shared-instance multi-tenancy). Phase 6 gains `deployment-model.md` and `feature-flags.md` contracts; data-model contract drops multi-tenancy; lock-first set updated; Phase 5 adds the per-client deployment step.
- **v0.3** — (1) reordered goals to High-quality > Rapid > Token-efficient, decoupling the front-loading principle out of the cost goal and adding the "spend tokens to save time" tie-break; (2) added a Version control constant (Git from day 1, commit=task, Conventional Commits, branch-per-EPIC merging to `main` on green, tags, rollback policy) and wired it into Phases 0, 5, and 7.
- **v0.2** — synthesized with the SicLab framework. Changes from v0.1: (1) named the definition-vs-convergence principle behind the owner model; (2) corrected the review surface to wrap-reports/tests/UI, not commit diffs, and added the review-surface constant + corrected verification bound; (3) made stack and contracts two-tier and had contracts accumulate like modules; (4) made Phase 6 enforcement the explicit ladder and added a domain-glossary contract; (5) added process-validation metrics for runs that are also process experiments.
- **v0.1** — initial draft from meta-process design session.
