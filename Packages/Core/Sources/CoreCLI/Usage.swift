import Core
import Foundation

/// Shared usage text and the two exit paths every subcommand uses.
enum Usage {
    static let text = "usage: core-cli version | validate <bundle-dir> | layout <bundle-dir>\n"

    /// Preserves the existing convention (`main.swift`, read in this run): usage text to stderr, exit 2.
    static func printAndExit() -> Never {
        FileHandle.standardError.write(Data(text.utf8))
        exit(2)
    }

    /// A `CoreError` was thrown before any report/rewrite could complete (bundle unreadable, a
    /// `format_version` major mismatch, or — `layout` only — a region/layout precondition failure).
    /// Prints the raw registry code (`CoreError.rawValue`) as one line on stderr; exits 3.
    static func fail(_ error: CoreError) -> Never {
        FileHandle.standardError.write(Data((error.rawValue + "\n").utf8))
        exit(3)
    }
}
