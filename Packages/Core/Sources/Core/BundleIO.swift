import Foundation

/// The six content files of a bundle directory, decoded (`manifest.json` plus `regions.json`,
/// `nodes.json`, `edges.json`, `courses.json`, `landmarks.json`, `sources.json`).
///
/// `student-state.json` is not part of `ContentBundle` — it has no bundle-directory consumer until
/// a later EPIC; it ships as a standalone `Codable` type only in this task.
public struct ContentBundle {
    public let manifest: Manifest
    public let regions: RegionsFile
    public let nodes: NodesFile
    public let edges: EdgesFile
    public let courses: CoursesFile
    public let landmarks: LandmarksFile
    public let sources: SourcesFile
}

/// Deterministic bundle-directory read/write I/O.
///
/// `BundleIO` never computes or verifies `sha256` (`Manifest.files[].sha256` is a stored `String`
/// field only) — hash computation is a pipeline concern and hash verification at load is an App-side
/// concern (`docs/plans/epic-01-task-plan.md` planner note 2).
public enum BundleIO {
    /// Reads a bundle directory, checking manifest file-presence completeness before decoding any
    /// content file. Throws `CoreError.platformBundleIntegrityFailed` if a file named in
    /// `manifest.files` is absent from `directory` — no partial `ContentBundle` is ever constructed.
    public static func read(from directory: URL) throws -> ContentBundle {
        let manifestData = try Data(contentsOf: directory.appendingPathComponent("manifest.json"))
        let manifest = try CoreCoding.decoder.decode(Manifest.self, from: manifestData)

        for file in manifest.files {
            let path = directory.appendingPathComponent(file.name)
            guard FileManager.default.fileExists(atPath: path.path) else {
                throw CoreError.platformBundleIntegrityFailed
            }
        }

        let regions = try CoreCoding.decoder.decode(
            RegionsFile.self, from: Data(contentsOf: directory.appendingPathComponent("regions.json")))
        let nodes = try CoreCoding.decoder.decode(
            NodesFile.self, from: Data(contentsOf: directory.appendingPathComponent("nodes.json")))
        let edges = try CoreCoding.decoder.decode(
            EdgesFile.self, from: Data(contentsOf: directory.appendingPathComponent("edges.json")))
        let courses = try CoreCoding.decoder.decode(
            CoursesFile.self, from: Data(contentsOf: directory.appendingPathComponent("courses.json")))
        let landmarks = try CoreCoding.decoder.decode(
            LandmarksFile.self, from: Data(contentsOf: directory.appendingPathComponent("landmarks.json")))
        let sources = try CoreCoding.decoder.decode(
            SourcesFile.self, from: Data(contentsOf: directory.appendingPathComponent("sources.json")))

        return ContentBundle(
            manifest: manifest, regions: regions, nodes: nodes, edges: edges, courses: courses,
            landmarks: landmarks, sources: sources)
    }

    /// Writes a bundle directory. `.sortedKeys` output formatting makes the write deterministic:
    /// byte-identical output for byte-identical input across runs.
    public static func write(_ bundle: ContentBundle, to directory: URL) throws {
        try CoreCoding.encoder.encode(bundle.manifest).write(
            to: directory.appendingPathComponent("manifest.json"))
        try CoreCoding.encoder.encode(bundle.regions).write(
            to: directory.appendingPathComponent("regions.json"))
        try CoreCoding.encoder.encode(bundle.nodes).write(to: directory.appendingPathComponent("nodes.json"))
        try CoreCoding.encoder.encode(bundle.edges).write(to: directory.appendingPathComponent("edges.json"))
        try CoreCoding.encoder.encode(bundle.courses).write(
            to: directory.appendingPathComponent("courses.json"))
        try CoreCoding.encoder.encode(bundle.landmarks).write(
            to: directory.appendingPathComponent("landmarks.json"))
        try CoreCoding.encoder.encode(bundle.sources).write(
            to: directory.appendingPathComponent("sources.json"))
    }
}
