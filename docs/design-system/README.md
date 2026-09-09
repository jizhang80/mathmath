# Design system — mathmath (Phase 4a)

Status: **draft, awaiting owner ratification** (bootstrap Phase 4a). Files: [`tokens.css`](tokens.css),
[`components.css`](components.css), [`gallery.html`](gallery.html) (open in a browser).

The stack is not locked until Phase 5, so this system is **stack-neutral**: CSS custom properties and plain
class names, no framework. Whatever UI toolkit Phase 5 names consumes these values; it does not replace
them. Nothing here pins a library (CLAUDE.md: no pins until `docs/tech-stack.md` exists).

## Principles

1. **Teacher, not chatbot; note, not dashboard.** One thing per screen; a single 720 px reading column for
   student and parent surfaces; sentences over scores. No percentages, streaks or gamification anywhere in
   student or parent surfaces [SOURCED: parent-view Purpose; tutoring-session §7 acceptance stance].
2. **Verdicts are typographic, not theatrical.** A wrong step gets a red left rule and one plain phrase;
   no shaking, no confetti on a pass. Correctness comes from the CAS (I1), and the UI must not imply that
   anything else judged it — so no "AI thinks…" phrasing anywhere near a step.
3. **Nothing blocks.** Loading, offline, update, consent and every recoverable error are inline strips or
   banners. The only modal is the destructive confirmation (clear history). Consent is a settings page,
   never a modal [SOURCED: telemetry W1].
4. **Honest states are first-class.** *Undetectable*, *unevaluated*, *unconfirmed*, *not seen*,
   *recorded for later* all have their own visual — grey, never red — so absence of a verdict is never
   read as failure.
5. **Cost stated before consent.** A probe says "2 questions, about a minute"; a download says "≈ 2 GB";
   consent says what leaves the device and that sent batches cannot be recalled.
6. **English only, light and dark.** UI locale is English (DEFERRED D-1). Dark mode follows the OS and
   an explicit `data-theme` wins.

## Tokens (`tokens.css`)

| Group | Tokens | Notes |
|---|---|---|
| Type families | `--font-ui` (system sans), `--font-prose` (serif: parent notes, explanations), `--font-math` (math-capable serif for rendered expressions), `--font-mono` (raw LaTeX) | Real math rendering is the Phase 5 stack's job; the prototype uses HTML `<sup>`/`<sub>` and a CSS fraction. |
| Type scale | `--t-xs` 12 · `--t-sm` 14 · `--t-md` 16 · `--t-lg` 20 · `--t-xl` 26 · `--t-2xl` 34 | Body 16 px, line-height 1.5. |
| Space | `--s-1`…`--s-8` = 4 · 8 · 12 · 16 · 24 · 32 · 48 · 64 px | 4 px base. |
| Radius / border / shadow | `--r-1` 6 · `--r-2` 10 · `--r-3` 16; `--bw` 1 px; `--shadow-1/2` | |
| Layout | `--w-read` 720 px (student, parent) · `--w-wide` 1040 px (settings tables, owner reports) | |
| Colour, neutral | `--bg` (warm paper), `--surface`, `--surface-2`, `--ink`, `--ink-2`, `--ink-3`, `--line`, `--line-strong` | |
| Colour, accent | `--accent`, `--accent-hover`, `--accent-ink`, `--accent-bg` | One accent (ink blue). |
| Colour, semantic | `--ok`, `--bad`, `--warn`, `--info`, each with `-bg` and `-line` | `ok` = CAS equivalent; `bad` = not equivalent; `warn` = domain violation / unreadable / attention; `info` = neutral guidance. |
| Focus / motion | `--focus`, `--dur` 120 ms | |

Contrast: every ink-on-bg and semantic-on-its-bg pair is chosen for ≥ 4.5:1 in both schemes [ESTIMATE:
by palette construction; verified mechanically in Phase 5 when the stack's lint runs].

## Components (`components.css`)

| Component | Class | Used for |
|---|---|---|
| App shell | `.shell`, `.shell-header`, `.nav`, `.shell-main[.wide]`, `.shell-footer` | Every page. Nav: Student · Parent · Settings. |
| Status strip | `.status-strip .status.is-ok/.is-busy/.is-bad` | "Checker loading / ready", "Offline", "Update ready at next launch". Never modal. |
| Card | `.card`, `.card-quiet`, `.section-label` | Grouping; the quiet card for context that is not the current task. |
| Prose | `.prose` | Parent note, explanations, remediation (serif). |
| Banner | `.banner-info/-ok/-warn/-error` with `.code` | Every recoverable error code from the domain docs renders here, with the code shown small. |
| Chip | `.chip-ok/-bad/-warn/-info/-outline` | Verdict labels, tier labels (Tier 0/1), node status, "hypothesis". |
| Depth meter | `.depth` with `i.on` / `i.cap` | I4 budget: three squares, level 0–2; the third square red when capped. |
| Button | `.btn`, `.btn-primary`, `.btn-quiet`, `.btn-danger`, `.btn-lg`, `.btn-block` | One primary per screen. Danger only for clear-history. |
| Form | `.field`, `.label`, `.hint`, `.input`, `.select`, `.textarea`, `.toggle` | Settings; free-text node description (Tier 1). |
| Math field | `.math-field` (+ `-toolbar`, `-input`) | Stand-in for MathLive (D9/I10). The real editor replaces `.math-field-input` only. |
| Step list | `.steps .step-ok/-bad/-domain/-unread/-undecided/-unevaluated`, `.step-problem`, `.step-note` | The verification trace: one row per Step, verdict enum mapped 1:1 to a class. |
| Choice list | `.choices .choice[.is-selected][.is-abstain][.is-proposed]` | Tier 0 error candidates (abstain = "none of these"), Tier 1 proposal to confirm. |
| Hint tiers | `.tiers .tier[.is-locked]` | Three tiers (lo-Q1); unrevealed tiers dashed, never hidden — the tree gates nothing (D5). |
| Dialog | `.dialog-backdrop .dialog` | Destructive confirmation only. |
| Empty state | `.empty` | Parent with no sessions; history with no attempts. |
| Progress | `.progress` | Model download; asset update. |
| Key-value, table | `.kv`, `.table[.num]` | Settings/storage; owner reports. |
| Node status | `.node-status.not-seen/.probed-pass/.probed-fail/.remediated/.deeper-gap` | The five parent-view states, 1:1. |
| Menu | `.menu` | Course → Strand → Node browse. |

## Voice and copy rules

- Second person, present tense, no exclamation marks, no persona name. The system never says "I".
- A verdict phrase per enum: *equivalent* → "follows"; *not_equivalent* → "does not follow";
  *domain_violation* → "breaks a condition"; *not_parseable* → "could not read this"; *timeout* →
  "could not decide in time"; *unevaluated* → "not checked yet".
- A hypothesis is always worded as one: "This might come from…", never "You don't understand…".
- A refuted hypothesis is owned by the system: "Not the issue — back to the problem."

## Ratification

| Date | Decision |
|---|---|
| 2026-09-08 | Drafted with the Phase 4b prototype. Awaiting owner ratification. |
