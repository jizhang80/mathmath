import Foundation

/// Read/write/migrate `StudentState` at a caller-supplied `URL` (`docs/domains/platform.md` § W3,
/// arbiter-03 § Q-F item 2). `Core`, Foundation only (I14) — the caller resolves the Application
/// Support URL; this type never hardcodes or resolves a platform-specific path.
public enum StudentStateStore {
    /// The highest `schema_version` this `Core` build decodes (`contracts/data-model.md:149`:
    /// "`schema_version` is **2**"). A file naming a higher version is refused (AC4c), never guessed at.
    private static let currentSchemaVersion = 2

    /// Every closed (`additionalProperties: false`) key set `contracts/schemas/student-state.schema.json`
    /// declares, mirrored here so `read(at:)` can reject a document carrying a key outside the closed
    /// schema even though `StudentState`'s synthesized `Decodable` conformance silently ignores unknown
    /// keys (`contracts/data-model.md:41-43`: "Every object schema sets `additionalProperties: false` —
    /// a new field is a versioned change"). `StudentStateStoreTests` asserts this table is byte-derived
    /// equal to the schema's own property sets so the two cannot drift.
    enum ClosedKeys {
        static let topLevel: Set<String> = [
            "schema_version", "format_version_seen", "syllabi", "marker", "nodes", "trail",
            "expedition_log", "probe_log", "install_day", "consent_on",
        ]
        static let marker: Set<String> = ["course_code", "unit_id", "past_last_unit"]
        static let nodeEntry: Set<String> = [
            "mastery", "correct_count", "last_probe", "next_due", "ladder_rung", "remediated",
        ]
        static let trail: Set<String> = ["segments"]
        static let trailSegment: Set<String> = ["kind", "course_code", "node_ids"]
        static let expeditionLogEntry: Set<String> = [
            "day", "item_count", "cleared", "blocked", "abandoned", "diagnosis_events",
        ]
        static let probeLogEntry: Set<String> = ["day", "node_id", "item_id", "correct", "retry"]
    }

    /// `true` iff `data` parses as a JSON object whose own keys, and every nested closed-schema
    /// object's keys (`marker`, each `nodes` entry, `trail`, each `trail.segments` entry, each
    /// `expedition_log`/`probe_log` entry), are each a subset of `ClosedKeys`' matching set. `false` for
    /// anything else, including non-object top-level JSON (decode already rejects malformed shapes;
    /// this only adds the "extra key" case decode alone does not catch).
    private static func hasOnlyClosedKeys(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        guard Set(object.keys).isSubset(of: ClosedKeys.topLevel) else { return false }

        if let marker = object["marker"] as? [String: Any] {
            guard Set(marker.keys).isSubset(of: ClosedKeys.marker) else { return false }
        }
        if let nodes = object["nodes"] as? [String: Any] {
            for case let node as [String: Any] in nodes.values {
                guard Set(node.keys).isSubset(of: ClosedKeys.nodeEntry) else { return false }
            }
        }
        if let trail = object["trail"] as? [String: Any] {
            guard Set(trail.keys).isSubset(of: ClosedKeys.trail) else { return false }
            if let segments = trail["segments"] as? [[String: Any]] {
                for segment in segments {
                    guard Set(segment.keys).isSubset(of: ClosedKeys.trailSegment) else { return false }
                }
            }
        }
        if let expeditionLog = object["expedition_log"] as? [[String: Any]] {
            for entry in expeditionLog {
                guard Set(entry.keys).isSubset(of: ClosedKeys.expeditionLogEntry) else { return false }
            }
        }
        if let probeLog = object["probe_log"] as? [[String: Any]] {
            for entry in probeLog {
                guard Set(entry.keys).isSubset(of: ClosedKeys.probeLogEntry) else { return false }
            }
        }
        return true
    }

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

        guard hasOnlyClosedKeys(originalData) else {
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
