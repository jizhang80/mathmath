import Foundation

/// `Core`'s error taxonomy, mirroring the subset of `contracts/error-codes.json` that `Core` raises
/// (`contracts/error-codes.md` § Rules). `ErrorRegistryTests` asserts every case is present in the
/// registry.
///
/// Only `platformBundleIntegrityFailed` is thrown by code shipped in this task (`BundleIO`); the
/// `GRAPH_L0_FAILED`/`MAP_*`/`SPINE_*` cases exist now so tasks 01.2/01.3 do not need to reopen this
/// file (`docs/plans/epic-01-task-plan.md` planner note 7).
public enum CoreError: String, Error, CaseIterable {
    case graphL0Failed = "GRAPH_L0_FAILED"
    case mapLayoutMissing = "MAP_LAYOUT_MISSING"
    case mapRegionUnknown = "MAP_REGION_UNKNOWN"
    case mapLandmarkUnsourced = "MAP_LANDMARK_UNSOURCED"
    case spineUnitEmpty = "SPINE_UNIT_EMPTY"
    case spineSourceRefUnresolved = "SPINE_SOURCE_REF_UNRESOLVED"
    case platformBundleIntegrityFailed = "PLATFORM_BUNDLE_INTEGRITY_FAILED"
    case expNoFringe = "EXP_NO_FRINGE"
    case expTrailInvalid = "EXP_TRAIL_INVALID"
    case expItemPoolEmpty = "EXP_ITEM_POOL_EMPTY"
    case expStateWriteFailed = "EXP_STATE_WRITE_FAILED"
    case expNodeNotInGraph = "EXP_NODE_NOT_IN_GRAPH"
    case diagNoPrerequisite = "DIAG_NO_PREREQUISITE"
    case diagProbeUnavailable = "DIAG_PROBE_UNAVAILABLE"
    case diagStateWriteFailed = "DIAG_STATE_WRITE_FAILED"
    case graphNoPrerequisite = "GRAPH_NO_PREREQUISITE"
    case mapMarkerOffTrail = "MAP_MARKER_OFF_TRAIL"
    case platformStateUnreadable = "PLATFORM_STATE_UNREADABLE"
    case platformStateWriteFailed = "PLATFORM_STATE_WRITE_FAILED"
    case platformSnapshotRefused = "PLATFORM_SNAPSHOT_REFUSED"
}
