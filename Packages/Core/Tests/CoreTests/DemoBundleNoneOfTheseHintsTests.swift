import Foundation
import Testing

@testable import Core

/// Companion test for task 04.1b (`tasks/epic-04-task-01b-data-demo-none-of-these-hints.md`, AC1/AC2/AC6):
/// every node in `data/demo` carries a `hint_tree["none-of-these"]` entry of exactly three non-empty tiers,
/// whose tier 1 never repeats a sibling key's tier 1 on that same node.
@Suite("Demo bundle hint_tree[\"none-of-these\"]")
struct DemoBundleNoneOfTheseHintsTests {
    private static var testsDir: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    private static var demoBundleDir: URL {
        testsDir
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // package root (Packages/Core)
            .deletingLastPathComponent()  // Packages
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent("data/demo")
    }

    private static func loadDemoBundle() throws -> ContentBundle {
        try BundleIO.read(from: demoBundleDir)
    }

    @Test("every data/demo node has a 3-tier none-of-these hint distinct from its sibling keys' tier 1")
    func noneOfTheseHintsPresentAndDistinct() throws {
        let bundle = try Self.loadDemoBundle()
        #expect(bundle.nodes.nodes.count > 0)

        for node in bundle.nodes.nodes {
            let noneOfThese = node.hintTree["none-of-these"]
            let tiers = try #require(noneOfThese, "\(node.id) is missing hint_tree[\"none-of-these\"]")
            #expect(tiers.count == 3, "\(node.id) has \(tiers.count) none-of-these tiers, expected 3")
            #expect(
                tiers.allSatisfy { !$0.isEmpty },
                "\(node.id) has an empty none-of-these tier")

            for (key, siblingTiers) in node.hintTree where key != "none-of-these" {
                #expect(
                    siblingTiers.first != tiers.first,
                    "\(node.id): none-of-these tier 1 duplicates sibling key \(key)'s tier 1")
            }
        }
    }
}
