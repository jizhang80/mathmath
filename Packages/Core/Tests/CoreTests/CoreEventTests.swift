import Foundation
import Testing

@testable import Core

/// Companion suite for `CoreEvent` (task 02.4, AC7). No dedicated test exists for this file in the
/// implementer's smoke coverage — `MasteryTransitionsTests` only ever constructs two of the 41 cases
/// (`.expeditionNodeCleared`, `.diagnosisNodeBlocked`) as a side effect of exercising
/// `MasteryTransitions`, so the other 39 raw values, the exact case count, and the exact left-to-right
/// order against `contracts/interaction-contract.md` § 5 were never independently verified.
@Suite("CoreEvent")
struct CoreEventTests {
    /// The exact § 5 notification-name list, left to right, byte-compared against
    /// `contracts/interaction-contract.md` § 5 (quoted verbatim in the task spec § 3).
    private static let contractNames: [String] = [
        "map.opened",
        "map.node_opened",
        "map.region_opened",
        "map.landmark_opened",
        "map.marker_moved",
        "map.check_here_requested",
        "map.include_requested",
        "map.unit_expedition_requested",
        "expedition.started",
        "expedition.item_answered",
        "expedition.diagnosis_requested",
        "expedition.node_cleared",
        "expedition.node_due",
        "expedition.marker_changed",
        "expedition.trail_generated",
        "expedition.completed",
        "diagnosis.opened",
        "diagnosis.hypothesis_formed",
        "diagnosis.probe_completed",
        "diagnosis.node_blocked",
        "diagnosis.capped",
        "diagnosis.remediation_shown",
        "diagnosis.returned",
        "platform.launched",
        "platform.content_updated",
        "platform.state_migrated",
        "platform.state_written",
        "platform.sync_completed",
        "platform.sync_conflict_merged",
        "platform.capability_facts",
        "platform.connectivity_changed",
        "tier.capability_detected",
        "tier.classification_returned",
        "tier.fallback_decided",
        "tier.wording_adapted",
        "telemetry.consent_changed",
        "telemetry.batch_sent",
        "telemetry.batch_failed",
        "learning_objects.bundle_loaded",
        "learning_objects.hint_tier_served",
        "graph.prerequisite_returned",
    ]

    // T1 happy-edge extension (AC7): exactly 41 cases, one per contract name.
    @Test("CoreEvent.allCases has exactly 41 cases, matching the contract's notification count")
    func exactCaseCount() {
        #expect(CoreEvent.allCases.count == 41)
        #expect(Self.contractNames.count == 41)
    }

    // AC7: every raw value matches the contract string, in the same left-to-right order the
    // contract lists them (declaration order == CaseIterable order for a non-@_marker enum).
    @Test("CoreEvent.allCases raw values match the contract, in contract order")
    func rawValuesMatchContractInOrder() {
        let actual = CoreEvent.allCases.map(\.rawValue)
        #expect(actual == Self.contractNames)
    }

    // AC7 exhaustiveness: no name added, renamed, or omitted — every contract name resolves to a
    // `CoreEvent` case and round-trips through `init?(rawValue:)`.
    @Test("every contract notification name round-trips through CoreEvent(rawValue:)")
    func everyContractNameRoundTrips() {
        for name in Self.contractNames {
            let event = CoreEvent(rawValue: name)
            #expect(event != nil, "contract name \(name) has no matching CoreEvent case")
            #expect(event?.rawValue == name)
        }
    }

    // T5 negative control (C2): prove the exact-match guard above is load-bearing by reconstructing a
    // broken case list (one renamed name) and showing the same order-and-membership check reds on it,
    // then confirm it greens on the real `CoreEvent.allCases`.
    @Test("the contract-order guard reds against a broken case list with one renamed entry")
    func contractOrderGuardRedsOnRenamedEntry() {
        var broken = Self.contractNames
        broken[3] = "map.landmark_visited"  // was "map.landmark_opened"
        #expect(broken != CoreEvent.allCases.map(\.rawValue))
        #expect(Self.contractNames == CoreEvent.allCases.map(\.rawValue))
    }

    // T5 negative control (C2): a case-count guard that only checks the count, not membership, would
    // wrongly accept a list with the right length but a missing/duplicated name — proving the
    // membership+order check above (not count alone) is what catches AC7 regressions.
    @Test("a count-only guard wrongly accepts a same-length list with a duplicated name")
    func countOnlyGuardWronglyAccepts() {
        var broken = Self.contractNames
        broken.removeLast()
        broken.append(broken[0])  // duplicate "map.opened" instead of the real last entry
        #expect(broken.count == CoreEvent.allCases.count)
        #expect(broken != CoreEvent.allCases.map(\.rawValue))
    }

    // I5: CoreEvent is a bare name registry — every case carries zero associated/reflected payload
    // fields, so no identifying data can ever be attached to an event by construction.
    @Test("every CoreEvent case carries no associated payload (I5)")
    func noAssociatedPayloadOnAnyCase() {
        for event in CoreEvent.allCases {
            let mirror = Mirror(reflecting: event)
            #expect(
                mirror.children.isEmpty,
                "\(event.rawValue) unexpectedly carries reflected children (a payload)")
        }
    }

    // T6 determinism: allCases order is stable across two independent reads (no hidden nondeterminism
    // in synthesized CaseIterable conformance).
    @Test("CoreEvent.allCases order is stable across two reads")
    func allCasesOrderIsStableAcrossReads() {
        let first = CoreEvent.allCases.map(\.rawValue)
        let second = CoreEvent.allCases.map(\.rawValue)
        #expect(first == second)
    }
}
