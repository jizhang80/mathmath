import Foundation
import Testing

@testable import Core

/// Companion suite for `PropertyGen` (task 02.4, AC8). AC8 has no dedicated `T`-case in the task's own
/// § 5 test plan despite being an independently verifiable acceptance criterion — this suite closes that
/// gap: "calling the same function with the same `SeededGenerator` seed and the same call sequence
/// produces byte-identical output across two separate test runs."
///
/// Every `MasteryTransitionsTests` property test already *depends on* this determinism implicitly (a
/// fixed seed like `42`/`7`/`99` is assumed reproducible), but none of them isolates and proves it as its
/// own property — a `PropertyGen` regression that silently reads extra entropy (e.g. a stray
/// `Int.random(in:)` without `using:`) would still let those tests pass on a given run while breaking
/// AC8's cross-run reproducibility guarantee.
@Suite("PropertyGen")
struct PropertyGenTests {
    // AC8: the same seed + the same call sequence produces byte-identical output, across two
    // independently constructed `SeededGenerator`s (simulating "two separate test runs").
    @Test("same seed and call sequence produce byte-identical output across independent generators")
    func sameSeedProducesIdenticalOutput() {
        func runSequence(seed: UInt64) -> [String] {
            var gen = SeededGenerator(seed: seed)
            var trace: [String] = []
            for _ in 0..<25 {
                let day = PropertyGen.calendarDay(&gen)
                let mastery = PropertyGen.mastery(&gen)
                let element = PropertyGen.element(&gen, from: ["a", "b", "c"])
                let bool = PropertyGen.bool(&gen, trueWeight: 0.5)
                let int = PropertyGen.int(&gen, in: 0...1000)
                let node = PropertyGen.nodeState(&gen, today: day)
                trace.append("\(day.iso)|\(mastery)|\(element)|\(bool)|\(int)|\(node)")
            }
            return trace
        }

        let firstRun = runSequence(seed: 123_456)
        let secondRun = runSequence(seed: 123_456)
        #expect(firstRun == secondRun)
        #expect(!firstRun.isEmpty)
    }

    // AC8 sibling: a different seed must (with overwhelming probability over this many draws) diverge —
    // otherwise the "same output" assertion above would be vacuously true for any two runs regardless of
    // seed, which would not actually prove determinism is seed-driven.
    @Test("a different seed produces different output from the same call sequence")
    func differentSeedProducesDifferentOutput() {
        func runSequence(seed: UInt64) -> [Int] {
            var gen = SeededGenerator(seed: seed)
            return (0..<25).map { _ in PropertyGen.int(&gen, in: 0...1_000_000) }
        }
        let fromSeedOne = runSequence(seed: 1)
        let fromSeedTwo = runSequence(seed: 2)
        #expect(fromSeedOne != fromSeedTwo)
    }

    // AC8 sibling: `nodesMap` (built from repeated `nodeState` calls) is equally deterministic and
    // order-independent on its key set — a `Dictionary`'s literal construction order must not affect
    // the resulting content.
    @Test("nodesMap produces byte-identical output for the same seed and id list")
    func nodesMapIsDeterministic() {
        let ids = ["alpha", "beta", "gamma"]
        guard let today = CalendarDay(iso: "2026-06-15") else {
            Issue.record("2026-06-15 must be a valid CalendarDay")
            return
        }
        var firstGen = SeededGenerator(seed: 777)
        var secondGen = SeededGenerator(seed: 777)
        let firstMap = PropertyGen.nodesMap(&firstGen, nodeIds: ids, today: today)
        let secondMap = PropertyGen.nodesMap(&secondGen, nodeIds: ids, today: today)
        #expect(firstMap == secondMap)
    }

    // T5 negative control (C2): prove the determinism guard is load-bearing by reconstructing a
    // generator call that reads an extra, unseeded source of randomness (`Int.random(in:)` without
    // `using:`, i.e. the system RNG) interleaved with the seeded stream, and showing the "same seed ->
    // same output" property reds on it.
    @Test("interleaving an unseeded system-random call breaks the determinism guard (negative control)")
    func unseededInterleaveBreaksDeterminism() {
        func runSequenceWithSystemEntropy(seed: UInt64) -> [Int] {
            var gen = SeededGenerator(seed: seed)
            return (0..<10).map { _ in
                let seeded = PropertyGen.int(&gen, in: 0...1000)
                let unseeded = Int.random(in: 0...1_000_000_000)  // system entropy, not `using: &gen`
                return seeded &+ unseeded
            }
        }
        let firstRun = runSequenceWithSystemEntropy(seed: 55)
        let secondRun = runSequenceWithSystemEntropy(seed: 55)
        #expect(
            firstRun != secondRun,
            "the reconstructed unseeded-entropy defect unexpectedly produced identical output twice")
    }
}
