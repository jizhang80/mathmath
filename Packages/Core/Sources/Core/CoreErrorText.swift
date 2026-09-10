import Foundation

/// The registered `user_text` for every `student`-surface code in `contracts/error-codes.json`, mirrored
/// verbatim — no new copy is authored here (content-policy voice: `contracts/error-codes.md` § Rules).
/// `internal`/`owner` codes have no entry (§1 AC2). `ErrorUserTextParityTests` asserts this table matches
/// the registry in both directions.
public enum CoreErrorText {
    public static let userText: [String: String] = [
        "MAP_MARKER_OFF_TRAIL": "The marker stays where it was; pick a unit from the list.",
        "EXP_NO_FRINGE":
            "You've cleared everything up to here. Move your class marker forward, or explore the map.",
        "EXP_STATE_WRITE_FAILED": "Your progress could not be saved just now; it will be retried.",
        "DIAG_NO_PREREQUISITE": "Nothing upstream to check — here's a hint.",
        "DIAG_PROBE_UNAVAILABLE": "No quick check is available for this one yet; here's a hint instead.",
        "DIAG_STATE_WRITE_FAILED": "Your progress could not be saved just now; it will be retried.",
        "PLATFORM_BUNDLE_FETCH_FAILED": "Could not refresh content; still using the installed version.",
        "PLATFORM_BUNDLE_INTEGRITY_FAILED": "Could not refresh content; still using the installed version.",
        "PLATFORM_STATE_UNREADABLE": "Earlier progress could not be read; it has been kept.",
        "PLATFORM_SNAPSHOT_REFUSED":
            "The map could not be loaded from this copy of the app; reinstall the app to fix it.",
        "VERIFY_CAS_UNAVAILABLE": "The checker could not start.",
        "VERIFY_PARSE_FAILED": "This step could not be read; please re-enter it.",
        "VERIFY_TIMEOUT": "This step could not be decided in time; the rest of the check stands.",
        "VERIFY_UNSUPPORTED": "Step checking is not available for this kind of problem; the answer is shown.",
    ]

    /// `nil` for any code absent from `userText` (internal/owner codes, or an unrecognized string).
    public static func text(for code: CoreError) -> String? {
        userText[code.rawValue]
    }
}
