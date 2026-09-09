import Foundation
import Testing

@testable import Core

/// Deeper coverage over `L0Checker`, independent of `L0CheckerTests.swift`'s own tables — every
/// assertion here is checked against `contracts/graph-constraints.md` / `contracts/error-codes.json`
/// text directly, not against `L0Checker`'s own rule-id list or `errorCode(forRuleId:)` mapping, so a
/// drift between the contract and the implementation is caught rather than mirrored.
@Suite("L0 checker — contract fidelity, isolation and boundary tests")
struct L0CheckerContractTests {
    private static var l0FixturesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .appendingPathComponent("Fixtures/l0")
    }

    private static func loadBundle(_ name: String) throws -> ContentBundle {
        try BundleIO.read(from: l0FixturesDir.appendingPathComponent(name))
    }

    // MARK: - Report completeness (C3)

    /// The ten non-advisory rule ids, copied verbatim from `contracts/graph-constraints.md`'s rule
    /// table (L0-1 … L0-10; L0-T is EPIC 02's and L0-4 is advisory, never in `checks[]`) — NOT read
    /// from `L0Checker`'s own output, so this test fails if the implementation drops or renames a
    /// rule id even though its own list would agree with itself.
    private static let contractRuleIds: Set<String> = [
        "L0-1", "L0-2", "L0-3a", "L0-3b", "L0-5", "L0-6", "L0-7", "L0-8", "L0-9", "L0-10",
    ]

    @Test("passing bundle's report lists every contract rule id, each with violations present (C3)")
    func reportListsEveryContractRuleId() throws {
        let bundle = try Self.loadBundle("valid")
        let report = L0Checker.validate(bundle: bundle)

        let reportedIds = Set(report.checks.map(\.id))
        #expect(reportedIds == Self.contractRuleIds, "checks[] must equal the contract's rule-id set exactly")
        #expect(report.checks.count == Self.contractRuleIds.count, "no duplicate ids")

        // Every check's `violations` key must be present as `[]`, never omitted — Codable's
        // synthesized encoding of a non-optional `[String]` guarantees this, verified through a real
        // encode/decode round trip rather than trusting the in-memory Swift value alone.
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let json = try #require(String(data: try encoder.encode(report), encoding: .utf8))
        for id in Self.contractRuleIds {
            #expect(json.contains(id), "encoded report must mention rule id \(id)")
        }
        #expect(
            json.contains("\"violations\":[]"),
            "at least one empty violations array must be printed, not omitted")
    }

    // MARK: - Report shape fidelity

    /// Field-for-field shape check against `contracts/graph-constraints.md` § Report shape: `{
    /// bundle_id, passed, checks: [{id, passed, violations[]}], indegree: {threshold, outliers[]} }`.
    /// Decodes into a loosely-typed JSON object (not back into `L0Report`) so an extra or renamed
    /// field the `Codable` round trip would silently tolerate is still caught.
    @Test("encoded report shape matches the contract's Report shape field for field")
    func reportShapeMatchesContract() throws {
        let bundle = try Self.loadBundle("valid")
        let report = L0Checker.validate(bundle: bundle)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(report)
        let top = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(Set(top.keys) == ["bundle_id", "passed", "checks", "indegree"])
        #expect(top["bundle_id"] is String)
        #expect(top["passed"] is Bool)

        let checks = try #require(top["checks"] as? [[String: Any]])
        #expect(checks.count == 10)
        for check in checks {
            #expect(Set(check.keys) == ["id", "passed", "violations"])
            #expect(check["id"] is String)
            #expect(check["passed"] is Bool)
            #expect(check["violations"] is [Any])
        }

        let indegree = try #require(top["indegree"] as? [String: Any])
        #expect(Set(indegree.keys) == ["threshold", "outliers"])
        #expect(indegree["threshold"] is Int)
        #expect(indegree["outliers"] is [Any])
    }

    // MARK: - L0-4 is advisory (both directions)

    @Test(
        "L0-4: no outlier on the valid fixture — indegree still reported, empty outliers, passed unaffected")
    func l0_4NoOutlierStillReported() throws {
        let bundle = try Self.loadBundle("valid")
        let report = L0Checker.validate(bundle: bundle)

        #expect(!report.checks.map(\.id).contains("L0-4"), "L0-4 is never a checks[] entry")
        #expect(report.indegree.outliers.isEmpty, "the small, evenly-spread valid fixture has no outlier")
        #expect(report.passed == true)
    }

    @Test("L0-4: a genuine in-degree outlier is reported AND passed stays true (advisory, report only)")
    func l0_4OutlierReportedButAdvisory() throws {
        // `l0-4-indegree-outlier/`: 21 nodes, one (`matrix-multiplication`) receiving 5 incoming
        // edges while every other node has in-degree 0 or 1 — a genuine 95th-percentile outlier
        // under the contract's nearest-rank threshold, constructed independently of `L0Checker`'s
        // own formula (tester-authored fixture; see reply for the derivation).
        let bundle = try Self.loadBundle("l0-4-indegree-outlier")
        let report = L0Checker.validate(bundle: bundle)

        #expect(!report.checks.map(\.id).contains("L0-4"))
        #expect(report.indegree.outliers.contains("matrix-multiplication"), "the skewed node must be flagged")
        #expect(report.indegree.threshold >= 0)
        // Advisory: passed is unaffected by the outlier — every other rule is still clean on this
        // fixture (no cycle, no course-order violation, spine/region/landmark rules all untouched).
        #expect(report.passed == true, "L0-4 must never affect passed — it is report only")
    }

    // MARK: - Negative controls: exact rule id AND exact error code, checked against the contracts independently

    /// Cross-checked against `contracts/graph-constraints.md`'s "Fails with" column AND
    /// `contracts/error-codes.json`'s code list directly (both re-read for this table), not against
    /// `L0Checker.errorCode(forRuleId:)` — that function is exactly what is under test here.
    @Test(
        "each negative-control fixture fails its exact rule id with the contract's exact error code",
        arguments: [
            ("l0-1-cycle", "L0-1", CoreError.graphL0Failed),
            ("l0-2-course-order", "L0-2", CoreError.graphL0Failed),
            ("l0-3a-unknown-code", "L0-3a", CoreError.graphL0Failed),
            ("l0-3a-uncovered-expectation", "L0-3a", CoreError.graphL0Failed),
            ("l0-3b-no-source", "L0-3b", CoreError.graphL0Failed),
            ("l0-5-broken-chain", "L0-5", CoreError.graphL0Failed),
            ("l0-6-unknown-region", "L0-6", CoreError.mapRegionUnknown),
            ("l0-7-position-outside", "L0-7", CoreError.mapLayoutMissing),
            ("l0-8-empty-unit", "L0-8", CoreError.spineUnitEmpty),
            ("l0-9-next-courses-cycle", "L0-9", CoreError.graphL0Failed),
            ("l0-10-not-https", "L0-10", CoreError.mapLandmarkUnsourced),
        ]
    )
    func negativeControlExactIdAndCode(fixture: String, ruleId: String, contractErrorCode: CoreError) throws {
        let bundle = try Self.loadBundle(fixture)
        let report = L0Checker.validate(bundle: bundle)
        let failing = try #require(report.checks.first { $0.id == ruleId })

        #expect(failing.passed == false)
        #expect(!failing.violations.isEmpty)
        // The rest of `checks[]` must still carry the OTHER nine ids untouched by this mutation
        // (report completeness holds even on a failing bundle).
        #expect(Set(report.checks.map(\.id)) == Self.contractRuleIds)

        // Raw-value cross-check against contract's error-codes.json string, independent of the enum
        // case name.
        let rawValues: [CoreError: String] = [
            .graphL0Failed: "GRAPH_L0_FAILED",
            .mapRegionUnknown: "MAP_REGION_UNKNOWN",
            .mapLayoutMissing: "MAP_LAYOUT_MISSING",
            .spineUnitEmpty: "SPINE_UNIT_EMPTY",
            .mapLandmarkUnsourced: "MAP_LANDMARK_UNSOURCED",
        ]
        #expect(contractErrorCode.rawValue == rawValues[contractErrorCode])
        #expect(L0Checker.errorCode(forRuleId: ruleId) == contractErrorCode)
    }

    /// L0-3b's contract row names two codes, `GRAPH_L0_FAILED{L0-3b, node}` /
    /// `SPINE_SOURCE_REF_UNRESOLVED`, with the note "resolution is a build-time check; the app checks
    /// presence only." `Core`'s structural L0-3b check can only ever raise the generic code; the
    /// pipeline-only `SPINE_SOURCE_REF_UNRESOLVED` case is never returned by `errorCode(forRuleId:)`.
    @Test("L0-3b maps to GRAPH_L0_FAILED, never the pipeline-only SPINE_SOURCE_REF_UNRESOLVED")
    func l0_3bMapsToStructuralCodeOnly() {
        #expect(L0Checker.errorCode(forRuleId: "L0-3b") == .graphL0Failed)
        #expect(L0Checker.errorCode(forRuleId: "L0-3b") != .spineSourceRefUnresolved)
    }

    // MARK: - Isolation of failures

    /// Verifies the implementer's own claim (task spec §5 T5 discussion): the `l0-1-cycle` fixture's
    /// back edge (`exponential-functions --> exponent-laws`, depth 3 --> depth 1) is genuinely a
    /// COURSE-ORDER violation too, not just a cycle — this is a true property of that fixture's data
    /// (a back edge in a depth-respecting DAG necessarily also runs against course order whenever the
    /// two nodes have different depths), not the checker over-reporting.
    @Test("l0-1-cycle's back edge is a true double violation: L0-1 AND L0-2 both fail, the other eight pass")
    func l0_1CycleFixtureTripsL0_2AsWellByConstruction() throws {
        let bundle = try Self.loadBundle("l0-1-cycle")
        let report = L0Checker.validate(bundle: bundle)

        let byId = Dictionary(uniqueKeysWithValues: report.checks.map { ($0.id, $0) })
        #expect(byId["L0-1"]?.passed == false)
        #expect(
            byId["L0-2"]?.passed == false,
            "the back edge exponential-functions(depth 3) --> exponent-laws(depth 1) also violates course order"
        )
        for id in Self.contractRuleIds.subtracting(["L0-1", "L0-2"]) {
            #expect(byId[id]?.passed == true, "\(id) should be untouched by this fixture's mutation")
        }
    }

    /// A tighter, tester-authored fixture that isolates L0-1 alone: a self-loop edge
    /// (`exponent-laws --> exponent-laws`) is a genuine 1-node cycle but, because `from == to`, can
    /// never violate L0-2's `depth(from) <= depth(to)` (a node's depth always equals itself). Proves
    /// the checker CAN report a single clean violation when the fixture is constructed to allow it,
    /// confirming `l0-1-cycle`'s double failure above is a fixture property, not an over-report bug.
    @Test("l0-1-self-loop-isolated (tester fixture): only L0-1 fails, all other nine rules pass")
    func l0_1SelfLoopIsolatesCleanly() throws {
        let bundle = try Self.loadBundle("l0-1-self-loop-isolated")
        let report = L0Checker.validate(bundle: bundle)

        let byId = Dictionary(uniqueKeysWithValues: report.checks.map { ($0.id, $0) })
        #expect(byId["L0-1"]?.passed == false)
        #expect(
            byId["L0-1"]?.violations == ["exponent-laws", "exponent-laws"],
            "self-loop cycle names the node twice")
        for id in Self.contractRuleIds.subtracting(["L0-1"]) {
            #expect(byId[id]?.passed == true, "\(id) must stay clean — the self-loop touches only L0-1")
        }
        #expect(report.passed == false)
    }

    // MARK: - L0-3a both directions, isolated and format-checked

    /// The implementer's shipped `l0-3a-unknown-code/` fixture REPLACES exponent-laws's only
    /// `expectation_codes` entry (`B3.4` → `B9.9`) rather than adding a second one — which means it
    /// also removes B3.4's only coverage, tripping direction B (`MTH1W.B3.4` now uncovered) as a side
    /// effect of exercising direction A. This is a true property of that fixture's data (verified,
    /// not assumed) and not the checker over-reporting; documented here rather than silently ignored,
    /// mirroring the l0-1-cycle/L0-2 finding above.
    @Test(
        "l0-3a-unknown-code (implementer's fixture) is itself a double violation: unknown code AND now-uncovered code"
    )
    func l0_3aUnknownCodeFixtureIsADoubleViolationByConstruction() throws {
        let report = L0Checker.validate(bundle: try Self.loadBundle("l0-3a-unknown-code"))
        let check = try #require(report.checks.first { $0.id == "L0-3a" })
        #expect(check.passed == false)
        #expect(
            Set(check.violations) == ["exponent-laws:MTH1W.B9.9", "MTH1W.B3.4"],
            "replacing the node's only code both cites an unknown code (direction A) and uncovers B3.4 (direction B)"
        )
    }

    /// A tighter, tester-authored fixture that isolates direction A cleanly: exponent-laws keeps its
    /// valid `B3.4` entry AND gains a second, unknown `B9.9` entry — direction A fails (unknown code)
    /// while B3.4 stays covered, so direction B never fires. Proves the two directions CAN be
    /// exercised independently when the fixture is constructed to allow it.
    @Test("L0-3a direction A, isolated: an added unknown code fails without uncovering the valid one")
    func l0_3aDirectionAIsolatedFromDirectionB() throws {
        let directionA = L0Checker.validate(bundle: try Self.loadBundle("l0-3a-unknown-code-isolated"))
        let directionB = L0Checker.validate(bundle: try Self.loadBundle("l0-3a-uncovered-expectation"))

        let aCheck = try #require(directionA.checks.first { $0.id == "L0-3a" })
        let bCheck = try #require(directionB.checks.first { $0.id == "L0-3a" })

        #expect(aCheck.passed == false)
        #expect(
            aCheck.violations == ["exponent-laws:MTH1W.B9.9"],
            "direction-A violation format: node:course.code — B3.4 stays covered, only B9.9 is unknown")
        #expect(bCheck.passed == false)
        #expect(bCheck.violations == ["MTH1W.B3.5"], "direction-B violation format: course.code")

        // Isolation: each fixture's mutation should leave every other rule (including the other
        // direction of L0-3a itself — no cross-direction bleed) clean.
        for report in [directionA, directionB] {
            let byId = Dictionary(uniqueKeysWithValues: report.checks.map { ($0.id, $0) })
            for id in Self.contractRuleIds.subtracting(["L0-3a"]) {
                #expect(byId[id]?.passed == true, "\(id) should be untouched by an L0-3a-only mutation")
            }
        }
    }

    // MARK: - Structural-only boundary: L0-3b / L0-10 check presence and referential integrity ONLY

    /// A `source_ref.locator` that is well-formed (non-empty) but does not resolve to anything real
    /// still PASSES `Core`'s L0-3b — proving `Core` performs no HTTP resolution (that is task 01.7's,
    /// per the contract's own "resolution is a build-time check; the app checks presence only").
    /// This test's very passage (a synchronous, fast, network-free `Core` function call) is the proof
    /// of the negative: an attempted network call in this sandboxed test environment would hang or
    /// fail, not silently pass fast.
    @Test(
        "L0-3b passes on a well-formed but non-resolving source_ref locator — no network resolution in Core")
    func l0_3bDoesNotResolveLocator() throws {
        let bundle = try Self.loadBundle("l0-3b-nonresolving-locator")
        let report = L0Checker.validate(bundle: bundle)
        let check = try #require(report.checks.first { $0.id == "L0-3b" })
        #expect(check.passed == true, "Core checks presence only, never resolves the locator")
        #expect(report.passed == true)
    }

    /// A landmark `source_url` that is well-formed https but points at a guaranteed-dead domain
    /// (`.invalid` TLD, RFC 2606) still PASSES `Core`'s L0-10 — HTTP resolution is the pipeline's job
    /// (I15).
    @Test("L0-10 passes on a well-formed but dead https source_url — no network resolution in Core")
    func l0_10DoesNotResolveSourceUrl() throws {
        let bundle = try Self.loadBundle("l0-10-dead-source-url")
        let report = L0Checker.validate(bundle: bundle)
        let check = try #require(report.checks.first { $0.id == "L0-10" })
        #expect(check.passed == true, "Core checks the https prefix and node-id referential integrity only")
        #expect(report.passed == true)
    }

    // MARK: - Manifest refusal, checked against the contract's exact code

    @Test("manifest naming a missing file refuses with the exact contract code, before any report exists")
    func manifestMissingFileRefusesWithContractCode() {
        #expect(CoreError.platformBundleIntegrityFailed.rawValue == "PLATFORM_BUNDLE_INTEGRITY_FAILED")
        #expect(throws: CoreError.platformBundleIntegrityFailed) {
            try L0Checker.validate(
                bundleDir: Self.l0FixturesDir.appendingPathComponent("manifest-missing-file"))
        }
    }

    @Test("format_version major mismatch refuses with the exact contract code, before any report exists")
    func manifestVersionMismatchRefusesWithContractCode() {
        #expect(throws: CoreError.platformBundleIntegrityFailed) {
            try L0Checker.validate(
                bundleDir: Self.l0FixturesDir.appendingPathComponent("manifest-version-mismatch"))
        }
    }

    // MARK: - Purity

    /// `validate(bundle:)` is a pure function: interleaved calls on two different decoded bundles
    /// never leak state into each other, and each call's result matches what a fresh, isolated call
    /// on the same bundle produces — a stronger check than calling `validate` twice on one bundle
    /// back to back (which would not catch state leaking between distinct bundle instances, e.g. a
    /// cache keyed incorrectly or a `static var` accumulator).
    @Test("validate(bundle:) leaks no state across interleaved calls on different bundles")
    func validateIsPureAcrossInterleavedCalls() throws {
        let valid = try Self.loadBundle("valid")
        let cyclic = try Self.loadBundle("l0-1-cycle")

        let validReportBaseline = L0Checker.validate(bundle: valid)
        let cyclicReportBaseline = L0Checker.validate(bundle: cyclic)

        // Interleave: valid, cyclic, valid, cyclic — if any mutable/shared state leaked between
        // calls, one of these would disagree with its own baseline above.
        let r1 = L0Checker.validate(bundle: valid)
        let r2 = L0Checker.validate(bundle: cyclic)
        let r3 = L0Checker.validate(bundle: valid)
        let r4 = L0Checker.validate(bundle: cyclic)

        #expect(r1 == validReportBaseline)
        #expect(r2 == cyclicReportBaseline)
        #expect(r3 == validReportBaseline)
        #expect(r4 == cyclicReportBaseline)
    }

    // MARK: - Anti-vacuity: every fixture directory this suite (and L0CheckerTests) names must exist

    /// A missing fixture directory is a FAIL, not a silently-skipped case — enumerates every fixture
    /// directory name used anywhere in the L0 checker test suites and asserts each resolves to a real
    /// directory on disk containing all seven bundle files.
    @Test("every fixture directory named by the L0 checker test suites exists on disk (anti-vacuity)")
    func everyNamedFixtureDirectoryExists() {
        let allNamedFixtures = [
            "valid", "l0-1-cycle", "l0-1-self-loop-isolated", "l0-2-course-order", "l0-3a-unknown-code",
            "l0-3a-unknown-code-isolated", "l0-3a-uncovered-expectation", "l0-3b-no-source",
            "l0-3b-nonresolving-locator", "l0-4-indegree-outlier", "l0-5-broken-chain",
            "l0-6-unknown-region", "l0-7-position-outside", "l0-8-empty-unit", "l0-9-next-courses-cycle",
            "l0-10-not-https", "l0-10-dead-source-url", "manifest-missing-file",
            "manifest-version-mismatch",
        ]
        #expect(allNamedFixtures.count == 19)
        #expect(Set(allNamedFixtures).count == 19, "no duplicate fixture names")

        // `manifest-missing-file/` deliberately omits `sources.json` (that absence IS the fixture,
        // AC3) — every other fixture must carry all seven files.
        let requiredFiles = [
            "manifest.json", "regions.json", "nodes.json", "edges.json", "courses.json", "landmarks.json",
            "sources.json",
        ]
        for name in allNamedFixtures {
            let dir = Self.l0FixturesDir.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDirectory)
            #expect(exists && isDirectory.boolValue, "fixture directory \(name) must exist")
            let expectedFiles =
                name == "manifest-missing-file"
                ? requiredFiles.filter { $0 != "sources.json" } : requiredFiles
            for file in expectedFiles {
                let filePath = dir.appendingPathComponent(file).path
                #expect(FileManager.default.fileExists(atPath: filePath), "\(name)/\(file) must exist")
            }
        }
    }

    // MARK: - No SHA-256 / CryptoKit anywhere in Core (I14/D33)

    /// `CoreTests.coreImportBoundary()` (task 01.1) asserts `Core` imports Foundation only, but its
    /// forbidden-import list does not name `CryptoKit` specifically. This is the hash-specific
    /// complement: scans every `Core` source file for a `CryptoKit` import or a `SHA256(` /
    /// `Insecure.SHA1(` call, matching `docs/plans/epic-01-task-plan.md` planner note 2's decision
    /// that hash computation/verification never lives in `Core`.
    @Test("Core source contains no CryptoKit import and no SHA-256 computation (I14 hash-specific check)")
    func coreHasNoCryptoKitOrHashComputation() throws {
        let sourcesDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root
            .appendingPathComponent("Sources/Core")
        let enumerator = FileManager.default.enumerator(
            at: sourcesDir, includingPropertiesForKeys: [.isDirectoryKey])
        var files: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension == "swift" {
                files.append(url)
            }
        }
        #expect(!files.isEmpty, "no Core source files found — empty scan is a FAIL")
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            #expect(!text.contains("import CryptoKit"), "\(file.lastPathComponent) imports CryptoKit")
            #expect(!text.contains("SHA256("), "\(file.lastPathComponent) computes a SHA-256 hash")
            #expect(!text.contains("Insecure.SHA1("), "\(file.lastPathComponent) computes a SHA-1 hash")
        }
    }
}
