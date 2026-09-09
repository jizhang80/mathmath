# Amendment v2.2 — Native iOS first

Date: 2026-09-09
Applies to: PROJECT-BRIEF-v2.md, AMENDMENT-v2.1.md, DEMO-BRIEF.md
Status: rulings final. Supersedes v2.1 §B D8 (platform), v2.1 §B D24 clarification, v2.1 §B D29, v2.1 §D demo deltas where they conflict. v2.1 §A3–A4 (AI role, Tier 2 queue rationale), §B D27, D28 stand.

## A. Decision

**D31 — Native iOS first.** The student-side product (Doors B and C, plus Door A diagnosis) is a native iOS/iPadOS app in Swift. Android is a second codebase, built after iOS ships. Two codebases are accepted.

**D32 — Stack.** Swift 6, SwiftUI. Map rendered with SwiftUI `Canvas`; if performance on a few hundred nodes demands it, Apple's first-party SpriteKit is permitted (D24's "no game engine" bars third-party engines; first-party frameworks are allowed). Persistence: SwiftData. Math display: SwiftMath (native LaTeX subset); fallback WKWebView + KaTeX only for notation SwiftMath cannot render. Tier 1: Foundation Models framework with `@Generable` guided generation. No third-party dependencies beyond SwiftMath without a recorded reason.

**D33 — Core separation carries over.** A Swift Package `Core` holds graph data, validation (L0), layout (region-constrained force layout, implemented in Swift), scheduler, and state transitions. `Core` imports Foundation only — no SwiftUI/UIKit/SwiftData. A test asserts this. Android's `core` will be a port of the same package; the JSON data formats are shared.

**D34 — Platform baseline (replaces D8 entirely).**
- Doors B and C, and Door A diagnosis with Tier 0 behaviour: iOS/iPadOS 17+ [ESTIMATE: floor chosen for SwiftData and modern SwiftUI; confirm at stack lock].
- Tier 1 (error classification, hint wording): iOS/iPadOS 26+ on Apple Intelligence-capable hardware (A17 Pro / M1 or later) with Apple Intelligence enabled [SOURCED: Apple Newsroom 2025-09; WWDC25 Session 286]. Availability is checked at runtime; ineligible devices run Tier 0.
- Door A homework mode (structured input + CAS step verification): remains web, desktop, deferred to M6 (see §C). Chrome Prompt API is no longer on the critical path.
- Android: after iOS. Tier 1 on Android via ML Kit GenAI / AICore where available; decided at that time.

**D35 — Distribution.** Apple Developer Program membership exists. Demo and all pre-release testing via TestFlight internal testers (no App Review) [SOURCED: App Store Connect TestFlight documentation, high confidence]. A privacy-policy page is required only at external TestFlight / App Store publication; that is the first D19 trigger and is a page, not an entity.

**A5 resolved.** iOS storage eviction no longer applies; student state is persisted with SwiftData. Serialisable state schema remains a requirement (for Android port and any future export).

**M4′ retargeted.** The Tier 1 spike runs on Foundation Models with a `@Generable` enum output, on an eligible device. Same node, same six-way error enum, same synthetic round-trip data, same ≥ 80% go line [ESTIMATE: owner-set]. If no eligible device is available to the owner, the spike is blocked and this must be raised as a Q5, not worked around.

## B. Demo brief deltas (replace v2.1 §D)

- Platform: native iOS app, iPhone-first, iPad supported. Distributed to the two testers via TestFlight internal testing.
- No web version of the demo.
- Stack per D32/D33. Data files per DEMO-BRIEF §5 unchanged (JSON, bundled).
- Add a **rendering spike** as the first task in the Demo EPIC: render every probe item and hint in `nodes.json` with SwiftMath; list any that fail; decide per item between rewriting the notation and the WKWebView fallback. Record the outcome.
- Two trails (MTH1W, MCR3U) and start marker per D28; error tolerance per D27 — unchanged.
- Acceptance §7 unchanged (six observations). Verification §8: replace the browser items with: builds and runs on a physical iPhone; one expedition and one diagnosis event completable by touch; state survives app relaunch; layout deterministic across launches; landmark source URL resolves.

## C. Milestone changes

- **Demo** — native, as above. Runs first.
- **M4′** — Foundation Models spike, parallel with M1.
- **M1, M2** — unchanged (content pipeline; platform-independent).
- **M3** — native Tier 0 end-to-end: one expedition with a Door A diagnosis event on real M2 data; L3 telemetry (opt-in, anonymous). Homework/CAS flow removed from M3.
- **M4** — Tier 1 integration via Foundation Models, with availability gating and Tier 0 fallback.
- **M5** — Parent view (native).
- **M6** — Coverage expansion; **Door A homework mode as a desktop web app** (Pyodide + SymPy, MathLive) built here; Android port planned here.
- **Release** — iOS after M6; Android after its port.

## D. Workflow sequence (replaces v2.1 §C)

v2 + v2.1 (surviving parts) + v2.2 → update `idea.md` and domain decomposition → Phase 5 stack lock (D32, D33; Xcode/iOS SDK versions validated; a physical-device test path is mandatory) → Demo as one EPIC, serving as the Phase 4 UI/UX artifact for Doors B and C → Phase 6 contracts fed by `Core`'s data shapes.
