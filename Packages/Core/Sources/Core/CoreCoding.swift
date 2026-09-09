import Foundation

/// The one JSON coder configuration for the bundle wire format and `student-state.json`.
///
/// `contracts/data-model.md` defines one shape set that "every bundle file, the student state and
/// `Core`'s `Codable` types share", so there is one key strategy: JSON keys are snake_case, Swift
/// properties are camelCase, and Foundation converts between them. No `Model/` type declares an
/// explicit `CodingKeys` — `.convertFromSnakeCase` rewrites the incoming key before it is matched
/// against a `CodingKey` raw value, so the two mechanisms cannot be combined.
public enum CoreCoding {
    /// A fresh decoder per access: `JSONDecoder` is a non-`Sendable` class, so a shared `static let`
    /// would not compile under Swift 6 strict concurrency.
    public static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    /// `.sortedKeys` is what makes `BundleIO.write` deterministic — byte-identical output for
    /// byte-identical input across runs. It is harmless for every other consumer because every
    /// comparison in this task's tests is structural (key order excluded).
    public static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
