# Amendment v2.1 — Platform reframe and Q5 rulings

Date: 2026-09-09
Applies to: PROJECT-BRIEF-v2.md, DEMO-BRIEF.md
Status: rulings final. Apply as deltas; do not rewrite the parent documents.

## A. Reframe: platform and the role of AI

**A1. Student-side platform is mobile-first.** Doors B and C are Tier 0 (no model) and target phones and tablets as the primary device. Desktop is supported but secondary for these doors.

**A2. Tier 1 does not exist on mobile.** Chrome Prompt API is desktop-only; WebLLM on phones is impractical. Door A's free-text entry and error classification (Tier 1) remain desktop Chrome only.

**A3. AI is primarily a build-time tool for the student-facing product.** Its main role is D12 (batch generation of explanations, error catalogues, hint trees, probe items, landmarks). Runtime AI is limited to Door A on desktop. This is stated so the harness does not treat "AI in the product" as a mobile runtime requirement.

**A4. Tier 2 reclassified in the queue.** Still not built. Its queue rationale changes from "fallback when Tier 1 fails" to "possible attractor if in-product AI conversation proves to be part of the appeal (per tester feedback)". Revisit after Demo observations.

**A5. New residual unknown.** iOS Safari may evict local storage for sites not installed to the home screen after a period of no interaction [SOURCED: WebKit ITP storage policy; duration not asserted here]. Streaks and lifted fog would be lost. Demo ignores this. Before M3: decide between guided home-screen install, exportable student state, or anonymous sync (must stay within D17). Student state schema must be serialisable from the start.

## B. Decision changes

**D8 (rewritten)**
Per-door platform baseline:
- Doors B and C: iOS Safari (current and previous major iOS), Android Chrome (current), and desktop Chrome/Edge/Safari. PWA-installable. No model, no Pyodide, no MathLive required.
- Door A, homework mode with CAS: desktop browsers (Pyodide + MathLive), any of Chrome/Edge/Safari.
- Door A, Tier 1 (free-text mapping, error classification, hint wording): desktop Chrome 148+, non-Chromebook, ≥16 GB RAM, ≥20 GB free, WebGPU.

**§9 Out of scope (amended)**
Replace "Safari / Firefox" with: "Firefox (all doors); Safari for Door A Tier 1 only". Replace "Chromebook for Door A" with "Chromebook for Door A Tier 1 only".

**D27 (new) — Expedition error tolerance.** A missed item gives one retry item on the same node. A second miss on that node triggers a Door A event. At most one Door A event per expedition; subsequent misses mark the node and continue without interruption.

**D28 (new) — Self-placed start marker.** Each trail has a start marker. Default position: the first node of the student's selected course trail (not the global graph root). The student may move it. Nodes upstream of the marker stay under fog but are excluded from the expedition frontier; they are entered only through Door A. Diagnosis is the safety net for a marker placed too far ahead.

**D29 (new) — Stack lock includes a mobile Safari test path.** Phase 5 must establish a runnable iOS Safari test path (device or simulator) alongside desktop CI. A stack that only verifies on desktop is not locked.

**D24 (clarified)** React + TypeScript + D3 + SVG + KaTeX confirmed. Pyodide, MathLive, and Prompt API are reserved for Door A and are not part of the Doors B/C bundle.

## C. Workflow sequence (accepted)

v2 + this amendment → update `idea.md` and domain decomposition incrementally → Phase 5 stack lock (D24, D29) → Demo executed as one EPIC, serving as the Phase 4 UI/UX artifact for Doors B and C (no static-HTML map prototype) → Phase 6 contracts, with `core/` data shapes from the Demo feeding the contract files.

## D. DEMO-BRIEF.md deltas

- §2 constraint "Runs in desktop Chrome; usable on phone" → **"Primary target: iOS Safari and Android Chrome on a phone; must also run on desktop Chrome and Safari. Phone experience is the one being tested."**
- §3.3 Trail → **two trails: MTH1W and MCR3U**, each an ordered node-id list. Start marker per D28; default at each trail's first node; draggable.
- §3.5 Expedition → apply D27 (retry once; second miss → Door A; max one Door A card per run). Frontier excludes nodes upstream of the marker.
- §3.6 Diagnosis → unchanged mechanics; add the one-per-run cap.
- §7 Acceptance → item 3 now testable for both testers (each has a trail). Add item 6: "Where did each tester place the start marker, and did Door A ever pull them upstream of it?"
- §8 Verification → add: demo loads and completes one expedition on a real iPhone Safari and a real Android Chrome; state survives a page reload (IndexedDB).
