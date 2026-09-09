import Foundation
import Testing

@testable import Core

@Suite("L0 checker (contracts/graph-constraints.md)")
struct L0CheckerTests {
    /// `Packages/Core/Tests/CoreTests/Fixtures/l0`, located the same way `DecodeRoundTripTests`
    /// locates `contracts/examples/`: from `#filePath`, one `.deletingLastPathComponent()` call
    /// reaches `Packages/Core/Tests/CoreTests`, then `.appendingPathComponent("Fixtures/l0")`.
    private static var l0FixturesDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .appendingPathComponent("Fixtures/l0")
    }

    // AC5 / C3: the fixed fixture-directory list, not a directory glob — an empty or partial list
    // is a FAIL. Asserted before any case runs.
    private static let fixtureDirs = [
        "valid", "l0-1-cycle", "l0-2-course-order", "l0-3a-unknown-code",
        "l0-3a-uncovered-expectation", "l0-3b-no-source", "l0-5-broken-chain", "l0-6-unknown-region",
        "l0-7-position-outside", "l0-8-empty-unit", "l0-9-next-courses-cycle", "l0-10-not-https",
        "manifest-missing-file", "manifest-version-mismatch",
    ]

    private static func loadBundle(_ name: String) throws -> ContentBundle {
        try BundleIO.read(from: l0FixturesDir.appendingPathComponent(name))
    }

    // AC5: fixed list has exactly 14 fixture directories (`valid/` + 13 mutations; L0-3a has two, plus
    // the two `manifest-*` refusal fixtures).
    @Test("fixture-count anti-vacuity guard (AC5)")
    func fixtureCountGuard() {
        #expect(Self.fixtureDirs.count == 14, "expected valid/ + 13 mutation fixtures")
        #expect(Set(Self.fixtureDirs).count == 14)
    }

    // T1 / AC1: happy path over `valid/`.
    @Test("valid fixture passes every non-advisory rule (AC1)")
    func validFixturePasses() throws {
        let bundle = try Self.loadBundle("valid")
        let report = L0Checker.validate(bundle: bundle)

        #expect(report.passed == true)
        #expect(report.checks.count == 10)
        let ids = Set(report.checks.map(\.id))
        #expect(
            ids == [
                "L0-1", "L0-2", "L0-3a", "L0-3b", "L0-5", "L0-6", "L0-7", "L0-8", "L0-9", "L0-10",
            ])
        for check in report.checks {
            #expect(check.passed == true, "\(check.id) unexpectedly failed: \(check.violations)")
            #expect(check.violations.isEmpty)
        }
        #expect(report.indegree.threshold >= 0)

        // Structural guarantee: violations is present as an empty array, not an omitted key.
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(report)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let redecoded = try decoder.decode(L0Report.self, from: data)
        for check in redecoded.checks {
            #expect(check.violations == [])
        }
    }

    // T2 / AC2 / AC3: one negative control per rule, asserting both the exact rule id's `passed ==
    // false` with a non-empty `violations`, and `errorCode(forRuleId:)` for that rule id.
    @Test(
        "negative-control fixtures detect their violation with the named error code (AC2)",
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
    func negativeControlDetectsViolation(fixture: String, ruleId: String, errorCode: CoreError) throws {
        let bundle = try Self.loadBundle(fixture)
        let report = L0Checker.validate(bundle: bundle)
        let check = try #require(report.checks.first { $0.id == ruleId })
        #expect(check.passed == false)
        #expect(!check.violations.isEmpty)
        #expect(L0Checker.errorCode(forRuleId: ruleId) == errorCode)
    }

    // AC3: manifest-missing-file throws platformBundleIntegrityFailed before any report is built.
    @Test("manifest-missing-file throws platformBundleIntegrityFailed before any report (AC3)")
    func manifestMissingFileThrows() {
        #expect(throws: CoreError.platformBundleIntegrityFailed) {
            try L0Checker.validate(
                bundleDir: Self.l0FixturesDir.appendingPathComponent("manifest-missing-file"))
        }
    }

    // manifest-version-mismatch also throws platformBundleIntegrityFailed (major version differs).
    @Test("manifest-version-mismatch throws platformBundleIntegrityFailed")
    func manifestVersionMismatchThrows() {
        #expect(throws: CoreError.platformBundleIntegrityFailed) {
            try L0Checker.validate(
                bundleDir: Self.l0FixturesDir.appendingPathComponent("manifest-version-mismatch"))
        }
    }

    // T3: error-taxonomy table, independent of any fixture.
    @Test(
        "errorCode(forRuleId:) matches the contract's Fails-with column (T3)",
        arguments: [
            ("L0-1", CoreError.graphL0Failed),
            ("L0-2", CoreError.graphL0Failed),
            ("L0-3a", CoreError.graphL0Failed),
            ("L0-3b", CoreError.graphL0Failed),
            ("L0-5", CoreError.graphL0Failed),
            ("L0-6", CoreError.mapRegionUnknown),
            ("L0-7", CoreError.mapLayoutMissing),
            ("L0-8", CoreError.spineUnitEmpty),
            ("L0-9", CoreError.graphL0Failed),
            ("L0-10", CoreError.mapLandmarkUnsourced),
        ]
    )
    func errorCodeTable(ruleId: String, expected: CoreError) {
        #expect(L0Checker.errorCode(forRuleId: ruleId) == expected)
    }

    // T5 / AC4: L0-4 never appears in `checks[]`; its data lives only in `indegree`.
    @Test("L0-4 is advisory only — never in checks[] (AC4)")
    func l0_4NeverInChecks() throws {
        let bundle = try Self.loadBundle("valid")
        let report = L0Checker.validate(bundle: bundle)
        #expect(!report.checks.map(\.id).contains("L0-4"))
        #expect(report.indegree.threshold >= 0)
    }

    // T5: `passed` is an AND over all ten checks, not e.g. only the first failing check — most
    // checks on the `l0-1-cycle` fixture still pass even though `passed` overall is false.
    @Test("passed is false when any single rule fails, even if the rest pass")
    func passedIsAndOverAllChecks() throws {
        let bundle = try Self.loadBundle("l0-1-cycle")
        let report = L0Checker.validate(bundle: bundle)
        #expect(report.passed == false)
        let acyclicCheck = try #require(report.checks.first { $0.id == "L0-1" })
        #expect(acyclicCheck.passed == false)
        let passingCount = report.checks.filter(\.passed).count
        #expect(passingCount >= 1, "at least one other check should still pass")
        #expect(passingCount < 10)
    }

    // T5: manifest-completeness reuse — `L0Checker.validate(bundleDir:)` throws the identical
    // `CoreError` case `BundleIO.read` throws directly, proving delegation rather than
    // reimplementation.
    @Test("manifest-completeness refusal delegates to BundleIO.read, not a reimplementation")
    func manifestCompletenessDelegatesToBundleIO() {
        let dir = Self.l0FixturesDir.appendingPathComponent("manifest-missing-file")
        var checkerError: CoreError?
        var bundleIOError: CoreError?
        do {
            _ = try L0Checker.validate(bundleDir: dir)
        } catch let error as CoreError {
            checkerError = error
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
        do {
            _ = try BundleIO.read(from: dir)
        } catch let error as CoreError {
            bundleIOError = error
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
        #expect(checkerError == .platformBundleIntegrityFailed)
        #expect(checkerError == bundleIOError)
    }

    // T6: `validate(bundle:)` is a pure, deterministic function of its input.
    @Test("validate(bundle:) is deterministic across two calls")
    func validateIsDeterministic() throws {
        let bundle = try Self.loadBundle("valid")
        let report1 = L0Checker.validate(bundle: bundle)
        let report2 = L0Checker.validate(bundle: bundle)
        #expect(report1 == report2)
    }
}
