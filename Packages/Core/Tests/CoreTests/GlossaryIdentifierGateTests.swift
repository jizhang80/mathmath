import Foundation
import Testing

/// Glossary identifier gate (`contracts/domain-glossary.md` header, v1.0.2): every Swift identifier under
/// `Packages/Core/Sources`, `Packages/Rendering/Sources` and `App/Sources` is checked against every
/// *Banned:* list in the glossary. The lists are parsed from the contract at test time and never restated
/// here, so a banned term the glossary gains is scanned from the next run on.
///
/// Bans are sense-scoped, so a word-level grep cannot be the gate: the glossary itself defines **Backtrack
/// level**, **Position indicator**, **Official link**, **Strand** and a probe **fail**, and platform APIs
/// (`appendingPathComponent`, SwiftUI `Link`) carry banned words too. Every legitimate use is an explicit
/// `allowlist` entry naming the exact identifiers and citing the glossary sense that makes them legitimate.
/// An entry no longer matched by the scan fails the gate, so the allowlist cannot rot. "attempt" has no entry:
/// it is banned in `Core` identifiers in any sense (`tasks/arbitration/arbiter-03-audit-f1-attempt.md`).
///
/// The gate scans identifiers only: comments and string-literal text are blanked first, while the code inside
/// a string interpolation is scanned. Student copy and comments stay covered by the single-term guards this
/// gate does not subsume (`CoreGlossaryAttemptGuardTests`, which also bans the stem "FailedProbe";
/// `MapLaunchGapTests`, `MapPanelsPickersHandOffStructuralTests` and `AppShellStructuralTests`, which scan
/// on-screen strings). The Python pipeline and `data/` JSON keys are not scanned: `docs/DEFERRED.md` D-19.
enum GlossaryIdentifierGate {
    /// One quoted phrase from a glossary *Banned:* clause, with the bold term its entry defines.
    struct BannedTerm: Hashable, Sendable {
        let phrase: String
        let listedUnder: String
        /// The phrase as lower-case identifier words, e.g. "skill tree" → ["skill", "tree"].
        var words: [String] { phrase.lowercased().split(separator: " ").map(String.init) }
    }

    /// One *Banned:* clause: the text after the marker, and the bold term its entry line starts with.
    struct Clause: Sendable {
        let listedUnder: String
        let text: String
    }

    /// A legitimate sense of one banned term: the exact identifiers that use it, and why.
    struct Allowance: Sendable {
        let term: String
        let identifiers: Set<String>
        let sense: String
    }

    struct Hit: Hashable, Sendable {
        let file: String
        let line: Int
        let identifier: String
        let term: String
    }

    static let marker = "*Banned:*"

    static func clauses(in glossary: String) -> [Clause] {
        glossary.split(separator: "\n").compactMap { line in
            guard let range = line.range(of: marker) else { return nil }
            let head = line.split(separator: "**", omittingEmptySubsequences: false)
            let listedUnder = head.count > 2 ? String(head[1]) : "?"
            return Clause(listedUnder: listedUnder, text: String(line[range.upperBound...]))
        }
    }

    /// Straight-double-quoted phrases in a clause; qualifiers outside the quotes ("(as a state)",
    /// "for an item") stay out of the phrase — the allowlist carries the sense.
    static func phrases(in clause: Clause) -> [String] {
        let parts = clause.text.split(separator: "\"", omittingEmptySubsequences: false)
        return stride(from: 1, to: parts.count - 1, by: 2).map { String(parts[$0]) }
    }

    static func bannedTerms(in glossary: String) -> [BannedTerm] {
        clauses(in: glossary).flatMap { clause in
            phrases(in: clause).map { BannedTerm(phrase: $0, listedUnder: clause.listedUnder) }
        }
    }

    /// Clauses the parser cannot read completely: no straight-quoted phrase, an unpaired quote, a curly quote,
    /// or a phrase with no identifier word. A banned term written in such a clause would be neither scanned nor
    /// allowlisted, so each one fails the drift guard.
    static func unreadableClauses(in glossary: String) -> [String] {
        clauses(in: glossary).compactMap { clause in
            let quotes = clause.text.filter { $0 == "\"" }.count
            let phrases = phrases(in: clause)
            let readable =
                !phrases.isEmpty && quotes % 2 == 0 && !clause.text.contains("\u{201C}")
                && !clause.text.contains("\u{201D}")
                && phrases.allSatisfy { !BannedTerm(phrase: $0, listedUnder: "").words.isEmpty }
            return readable ? nil : "\(clause.listedUnder): \(clause.text)"
        }
    }

    // MARK: - Swift identifiers

    /// `source` with comments and string-literal text blanked (line breaks kept, so line numbers hold) and the
    /// code inside `\( … )` interpolations kept. Handles nested block comments, `"""` and `#"…"#` literals.
    static func codeOnly(_ source: String) -> String {
        var lexer = Lexer(bytes: Array(source.utf8))
        lexer.code(insideInterpolation: false)
        return String(decoding: lexer.out, as: UTF8.self)
    }

    private struct Lexer {
        let bytes: [UInt8]
        var index = 0
        var out: [UInt8] = []

        static let slash = UInt8(ascii: "/")
        static let star = UInt8(ascii: "*")
        static let hash = UInt8(ascii: "#")
        static let quote = UInt8(ascii: "\"")
        static let backslash = UInt8(ascii: "\\")
        static let openParen = UInt8(ascii: "(")
        static let closeParen = UInt8(ascii: ")")
        static let newline = UInt8(ascii: "\n")
        static let space = UInt8(ascii: " ")

        init(bytes: [UInt8]) { self.bytes = bytes }

        func peek(_ offset: Int) -> UInt8? {
            index + offset < bytes.count ? bytes[index + offset] : nil
        }

        mutating func blank() {
            out.append(bytes[index] == Self.newline ? Self.newline : Self.space)
            index += 1
        }

        /// Copies code until the end of input, or — inside an interpolation — until its closing paren.
        mutating func code(insideInterpolation: Bool) {
            var depth = 0
            while index < bytes.count {
                let byte = bytes[index]
                if byte == Self.slash, peek(1) == Self.slash {
                    while index < bytes.count, bytes[index] != Self.newline { index += 1 }
                } else if byte == Self.slash, peek(1) == Self.star {
                    blockComment()
                } else if let hashes = stringOpener() {
                    string(hashes: hashes)
                } else {
                    if insideInterpolation, byte == Self.openParen { depth += 1 }
                    if insideInterpolation, byte == Self.closeParen {
                        if depth == 0 {
                            index += 1
                            return
                        }
                        depth -= 1
                    }
                    out.append(byte)
                    index += 1
                }
            }
        }

        /// The number of `#` before a `"` at `index`, or nil when no string literal opens here.
        func stringOpener() -> Int? {
            var scanIndex = index
            while scanIndex < bytes.count, bytes[scanIndex] == Self.hash { scanIndex += 1 }
            return scanIndex < bytes.count && bytes[scanIndex] == Self.quote ? scanIndex - index : nil
        }

        mutating func blockComment() {
            var depth = 0
            while index < bytes.count {
                if bytes[index] == Self.slash, peek(1) == Self.star {
                    depth += 1
                    index += 2
                } else if bytes[index] == Self.star, peek(1) == Self.slash {
                    depth -= 1
                    index += 2
                    if depth == 0 { return }
                } else {
                    blank()
                }
            }
        }

        mutating func string(hashes: Int) {
            index += hashes
            let delimiter = peek(1) == Self.quote && peek(2) == Self.quote ? 3 : 1
            index += delimiter
            out.append(Self.space)
            while index < bytes.count {
                if closes(delimiter: delimiter, hashes: hashes) {
                    index += delimiter + hashes
                    return
                }
                if bytes[index] == Self.backslash {
                    var after = index + 1
                    while after < bytes.count, after - index - 1 < hashes, bytes[after] == Self.hash {
                        after += 1
                    }
                    if after - index - 1 == hashes, after < bytes.count {
                        index = after
                        if bytes[index] == Self.openParen {
                            index += 1
                            out.append(Self.space)
                            code(insideInterpolation: true)
                            out.append(Self.space)
                        } else {
                            blank()  // the escaped character, e.g. \" or \#n
                        }
                        continue
                    }
                }
                blank()
            }
        }

        func closes(delimiter: Int, hashes: Int) -> Bool {
            guard index + delimiter + hashes <= bytes.count else { return false }
            for offset in 0..<delimiter where bytes[index + offset] != Self.quote { return false }
            for offset in 0..<hashes where bytes[index + delimiter + offset] != Self.hash { return false }
            return true
        }
    }

    /// Identifiers in code-only text, with 1-based line numbers. Attribute and directive names after `@`/`#`
    /// (`@available`, `@unknown default`, `#available`) are Swift syntax, not identifiers, and are skipped.
    static func identifiers(inCode code: String) -> [(line: Int, name: String)] {
        var result: [(line: Int, name: String)] = []
        var line = 1
        var current = ""
        var skip = false
        var previous: Character = " "
        for character in code + " " {
            let isIdentifierCharacter =
                character == "_" || (character.isASCII && character.isLetter)
                || (character.isASCII && character.isNumber)
            if isIdentifierCharacter {
                if current.isEmpty { skip = character.isNumber || previous == "@" || previous == "#" }
                current.append(character)
            } else {
                if !current.isEmpty, !skip { result.append((line, current)) }
                current = ""
                if character == "\n" { line += 1 }
            }
            previous = character
        }
        return result
    }

    /// Lower-case words of an identifier, split at `_`, digit runs and camel-case humps (acronym-aware:
    /// `URLSession` → ["url", "session"]).
    static func words(_ identifier: String) -> [String] {
        var words: [String] = []
        var current = ""
        let characters = Array(identifier)
        for (offset, character) in characters.enumerated() {
            if character == "_" {
                if !current.isEmpty { words.append(current) }
                current = ""
                continue
            }
            if let last = current.last {
                let next = offset + 1 < characters.count ? characters[offset + 1] : nil
                let boundary =
                    character.isNumber != last.isNumber
                    || (character.isUppercase && last.isLowercase)
                    || (character.isUppercase && last.isUppercase && next?.isLowercase == true)
                if boundary {
                    words.append(current)
                    current = ""
                }
            }
            current.append(character)
        }
        if !current.isEmpty { words.append(current) }
        return words.map { $0.lowercased() }
    }

    static func inflections(of word: String) -> Set<String> {
        var forms: Set<String> = [word, word + "s", word + "es", word + "ed", word + "d", word + "ing"]
        if word.hasSuffix("e") {
            forms.insert(String(word.dropLast()) + "ing")
            forms.insert(String(word.dropLast()) + "ed")
        }
        return forms
    }

    /// True when the term's words occur contiguously in the identifier's words; the last may be inflected.
    static func identifier(_ identifierWords: [String], uses term: BannedTerm) -> Bool {
        let termWords = term.words
        guard let lastWord = termWords.last, identifierWords.count >= termWords.count else { return false }
        let lastForms = inflections(of: lastWord)
        for start in 0...(identifierWords.count - termWords.count) {
            let end = start + termWords.count - 1
            if Array(identifierWords[start..<end]) == Array(termWords.dropLast()),
                lastForms.contains(identifierWords[end])
            {
                return true
            }
        }
        return false
    }

    /// Every banned-term use in one source file, allowlisted or not.
    static func hits(inSource source: String, file: String, terms: [BannedTerm]) -> [Hit] {
        identifiers(inCode: codeOnly(source)).flatMap { token in
            let identifierWords = words(token.name)
            return terms.filter { identifier(identifierWords, uses: $0) }.map {
                Hit(file: file, line: token.line, identifier: token.name, term: $0.phrase)
            }
        }
    }

    static func isAllowed(_ hit: Hit, by allowlist: [Allowance]) -> Bool {
        allowlist.contains { $0.term == hit.term && $0.identifiers.contains(hit.identifier) }
    }

    // MARK: - Allowlist: each entry cites the glossary sense that makes the identifiers legitimate

    static let allowlist: [Allowance] = [
        Allowance(
            term: "fail",
            identifiers: [
                "graphL0Failed", "platformBundleIntegrityFailed", "expStateWriteFailed",
                "diagStateWriteFailed",
                "platformStateWriteFailed", "telemetryBatchFailed", "fail",
            ],
            sense:
                "An operation that failed: `CoreError` cases mirroring `contracts/error-codes.json` `*_FAILED` "
                + "codes, and `core-cli`'s `Usage.fail` exit. Never an item; the ban is \"fail\" for an item."
        ),
        Allowance(
            term: "fail",
            identifiers: ["downstreamFailGivenUpstreamFail"],
            sense:
                "Probe outcome **fail** (glossary Probe: pass / fail / declined); `data-model.md` edge key."),
        Allowance(
            term: "unknown",
            identifiers: ["mapRegionUnknown", "hasUnknownNode", "unknown"],
            sense:
                "Not a mastery state (the ban is \"unknown\" as a state): the `MAP_REGION_UNKNOWN` error code, an "
                + "L0 check for ids absent from the graph, and the `solve` answer spec's `unknown` symbol key "
                + "(`data-model.md`)."),
        Allowance(
            term: "path",
            identifiers: [
                "appendingPathComponent", "appendingPathExtension", "deletingLastPathComponent",
                "lastPathComponent", "atPath",
                "fileURLWithPath", "resourcePath", "path",
            ],
            sense:
                "Foundation file-system paths (`URL.path`, `FileManager`), and a local SwiftUI `Path`. Not a Trail."
        ),
        Allowance(
            term: "path",
            identifiers: ["Path"],
            sense: "SwiftUI's `Path` shape used to draw the map canvas. Not a Trail."),
        Allowance(
            term: "position",
            identifiers: [
                "position", "positions", "initialPosition", "otherPosition", "memberPositions",
                "checkPositionInPolygon",
            ],
            sense:
                "Glossary Layout / coordinates (\"node positions precomputed by `core-cli`\"), and a node's "
                + "ordinal within a trail segment. Never the Course-progress marker."),
        Allowance(
            term: "position",
            identifiers: ["positionIndicatorNodeId", "drawPositionIndicator"],
            sense: "Glossary **Position indicator** (display only)."),
        Allowance(
            term: "link",
            identifiers: ["ExpectationCodeLink", "expectationCodeLinks", "links", "link"],
            sense: "Glossary **Official link**: the outbound link to the Ministry page (I6). Not an Edge."),
        Allowance(
            term: "link",
            identifiers: ["Link"],
            sense:
                "SwiftUI's `Link` view rendering an Official link or a landmark `source_url` (I15). Not an Edge."
        ),
        Allowance(
            term: "level",
            identifiers: [
                "level", "levelBudget", "levelReached", "levelResults", "newLevelContext",
                "decideFurtherLevel",
                "acceptFurtherLevel", "FurtherLevelOffer", "furtherLevelOffer",
                "DoorAFurtherLevelOfferContent",
                "furtherLevelQuestion", "DiagnosisLevelDecision", "onFurtherLevelDecision",
            ],
            sense: "Glossary **Backtrack level**: distance from the origin node (≤ 2, I4). Not an Expedition."
        ),
        Allowance(
            term: "level",
            identifiers: ["fogLevel"],
            sense: "Glossary **Fog**: the rendering degree of a node's mastery state. Not an Expedition."),
        Allowance(
            term: "level",
            identifiers: ["topLevel"],
            sense: "The top level of the student-state JSON object (key nesting). Not an Expedition."),
        Allowance(
            term: "question",
            identifiers: ["question", "furtherLevelQuestion"],
            sense:
                "The yes/no offer Door A puts to the student (\"want to look one step further upstream?\"), "
                + "not an Item."),
        Allowance(
            term: "available",
            identifiers: ["available"],
            sense:
                "The ready set of a topological sort within a unit (I8 trail well-formedness). Not the Fringe."
        ),
        Allowance(
            term: "strand",
            identifiers: ["strand", "strands", "Strand"],
            sense: "Glossary **Strand**: a Ministry division of a course (Spine). Not a Region."),
        Allowance(
            term: "example",
            identifiers: [
                "WorkedExample", "workedExample", "workedExamples", "BundleWorkedExample", "example",
            ],
            sense: "Glossary **Learning object** WorkedExample. Not a Landmark."),
        Allowance(
            term: "application",
            identifiers: ["applicationSupportDirectory"],
            sense: "Foundation's `FileManager` directory for the student-state file. Not a Landmark."),
        Allowance(
            term: "zone",
            identifiers: ["timeZone"],
            sense: "Foundation's `TimeZone` on a date formatter. Not a Region."),
    ]
}

@Suite("Glossary identifier gate — banned synonyms in Swift identifiers (domain-glossary v1.0.2)")
struct GlossaryIdentifierGateTests {
    private typealias Gate = GlossaryIdentifierGate

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // Core (package root)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
    }

    private static let scannedRoots = ["Packages/Core/Sources", "Packages/Rendering/Sources", "App/Sources"]

    private static func glossary() throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent("contracts/domain-glossary.md"), encoding: .utf8)
    }

    /// Every banned-term hit across the scanned roots, and the number of `.swift` files per root.
    private static func scan(terms: [Gate.BannedTerm]) throws -> (hits: [Gate.Hit], files: [String: Int]) {
        var hits: [Gate.Hit] = []
        var files: [String: Int] = [:]
        for root in scannedRoots {
            let rootURL = repoRoot.appendingPathComponent(root)
            let enumerator = try #require(
                FileManager.default.enumerator(at: rootURL, includingPropertiesForKeys: nil))
            files[root] = 0
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                files[root, default: 0] += 1
                let relative = root + url.path.dropFirst(rootURL.path.count)
                hits += try Gate.hits(
                    inSource: String(contentsOf: url, encoding: .utf8), file: relative, terms: terms)
            }
        }
        return (hits, files)
    }

    // MARK: - Drift guard

    @Test("drift guard: every glossary *Banned:* clause parses completely, so every banned term is scanned")
    func glossaryBannedListsParseCompletely() throws {
        let glossary = try Self.glossary()
        let clauses = Gate.clauses(in: glossary)
        let rawMarkers = glossary.components(separatedBy: Gate.marker).count - 1
        #expect(!clauses.isEmpty, "instrument broken: no *Banned:* clause parsed from the glossary")
        #expect(clauses.count == rawMarkers, "a *Banned:* marker was not parsed as a clause")
        #expect(
            Gate.unreadableClauses(in: glossary).isEmpty,
            "unreadable clauses: \(Gate.unreadableClauses(in: glossary))")
        let phrases = Set(Gate.bannedTerms(in: glossary).map(\.phrase))
        let unknownAllowanceTerms = Set(Gate.allowlist.map(\.term)).subtracting(phrases)
        #expect(
            unknownAllowanceTerms.isEmpty,
            "allowlist names terms the glossary does not ban: \(unknownAllowanceTerms)")
        #expect(Gate.allowlist.allSatisfy { !$0.sense.isEmpty && !$0.identifiers.isEmpty })
    }

    // MARK: - The gate

    @Test("no Swift identifier uses a banned glossary term outside a documented allowlisted sense")
    func noUnallowlistedBannedIdentifier() throws {
        let terms = try Gate.bannedTerms(in: Self.glossary())
        let (hits, files) = try Self.scan(terms: terms)
        for (root, count) in files {
            #expect(count > 0, "instrument broken: no .swift file under \(root)")
        }
        let violations = hits.filter { !Gate.isAllowed($0, by: Gate.allowlist) }
            .map { "\($0.file):\($0.line) `\($0.identifier)` uses banned \"\($0.term)\"" }
        #expect(
            violations.isEmpty, "banned glossary terms in identifiers:\n\(violations.joined(separator: "\n"))"
        )
    }

    @Test("the allowlist has no stale entry: every allowlisted identifier still occurs with its term")
    func allowlistHasNoStaleEntry() throws {
        let terms = try Gate.bannedTerms(in: Self.glossary())
        let used = try Set(Self.scan(terms: terms).hits.map { "\($0.term)|\($0.identifier)" })
        let stale = Gate.allowlist.flatMap { allowance in
            allowance.identifiers.map { "\(allowance.term)|\($0)" }
        }.filter { !used.contains($0) }
        #expect(stale.isEmpty, "allowlist entries matched by no identifier (remove them): \(stale.sorted())")
    }

    // MARK: - Negative controls (C2)

    private static let fixtureTerms = [
        "attempt", "fail", "frontier", "session", "user id", "skill tree", "cursor", "position", "quiz",
        "quest",
        "level", "available", "unknown", "link",
    ].map { Gate.BannedTerm(phrase: $0, listedUnder: "fixture") }

    private static func violations(in source: String) -> Set<String> {
        Set(
            Gate.hits(inSource: source, file: "fixture.swift", terms: fixtureTerms)
                .filter { !Gate.isAllowed($0, by: Gate.allowlist) }
                .map { "\($0.identifier)|\($0.term)" })
    }

    @Test(
        "negative control: planted banned identifiers are caught, including inflections and multi-word terms")
    func plantedIdentifiersAreCaught() {
        let found = Self.violations(
            in: """
                public struct FailedProbeAttempt: Equatable {}
                var frontierNodes: [String] = []
                struct MapSession { let userId: Int }
                func drawSkillTree(positionCursor: Int) {}
                let label = "\\(quizCount) items"
                """)
        #expect(found.contains("FailedProbeAttempt|attempt"))
        #expect(found.contains("FailedProbeAttempt|fail"))
        #expect(found.contains("frontierNodes|frontier"))
        #expect(found.contains("MapSession|session"))
        #expect(found.contains("userId|user id"))
        #expect(found.contains("drawSkillTree|skill tree"))
        #expect(found.contains("positionCursor|cursor"))
        #expect(
            found.contains("positionCursor|position"), "the allowlist names exact identifiers, not a word")
        #expect(found.contains("quizCount|quiz"), "code inside a string interpolation is scanned")
    }

    @Test("negative control: comments, string text and Swift attributes are not identifiers")
    func commentsStringsAndAttributesAreNotScanned() {
        let found = Self.violations(
            in: """
                // a session, a quiz
                /* quest /* nested attempt */ frontier */
                /// available level
                let copy = "Start a new session, not a quest"
                let raw = #"a "quiz" \\(frontier)"#
                let block = \"""
                    an attempt, a "cursor"
                    \"""
                @available(iOS 18, *)
                func check() { if #available(iOS 26, *) {}; switch x { @unknown default: break } }
                """)
        #expect(found.isEmpty, "unexpected hits: \(found)")
    }

    @Test("negative control: an allowlisted sense does not leak to a different term or identifier")
    func allowlistIsTermAndIdentifierScoped() {
        #expect(Self.violations(in: "let level = 1; let fogLevel = 0; var available = Set<String>()").isEmpty)
        let found = Self.violations(in: "let expeditionLevel = 1; let availableNodes = 0; let linkEdge = 0")
        #expect(found == ["expeditionLevel|level", "availableNodes|available", "linkEdge|link"])
    }

    @Test(
        "negative control: a banned term added to a glossary is scanned; an unreadable clause fails the drift guard"
    )
    func glossaryDriftIsCaught() {
        let grown =
            "- **Node** — one concept. *Banned:* \"topic\".\n- **Widget** — new. *Banned:* \"gizmo\".\n"
        let terms = Gate.bannedTerms(in: grown)
        #expect(terms.map(\.phrase) == ["topic", "gizmo"])
        #expect(terms.last?.listedUnder == "Widget")
        #expect(
            Gate.hits(inSource: "let gizmoCount = 0", file: "f.swift", terms: terms).map(\.term) == ["gizmo"])
        #expect(Gate.unreadableClauses(in: grown).isEmpty)
        #expect(Gate.unreadableClauses(in: "- **Widget** — new. *Banned:* \u{201C}gizmo\u{201D}.").count == 1)
        #expect(Gate.unreadableClauses(in: "- **Widget** — new. *Banned:* gizmo.").count == 1)
        #expect(Gate.unreadableClauses(in: "- **Widget** — new. *Banned:* \"gizmo.").count == 1)
    }
}
