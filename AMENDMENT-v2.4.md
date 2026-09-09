# Amendment v2.4 — Rulings on harness corrections

Date: 2026-09-09
Applies to: PROJECT-BRIEF-v2.md, AMENDMENT-v2.2.md, AMENDMENT-v2.3.md, CLAUDE.md and the kit
Status: rulings final.

## 1. Persistence — accepted. D32 amended.

Student state types are `Codable` structs in `Core` (Foundation only). The App layer persists them as JSON in Application Support. SwiftData is removed from the stack. D33 stands unchanged.

D36 consequence: cross-device sync of the JSON state file uses iCloud (iCloud Drive document container or CloudKit asset — chosen at M3, not now). No accounts of ours either way.

## 2. CLAUDE.md and kit rewrite — authorised, with the proposed wording.

- Swift is the student-side primary language.
- TypeScript is retained only for the desktop homework mode, now at **M5** (renumbered in v2.3; not M6).
- I1: add the qualifier "wherever step verification exists".
- I10: "Input is defined per door: expedition items are numeric or multiple-choice; homework mode uses a structured math editor; no OCR in any door."
- Remove pnpm/PWA/MathLive/Pyodide references from all agent definitions, `run-task`, and gate commands except where scoped to M5 desktop.
- Gates: replace web build/test commands with `xcodebuild` build + test on simulator (see §6) and the Python pipeline checks (see §3).

## 3. Offline pipeline language — Python. D41.

The content pipeline (spine extraction, graph generation runs, L1 source matching, L0 validation, content generation, SymPy answer verification, layout precompute) is Python. Rationale: SymPy is required for offline answer verification; a second TypeScript project would add a maintenance surface with no benefit. Output is the shared JSON data formats consumed by `Core`.

## 4. Test distribution — direct install via Xcode. D35 amended.

The two testers' devices are registered to the developer account and builds are installed directly from Xcode with development signing. TestFlight is not used for the Demo. (TestFlight remains the path for any later external testing.)

## 5. Minimum iOS — 18. D34 amended.

Doors B/C and Tier 0 diagnosis: iOS/iPadOS 18+. Tier 1 unchanged (26+, Apple Intelligence-capable hardware).

## 6. Device verification responsibility — accepted. D29 restated.

Agent gate: all tests pass under `xcodebuild` on the iOS simulator. Physical-device verification is the owner's delivery verification at the wrap-gate, recorded there. No agent task may claim device verification.

## 7. Layout precompute — accepted. D33 clarified.

The region-constrained force layout lives in `Core` as a pure function. A build step (Python pipeline calling the same algorithm ported, or a Swift CLI target invoking `Core`) runs it once and writes node coordinates into the data files. The App reads coordinates at runtime and never recomputes layout. L0 validation runs in the same build step; data files that fail L0 are not emitted.

Note: to avoid two implementations, the reference implementation is the Swift function in `Core`, invoked from a small Swift command-line target in the same package; the Python pipeline calls that binary. If this proves awkward at M1, port to Python and mark the Python version as reference — record the switch.

## 8. Parent view — moot.

v2.3 D38 removed the parent view entirely. Nothing to record in §11. If the kit still references a parent view or M5-parent, delete those references under the same authorisation as §2.
