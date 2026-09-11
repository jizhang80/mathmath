import Core
import SwiftUI

/// The unit-list marker picker (map W5, interaction-contract v0.9.2 § 3): the marker is set from this
/// list only, one row per unit in unit order, followed by exactly one "past the last unit" row. No drag
/// gesture exists anywhere in this file.
struct UnitListPickerView: View {
    let course: Course
    let mapState: MapState
    let today: CalendarDay
    let onMarkerSet: (MapState) -> Void

    var body: some View {
        List {
            ForEach(course.units, id: \.unitId) { unit in
                Button(unit.name) { setMarker(unitId: unit.unitId, pastLastUnit: false) }
            }
            if let lastUnit = course.units.last {
                Button("Past the last unit") {
                    setMarker(unitId: lastUnit.unitId, pastLastUnit: true)
                }
            }
        }
    }

    private func setMarker(unitId: String, pastLastUnit: Bool) {
        do {
            let (map, _) = try MapFacade.setMarker(
                unitId: unitId, pastLastUnit: pastLastUnit, mapState: mapState, today: today)
            onMarkerSet(map)
        } catch {
            // Same internal-surface treatment as CoursePickerView.select (§6).
        }
    }
}
