import Foundation

/// Read/write/migrate `StudentState` at a caller-supplied `URL` (`docs/domains/platform.md` § W3,
/// arbiter-03 § Q-F item 2). `Core`, Foundation only (I14) — the caller resolves the Application
/// Support URL; this type never hardcodes or resolves a platform-specific path.
public enum StudentStateStore {
    /// The highest `schema_version` this `Core` build decodes (`contracts/data-model.md:149`:
    /// "`schema_version` is **2**"). A file naming a higher version is refused (AC4c), never guessed at.
    private static let currentSchemaVersion = 2

    public enum ReadResult: Equatable {
        case absent
        case loaded(StudentState, migratedFrom: Int?)
    }

    /// Reads `StudentState` from `url`, migrating a `schema_version: 1` document to 2 (identity) if
    /// needed. Throws `CoreError.platformStateUnreadable` for an undecodable file, a `schema_version`
    /// outside `1...2`, or a migration whose write back to `url` fails — `url`'s bytes are left
    /// untouched in every throwing case (platform W3: "the old file is kept ... nothing deleted").
    /// Returns `(result, events)`: `events == [.platformStateMigrated]` iff `result` is `.loaded` with a
    /// non-nil `migratedFrom`; otherwise `events == []` (a plain read, or a read of an absent file,
    /// writes nothing).
    public static func read(at url: URL) throws -> (result: ReadResult, events: [CoreEvent]) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (.absent, [])
        }

        let originalData: Data
        do {
            originalData = try Data(contentsOf: url)
        } catch {
            throw CoreError.platformStateUnreadable
        }

        let decoded: StudentState
        do {
            decoded = try CoreCoding.decoder.decode(StudentState.self, from: originalData)
        } catch {
            throw CoreError.platformStateUnreadable
        }

        guard decoded.schemaVersion >= 1, decoded.schemaVersion <= currentSchemaVersion else {
            throw CoreError.platformStateUnreadable
        }

        guard decoded.schemaVersion != currentSchemaVersion else {
            return (.loaded(decoded, migratedFrom: nil), [])
        }

        // decoded.schemaVersion == 1: identity migration. Every field is carried through unchanged
        // except schemaVersion — a valid v1 document already has every `remediated` key absent, per the
        // contract's own migration rule.
        let migrated = StudentState(
            schemaVersion: currentSchemaVersion,
            formatVersionSeen: decoded.formatVersionSeen,
            syllabi: decoded.syllabi,
            marker: decoded.marker,
            nodes: decoded.nodes,
            trail: decoded.trail,
            expeditionLog: decoded.expeditionLog,
            probeLog: decoded.probeLog,
            installDay: decoded.installDay,
            consentOn: decoded.consentOn)

        let preMigrationURL = url.appendingPathExtension("pre-migration")
        do {
            try originalData.write(to: preMigrationURL, options: .atomic)
        } catch {
            throw CoreError.platformStateUnreadable
        }

        do {
            _ = try write(migrated, to: url)
        } catch {
            // `url` is untouched (write-then-rename never truncates the target in place);
            // `preMigrationURL` is left in place — "keep the pre-migration file until the migrated one
            // is written" (arbiter-03 § Q-F). AC7.
            throw CoreError.platformStateUnreadable
        }

        try? FileManager.default.removeItem(at: preMigrationURL)
        return (.loaded(migrated, migratedFrom: 1), [.platformStateMigrated])
    }

    /// Atomic whole-document write through `CoreCoding.encoder`: encode, write to a hidden temp file
    /// beside `url`, then `FileManager.replaceItemAt` — a single OS-level rename that either fully
    /// replaces `url`'s content or leaves it untouched, never a partial write (AC5, AC6). Works
    /// identically whether or not a file already exists at `url` (`replaceItemAt` moves the temp file
    /// into place when the target is absent). Throws `CoreError.platformStateWriteFailed` on any
    /// failure. Returns `[.platformStateWritten]` on success.
    public static func write(_ state: StudentState, to url: URL) throws -> [CoreEvent] {
        do {
            let data = try CoreCoding.encoder.encode(state)
            let tempURL = url.deletingLastPathComponent()
                .appendingPathComponent(".\(url.lastPathComponent).tmp-\(UUID().uuidString)")
            try data.write(to: tempURL, options: .atomic)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL)
        } catch {
            throw CoreError.platformStateWriteFailed
        }
        return [.platformStateWritten]
    }
}
