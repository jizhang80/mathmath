import Core
import Foundation

/// `core-cli layout <bundle-dir>`. Rewrites `nodes.json` in place with a computed `position` for every
/// node; touches no other bundle file. Prints nothing to stdout on success.
///
/// `Node`/`NodesFile` (`Packages/Core/Sources/Core/Model/Nodes.swift`) expose no public initializer —
/// only the compiler-synthesized `Decodable.init(from:)` is public, so a cross-module `Node(...)` call
/// does not compile. Rewriting the file at the `JSONSerialization` level (patch the `position` key of
/// each node object, leave every other key untouched) avoids reconstructing `Node` values while still
/// using only `Core`'s computed positions — `Core` still owns the layout computation (D42/I14), this
/// file only rewrites the wire JSON with that computation's result.
enum LayoutCommand {
    static func run(arguments: [String]) {
        guard arguments.count == 1 else { Usage.printAndExit() }
        let bundleDir = URL(fileURLWithPath: arguments[0], isDirectory: true)

        do {
            let bundle = try BundleIO.read(from: bundleDir)
            var rng = SeededGenerator(seed: LayoutConfig.defaultSeed)
            let positions = try LayoutEngine.layout(
                nodes: bundle.nodes.nodes, regions: bundle.regions.regions, rng: &rng
            )

            let nodesURL = bundleDir.appendingPathComponent("nodes.json")
            let rawData = try Data(contentsOf: nodesURL)
            guard var root = try JSONSerialization.jsonObject(with: rawData) as? [String: Any],
                var nodeObjects = root["nodes"] as? [[String: Any]]
            else {
                throw CoreError.mapLayoutMissing
            }

            for index in nodeObjects.indices {
                guard let id = nodeObjects[index]["id"] as? String, let position = positions[id]
                else {
                    throw CoreError.mapLayoutMissing
                }
                nodeObjects[index]["position"] = ["x": position.x, "y": position.y]
            }
            root["nodes"] = nodeObjects

            let data = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
            try data.write(to: nodesURL)
        } catch let error as CoreError {
            Usage.fail(error)
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(3)
        }
        exit(0)
    }
}
