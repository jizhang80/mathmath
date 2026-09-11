import Foundation

public enum DoorBSummaryCopy {
    public static let clearedHeading = "Fog lifted"
    public static let blockedHeading = "Marked on the map"
    public static let startAnotherLabel = "Start another"
    public static let backToMapLabel = "Back to the map"
    public static let secondMissLine = "We'll come back to this one"
}

/// One screen the Door B façade hands the caller after a state-changing or continue call. `.item` reuses
/// 04.2's `DoorItemContent` directly (04.2's own §6 default: its screen-content types are shared by both
/// doors — no second wrapper type here, RULE 2). `.diagnosis` carries 04.3's raw `DoorADiagnosisScreen`
/// unmodified, for the App to render and drive further itself.
public enum DoorBScreen: Equatable {
    case item(DoorItemContent)
    case diagnosis(DoorADiagnosisScreen)
    case summary(DoorBSummaryScreen)
}

/// Built only from `ExpeditionSummary` (no tint deltas, no fractions/percentages —
/// `contracts/content-policy.md` § Voice).
public struct DoorBSummaryScreen: Equatable {
    public let itemCount: Int
    public let clearedNodeNames: [String]
    public let blockedNodeNames: [String]
    public let clearedHeading: String
    public let blockedHeading: String
    public let startAnotherLabel: String
    public let backToMapLabel: String
}

enum DoorBContent {
    static func itemScreen(_ current: CurrentItem) -> DoorItemContent {
        DoorItemContent(nodeId: current.nodeId, item: current.item, isRetry: current.isRetry)
    }

    static func summaryScreen(summary: ExpeditionSummary, bundle: ContentBundle) -> DoorBSummaryScreen {
        DoorBSummaryScreen(
            itemCount: summary.itemCount,
            clearedNodeNames: summary.clearedNodeIds.map { nodeName($0, bundle: bundle) },
            blockedNodeNames: summary.blockedNodeIds.map { nodeName($0, bundle: bundle) },
            clearedHeading: DoorBSummaryCopy.clearedHeading,
            blockedHeading: DoorBSummaryCopy.blockedHeading,
            startAnotherLabel: DoorBSummaryCopy.startAnotherLabel,
            backToMapLabel: DoorBSummaryCopy.backToMapLabel)
    }

    private static func nodeName(_ id: String, bundle: ContentBundle) -> String {
        guard let match = bundle.nodes.nodes.first(where: { $0.id == id }) else {
            preconditionFailure("DoorBContent: node \(id) not found in bundle")
        }
        return match.name
    }
}
