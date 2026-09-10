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
}
