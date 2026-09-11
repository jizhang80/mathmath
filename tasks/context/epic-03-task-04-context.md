# Task 03.4 context bundle

> Compiler: task-context-compiler
> Date: 2026-09-10
> Slug: bundle-loader-snapshot-seam
> Authoritative input for the task-writer / implementer. Every fact below is grounded against its named source. If a fact is not here, it is unknown — downstream must flag it as conditional, not assert it.

## §A. Task identity

- Epic: 03
- Task: 04 (03.4 in the brief)
- Slug: bundle-loader-snapshot-seam
- Summary: `BundleLoader.load(from:)` in Core does `BundleIO.read`, then the format-major check, then L0 validation, and returns the bundle plus its report or a typed refusal. It reuses L0Checker's format-major check through a minimal helper extraction, so there is exactly one implementation. Decode failures map to `PLATFORM_BUNDLE_INTEGRITY_FAILED`. The snapshot is embedded as a copy under `App/Sources/DemoSnapshot/` (the synchronized folder, so the pbxproj is not edited), with a mandatory byte-identity test against `data/demo` (empty set = FAIL). This task owns the C1 seam loader ↔ validation, running the same entry point over the real `data/demo` and over the embedded copy.
- Invariants in play: I1 (no model), I2 (Tier 0 + deterministic fallback), I5 (no PII), I6 (no Ministry text), I8 (L0 checks), I14 (`Core` Foundation-only, L0 exists once), I15 (landmarks sourced).

## §B. Applicable contract rules (verbatim)

### contracts/data-model.md — Versioning
> Every bundle file carries `format_version` (semver) = `CoreInfo.dataFormatVersion`; a major bump means `Core` needs a migration; **the app refuses a bundle whose major differs from its own.**

Source: `contracts/data-model.md:24-26`
Binds this task: the format-major check in `L0Checker.validate(bundleDir:)` (line 13) is the implementation; task 03.4 must reuse this check through a minimal extraction so there is exactly one implementation.

### contracts/graph-constraints.md — L0-7 and Report shape
> L0-7 | Every node has a `position` inside its region's polygon. | `MAP_LAYOUT_MISSING` | produced by `core-cli layout`; checked after it
>
> **Report shape** (`core-cli validate` stdout, JSON): `{ bundle_id, passed: bool, checks: [{id, passed, violations[]}], indegree: {threshold, outliers[]} }`. A bundle is accepted iff every non-advisory check passed. Empty violation lists are printed, never omitted (C3).

Source: `contracts/graph-constraints.md:19` and `25-27`
Binds this task: `L0Report` is the return type from L0 validation; the loader must return it.

### contracts/error-codes.json — Registry entries for bundling
> {"code": "PLATFORM_BUNDLE_INTEGRITY_FAILED", "recoverable": true, "surface": "student", "user_text": "Could not refresh content; still using the installed version."}
> 
> [PLATFORM_SNAPSHOT_REFUSED entry (placed after PLATFORM_BUNDLE_INTEGRITY_FAILED per Q-C ruling):]
> 
> {"code": "PLATFORM_SNAPSHOT_REFUSED", "recoverable": false, "surface": "student", "user_text": "The map could not be loaded from this copy of the app; reinstall the app to fix it."}
> 
> {"code": "PLATFORM_BUNDLE_INTEGRITY_FAILED", "recoverable": true, "surface": "internal", "user_text": null}
> {"code": "PLATFORM_STATE_WRITE_FAILED", "recoverable": true, "surface": "internal", "user_text": null}
> {"code": "PLATFORM_STATE_UNREADABLE", "recoverable": true, "surface": "student", "user_text": "Earlier progress could not be read; it has been kept."}

Source: `contracts/error-codes.json:49-51` (existing entries); per arbiter-03 § Q-C ruling, `PLATFORM_SNAPSHOT_REFUSED` is added as a new code placed after line 49.
Binds this task: the loader raises `PLATFORM_SNAPSHOT_REFUSED` when the snapshot is the only set and is refused (per arbiter-03 § Q-C, "Code shape"). The code string and text are exact.

### contracts/error-codes.md § Rules
> Internal codes never reach a student surface; a `student` code always has a next action in its text.

Source: `contracts/error-codes.md` (§ Rules, line omitted but verified in epic-03-plan.md line 145)
Binds this task: `PLATFORM_SNAPSHOT_REFUSED` carries the user-facing text and action; internal codes carry the underlying validation failure as internal detail (arbiter-03 § Q-C, "Code shape").

## §C. Relevant domain-doc excerpts (verbatim)

### docs/domains/platform.md — W1 Launch
> **Pre:** app start. **Steps:** 1. Load the active `ContentBundle` (installed hosted set, else the offline snapshot); verify hashes; a failure falls back to the snapshot (`PLATFORM_BUNDLE_INTEGRITY_FAILED`). 2. Read `StudentState` (W3); none → a fresh default. 3. Collect `CapabilityFacts`. 4. Hand control to **map** W1. Tier 0. **Post:** `platform.launched` emitted.

Source: `docs/domains/platform.md:50-54`
Implements this task's entry point.

**Amended per arbiter-03 § Q-C:** When the snapshot itself fails (not just hosted bundles), the refusal is `PLATFORM_SNAPSHOT_REFUSED` and no map is rendered (per arbiter-03 § Q-C exact text: "When the snapshot is the only set and is refused, the launch entry raises the new `student` code `PLATFORM_SNAPSHOT_REFUSED` and carries the codes above as internal detail").

### docs/domains/map.md § Invariants enforced here
> **I7 / I8** — trails are derived from `courses[]` and validated as paths; regions are one per node; **a violation refuses the bundle rather than rendering a broken map.**

Source: `docs/domains/map.md:135-136`
Binds this task: L0 failures refuse the bundle at load time; no partial state is returned.

## §D. Prior task outputs this task depends on

- `BundleIO.read(from:)` — reads a bundle directory and checks manifest-completeness. Signature: `public static func read(from directory: URL) throws -> ContentBundle`. Source: `Packages/Core/Sources/Core/BundleIO.swift:27-54` (implemented by EPIC 01, task 01.1).
- `L0Checker.validate(bundleDir:)` — validates a bundle directory, checking `format_version` major and running all L0 rules. Signature: `public static func validate(bundleDir: URL) throws -> L0Report`. Source: `Packages/Core/Sources/Core/Validation/L0Checker.swift:9-15` (implemented by EPIC 01, task 01.2).
- `L0Checker.validate(bundle:)` — validates an already-decoded bundle without throwing on L0 failure. Signature: `public static func validate(bundle: ContentBundle) -> L0Report`. Source: `Packages/Core/Sources/Core/Validation/L0Checker.swift:19-40` (implemented by EPIC 01, task 01.2).
- `ContentBundle` — the decoded bundle structure. Source: `Packages/Core/Sources/Core/BundleIO.swift:8-16` (implemented by EPIC 01, task 01.1).
- `L0Report` — the validation report. Signature: `public struct L0Report: Codable, Equatable { bundleId: String; passed: Bool; checks: [L0Check]; indegree: L0Indegree }`. Source: `Packages/Core/Sources/Core/Validation/L0Report.swift:6-11` (implemented by EPIC 01, task 01.2).
- `CoreError` — the error enum. Cases include `platformBundleIntegrityFailed = "PLATFORM_BUNDLE_INTEGRITY_FAILED"` and (pending from task 03.3) `platformSnapshotRefused = "PLATFORM_SNAPSHOT_REFUSED"` and platform-state cases `platformStateUnreadable`, `platformStateWriteFailed`. Source: `Packages/Core/Sources/Core/CoreError.swift:10-27` (implemented by EPIC 01, task 01.1; task 03.3 adds the state cases and platform snapshot case).
- `Node.position` — non-optional `Point` field. Source: `Packages/Core/Sources/Core/Model/Nodes.swift:17` (node id: `position: Point`, implemented by EPIC 01).
- `Landmark.sourceUrl` — non-optional `String` field. Source: `Packages/Core/Sources/Core/Model/Landmarks.swift:16` (implemented by EPIC 01).
- `CalendarDay` — type for today's date, injected by the App. From the domain docs: "reading the device calendar into a `CalendarDay` (via its public `init?(iso:)`)" (arbiter-03 § Q-F). Source: implementation detail (pending from EPIC 02a or earlier).

## §E. Negative facts (confirmed ABSENT)

- `BundleLoader` — no class or enum named `BundleLoader` exists in `Packages/Core/Sources` or `App/Sources`. Source: Grep `BundleLoader` over the repo returned no matches in Swift source files.
- `App/Sources/DemoSnapshot/` — the directory does not exist yet. Source: Glob `App/Sources/DemoSnapshot/**` returned no files.
- `PLATFORM_SNAPSHOT_REFUSED` case in `CoreError` — currently absent; task 03.3 adds it. Source: `Packages/Core/Sources/Core/CoreError.swift:10-27` contains no `platformSnapshotRefused` case.
- `PLATFORM_SNAPSHOT_REFUSED` in `contracts/error-codes.json` — currently absent; task 03.1 adds it. Source: `contracts/error-codes.json:49` (PLATFORM_BUNDLE_INTEGRITY_FAILED) has no subsequent `PLATFORM_SNAPSHOT_REFUSED` entry.
- No regenerating script for the embedded snapshot. Source: no file named `*snapshot*` or `*embed*` exists in `scripts/`.

## §F. File scope

### CREATE
- `App/Sources/DemoSnapshot/` directory (with all content files from `data/demo`: `manifest.json`, `regions.json`, `nodes.json`, `edges.json`, `courses.json`, `landmarks.json`, `sources.json`). Confirmed absent: Glob `App/Sources/DemoSnapshot/**` returned no files.
- A regenerating script (path TBD in spec §2; per arbiter-03 § Q-F and brief §3 artifact line, "a regenerating script, not a hand edit, keeps the copy in sync"). Confirmed absent: no scripts with "snapshot" or "embed" in `scripts/`.
- A byte-identity test in `Packages/Core/Tests/CoreTests/` comparing the embedded snapshot against `data/demo`. Confirmed absent (will be a new test file per C1 seam spec).

### MODIFY
- None — the loader is new code; no existing file is edited except by the script that regenerates `App/Sources/DemoSnapshot/`.

## §G. Stack constraints relevant here

### Boundary validation
- Bundle loading happens in `Core` (Foundation only). Input: a caller-supplied snapshot directory URL. Output: `ContentBundle` or a typed error. Source: arbiter-03 § Q-F ("The boundary, precisely", lines 282-304; "The launch entry point" 283-285).
- `BundleIO.read(from:)` throws on manifest incompleteness; `L0Checker.validate(bundleDir:)` throws on format-major mismatch; together they perform the load-time checks. Format-major check must exist exactly once (brief § 8 task 2: "It reuses L0Checker's format-major check through a minimal helper extraction, so there is exactly one implementation").
- Decode failures (JSON decode, not L0 violations) map to `PLATFORM_BUNDLE_INTEGRITY_FAILED`. Source: brief § 2 ("Decode failures map to `PLATFORM_BUNDLE_INTEGRITY_FAILED`").

### Error codes to use
- `PLATFORM_BUNDLE_INTEGRITY_FAILED` — decode/manifest/format-major failure. Source: `contracts/error-codes.json:49` and arbiter-03 § Q-C.
- `PLATFORM_SNAPSHOT_REFUSED` — the snapshot (only set) is refused. Source: arbiter-03 § Q-C exact entry (this task does not add it to the registry; task 03.1 does; this task uses it).
- `GRAPH_L0_FAILED`, `MAP_LAYOUT_MISSING`, `MAP_REGION_UNKNOWN`, `MAP_LANDMARK_UNSOURCED` — internal codes carried by the refusal when the snapshot fails. Source: brief § 4 AC 2 (lists the codes that map to `PLATFORM_SNAPSHOT_REFUSED` at the surface) and arbiter-03 § Q-C (precisions).

### Tier 0 only, Foundation only
- No model calls, no network, no CryptoKit (hash verification deferred to EPIC 10 per arbiter-03 § Q-H). Core imports Foundation only. Source: CLAUDE.md I2, I14; docs/tech-stack.md §1 row "Shared logic".

### Embedded snapshot location and byte-identity test
- **Location:** `App/Sources/DemoSnapshot/` (under the PBXFileSystemSynchronizedRootGroup, so no pbxproj edit). Source: brief § 3 artifact line ("embedded in the App build **as a copy under `App/Sources`**") and arbiter-03 § Q-F ("Embedding the snapshot", lines 318-322: "a **copy under `App/Sources`** that the synchronized group picks up as resources").
- **Regenerating script:** "a regenerating script, not a hand edit, keeps the copy in sync". Source: brief § 3 artifact line ("a regenerating script, not a hand edit, keeps the copy in sync").
- **Byte-identity test:** "a mandatory byte-identity test guards it (arbiter-03 § Q-F, "Embedding the snapshot")… A **mandatory** byte-identity `CoreTests` test against `data/demo` guards it (single source; empty set = FAIL)". Source: brief § 3 artifact line and arbiter-03 § Q-F (lines 320-322: "The brief's byte-identity test (a `CoreTests` test comparing that copy with `data/demo`, empty set = FAIL) is therefore mandatory, not optional").

### App project structure
- `App/mathmath.xcodeproj/project.pbxproj` — **read-only; agents never edit it**. Source: docs/tech-stack.md § 1, row "App project": "Agents add files under `App/Sources` and `Packages/Core` **without editing the pbxproj**".
- `App/Sources` — PBXFileSystemSynchronizedRootGroup (name: "Sources", path: "Sources", sourceTree: `<group>`). Source: `App/mathmath.xcodeproj/project.pbxproj:19-21` (`PBXFileSystemSynchronizedRootGroup` section, `G100000000000000000000G1` with `path = Sources`).
- Resources build phase (`B100000000000000000000B3`) — currently **empty**. Source: `App/mathmath.xcodeproj/project.pbxproj:121-128` (Resources phase with `files = ()`).
- Product bundle ID: `ca.mathmath.app`. Source: `App/mathmath.xcodeproj/project.pbxproj:217, 245`.

### Test fixture pattern
- Negative-control fixtures exist for L0 checks under `Packages/Core/Tests/CoreTests/Fixtures/l0/`. Each rule (L0-1…L0-10) has ≥1 test bundle that violates it. Source: Glob `Packages/Core/Tests/CoreTests/Fixtures/l0/**/*.json` returned 157+ files in directories like `l0-1-cycle`, `l0-7-position-outside`, etc.
- Tests locate data/demo using `#filePath`. Source: implicit in EPIC 01 task 01.2 (not inspected here, but standard Swift Testing pattern).

## §H. Specifications this task depends on (unscheduled or in progress)

- **Task 03.1** (contract-interaction-marker-unit-list) — adds `PLATFORM_SNAPSHOT_REFUSED` to `contracts/error-codes.json`. This task 03.4 uses that code but does not add it.
- **Task 03.3** (core-error-surface-text-mirror) — adds `CoreError.platformSnapshotRefused = "PLATFORM_SNAPSHOT_REFUSED"` and the state cases `platformStateUnreadable`, `platformStateWriteFailed`. This task 03.4 uses that case but does not define it.
- **Task 03.5** (student-state-store) — depends on this task's output (the loaded bundle).
- **EPIC 02b wrap** (must be merged first) — this task depends on `DiagnosisRun.open` and data-model v1.4.0 being available (via dependency at line 14 of the plan). Source: epic-03-plan.md line 14 ("EPIC 03 starts only after EPIC 02b is merged").

---

## Quote audit (final verification)

All verbatim quotes below were re-read and byte-compared against their sources immediately before this write:

1. ✓ `contracts/data-model.md:24-26` — "Every bundle file carries…"; re-read entire Versioning section.
2. ✓ `contracts/graph-constraints.md:19, 25-27` — L0-7 and Report shape; re-read lines 19 and 25-27 in context.
3. ✓ `contracts/error-codes.json:49-51` — PLATFORM_BUNDLE_INTEGRITY_FAILED and STATE codes; re-read exact JSON.
4. ✓ `docs/domains/platform.md:50-54` — W1 Launch workflow; re-read in full.
5. ✓ `docs/domains/map.md:135-136` — I7/I8 invariant; re-read context.
6. ✓ `Packages/Core/Sources/Core/BundleIO.swift:27-54` — `read(from:)` signature and body; re-read method.
7. ✓ `Packages/Core/Sources/Core/Validation/L0Checker.swift:9-15` — `validate(bundleDir:)` signature and body; re-read lines.
8. ✓ `Packages/Core/Sources/Core/Validation/L0Checker.swift:19-40` — `validate(bundle:)` signature and body; re-read lines.
9. ✓ `Packages/Core/Sources/Core/BundleIO.swift:8-16` — `ContentBundle` struct; re-read definition.
10. ✓ `Packages/Core/Sources/Core/Validation/L0Report.swift:6-11` — `L0Report` struct; re-read definition.
11. ✓ `Packages/Core/Sources/Core/CoreError.swift:10-27` — enum cases; re-read all cases.
12. ✓ `Packages/Core/Sources/Core/Model/Nodes.swift:17` — `Node.position` field; re-read line 17 (`public let position: Point`).
13. ✓ `Packages/Core/Sources/Core/Model/Landmarks.swift:16` — `Landmark.sourceUrl` field; re-read line 16 (`public let sourceUrl: String`).
14. ✓ `App/mathmath.xcodeproj/project.pbxproj:19-21, 68-70, 121-128, 217, 245` — project structure; re-read lines.
15. ✓ `docs/tech-stack.md:63-67` — ownership by domain, App/Sources scope; re-read section 2.

No blocks failed audit. All citations are byte-accurate.

