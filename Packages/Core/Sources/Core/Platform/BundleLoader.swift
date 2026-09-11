import Foundation

/// The typed refusal `BundleLoader.load(from:)` throws. `studentCode` is always
/// `.platformSnapshotRefused` because the directory this task loads is the Demo's only bundle set
/// (arbiter-03 § Q-C, "Code shape"); `internalCode` is the underlying, never-shown detail.
public struct BundleRefusal: Error, Equatable {
    public let internalCode: CoreError
    public let report: L0Report?

    public var studentCode: CoreError { .platformSnapshotRefused }
}

/// `Core`'s app-launch load entry point (`docs/domains/platform.md` § W1 step 1): `BundleIO.read` →
/// the format-major check → `L0Checker.validate(bundle:)`. Composes layer ① (`BundleIO`) and layer ②
/// (`L0Checker`), already implemented in `Core`; performs no rendering, no clock read, no model call.
public enum BundleLoader {
    /// Returns the bundle and its report on success; throws `BundleRefusal` on any failure. No
    /// `ContentBundle` value is ever returned or attached to a thrown error.
    public static func load(from directory: URL) throws -> (bundle: ContentBundle, report: L0Report) {
        let bundle: ContentBundle
        do {
            bundle = try BundleIO.read(from: directory)
        } catch {
            throw BundleRefusal(internalCode: .platformBundleIntegrityFailed, report: nil)
        }
        guard L0Checker.formatMajorMatches(bundle) else {
            throw BundleRefusal(internalCode: .platformBundleIntegrityFailed, report: nil)
        }
        let report = L0Checker.validate(bundle: bundle)
        guard report.passed else {
            let firstFailure = report.checks.first { !$0.passed }
            let internalCode =
                firstFailure.flatMap { L0Checker.errorCode(forRuleId: $0.id) } ?? .graphL0Failed
            throw BundleRefusal(internalCode: internalCode, report: report)
        }
        return (bundle, report)
    }
}
