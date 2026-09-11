import Foundation

/// Presentation-only state for the Door B render layer (I14): the in-progress numeric keypad string, and the
/// resolved text for a "Start another" failure (`EXP_NO_FRINGE`, via `CoreErrorText.text(for:)` — never
/// authored here). Neither field derives a fog/mastery/correctness fact.
struct DoorBViewState: Equatable {
    var keypadInput: String = ""
    var startAnotherErrorText: String?
}
