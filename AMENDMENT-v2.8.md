# Amendment v2.8 — Web first; native frozen

Date: 2026-10-06
Applies to: PROJECT-BRIEF-v2.md, AMENDMENT-v2.1–v2.7 (D24, D29, D31–D36, D39, D42; I5, I14), DEMO-BRIEF.md, docs/epic-plan.md, CLAUDE.md and the kit
Status: rulings final.

**Product requirements do not change.** The three doors, the map, the trail, the scheduler policy and the content rules stand verbatim: D1–D7, D9–D23, D25–D27, D38, D40, D41, D43–D49 and invariants I1–I4, I6–I13, I15. This amendment changes platform, stack, distribution and verification only.

## 1. D31 (revised) — Web first.

The student-side product (Doors B and C, and Door A diagnosis) is a web app, installable to the home screen as a PWA, running in mobile and desktop browsers. Primary targets are iPad Safari and iPhone Safari; desktop Chrome and Safari are supported. A native app-store presence (iOS or Android) is decided later; wrapping the web app is one option, not a commitment.

## 2. D50 (new) — Native iOS frozen.

The Swift code (`Packages/`, `App/`) and the records of EPICs 01–04 stay in the repository unchanged. No agent edits them. Their CI job keeps running, scoped by path filter to changes under those paths. Web work derives from the brief, `contracts/` and `docs/domains/`, not from the Swift sources. The Swift `core-cli` outputs over `data/demo/` may be used as a test oracle for the web `Core`; where an oracle output disagrees with a contract, the contract wins.

## 3. D32 (revised) — Stack delegated to the harness.

The owner verifies at requirement level only: through product behaviour, acceptance records and wrap-gates. The harness chooses the concrete stack at Phase 5, against `claude-tech-stack-preferences.md`, and locks it in `docs/tech-stack.md` with a stated rationale for each choice. The owner is not consulted on tool choice. Changing a tool after the lock is recorded in `docs/tech-stack.md`; it is not a Q5. The lock must meet these constraints:

- (a) one strictly typed language for `Core` and the UI;
- (b) boundary validation derived from `contracts/schemas/`;
- (c) no third-party game engine (D24);
- (d) no runtime server beyond D36;
- (e) usable offline after first load;
- (f) a WebKit test path (D29).

## 4. D33 and I14 (revised) — `Core` carries over, in the web stack's language.

A renderer-free `Core` package holds graph types, L0 validation, the region-constrained layout, trail generation, the scheduler, student-state transitions and state merge. `Core` imports no DOM or browser API, and a test asserts this boundary. Layout is precomputed by a build step and read at runtime. L0 runs in the same step, and data that fails L0 is not emitted. The render layer never computes state.

I14 wording: "`Core` is renderer-free and single-source: `Core` uses no DOM or browser API; the render layer never computes state; L0 and layout exist once, in `Core`. A test asserts the boundary."

## 5. D42 (revised) — Single implementation lives in the web `Core`.

Anything the pipeline and the app must agree on is implemented once, in the web `Core`, and exposed through its command-line entry point. Currently that covers L0 validation and layout. Python invokes it and never reimplements it. Until the web `Core`'s L0 and layout land, the pipeline may keep calling the Swift `core-cli`. The switch is recorded when it happens, and after the switch the Swift `core-cli` is no longer a reference.

## 6. D34 (revised) — Platform baseline.

- Doors B and C and Tier 0 Door A: current Safari on iOS/iPadOS 18+, plus current desktop Chrome and Safari [ESTIMATE: floor confirmed at Phase 5].
- Tier 1: deferred (§8).
- Door A homework mode (M5) becomes a desktop-first surface of the same web app, not a separate app.

## 7. D35 (revised) — Distribution.

The app is distributed as a URL on static hosting and installed through Add to Home Screen. Demo testers open a preview deployment URL. No app store is involved. A privacy-policy page is required only when the URL is published beyond the testers; that is the first D19 trigger, and it is a page, not an entity.

## 8. Tier 1, M4′ and M4 deferred.

Foundation Models is unavailable to a web app. Tier 0 remains the product (I2 unchanged). Tier 1, the M4′ spike and M4 move to `docs/DEFERRED.md`. Re-entry trigger: an on-device model API is available in the target Safari versions, or a native wrapper is decided. `contracts/runtime-tiers.md` is revised at Phase 6.

## 9. D36, D17 and I5 (revised) — Local state only; no sync.

Student state is persisted locally in browser storage, and the app requests persistent storage. The student can export their state to a file and import it back. Cross-device sync is not provided: Apple-managed identity is unavailable to a web app, and accounts remain queued. The runtime infrastructure is unchanged: static content hosting plus one anonymous, append-only telemetry endpoint with no IP retention.

I5 last sentence becomes: "Cross-device sync is not provided; introducing it is a Q5."

Known risk: Safari may evict storage for sites that are not installed. This is recorded in `docs/DEFERRED.md` as a measurement to take during the Demo (installed vs. not installed), not as a diagnosis.

## 10. D29 (revised) — Verification.

Agent gate: all tests pass in CI, including end-to-end tests under both the WebKit and Chromium engines. Physical-device verification (iPad and iPhone Safari, installed to the home screen) is the owner's delivery verification at the wrap-gate. No agent task may claim it.

## 11. D24 (restated) and D39 (revised).

**D24.** No third-party game engine. The rendering technology is chosen at Phase 5, with escalation only on measured performance. Data, layout and state are strictly separated from rendering.

**D39.** Game Center is unavailable on the web. Leaderboards and achievements stay unbuilt; if they are ever built, the mechanism is decided then, with no self-built accounts or ranking service.

## 12. Demo brief deltas

- The Demo re-runs on the web. The question in §1, the hand-written data in `data/demo/` (schemas unchanged) and the acceptance items in §7 are unchanged.
- The first Demo task is a rendering check: every prompt, hint and explanation in the bundle is rendered by the chosen math renderer, and each failure is resolved by rewriting the item.
- Verification §8 is replaced with:
  - the app opens from the URL on iPad and iPhone Safari;
  - it installs to the home screen and launches offline;
  - one expedition and one diagnosis event can be completed by touch;
  - state survives reload and relaunch;
  - layout is deterministic across loads;
  - the landmark `source_url` resolves.

## 13. Milestone changes

- **Demo** — web, as in §12. Runs first.
- **M1, M2** — unchanged (pipeline). L0 and layout go through the `Core` CLI per §5.
- **M3** — web Tier 0 end-to-end: content hosting with offline snapshot and refresh, telemetry, one expedition with a Door A event on real M2 data. iCloud sync is removed.
- **M4′, M4** — deferred (§8).
- **M5** — coverage expansion. The Door A homework mode is built into the same web app.
- **Native** — deferred (§1, §2).

## 14. Workflow sequence

1. v2.8 is applied: `docs/idea.md`, `CLAUDE.md` and `docs/kit-adaptation.md` are updated, and agents, commands and gates are re-anchored to the web stack.
2. Phase 5 re-lock (`docs/tech-stack.md`, `scripts/gate.sh`, CI).
3. Phase 6 contract revision: `deployment-model.md`, `runtime-tiers.md`, the platform parts of `interaction-contract.md`, and the I14 boundary test.
4. The Phase 4 design system is reused where it fits.
5. Phase 7: a new EPIC plan with the web Demo first.

## 15. Bookkeeping

- D30 and D37: unassigned. Do not reuse.
- D50 is new (native frozen). No other new D-numbers.
- D28: still superseded by D45.
