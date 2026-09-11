import Core
import SwiftUI

/// The first-launch / course-change picker (arbiter-03 § Q-E). `previousState` is `nil` on the
/// first-launch path (`courseSelectionNeeded`) and the prior `StudentState` on a later course change;
/// this view makes no decision about which — its caller (03.12) supplies whichever applies.
struct CoursePickerView: View {
    let bundle: ContentBundle
    let stateURL: URL
    let previousState: StudentState?
    let today: CalendarDay
    let onSelected: (MapState) -> Void

    var body: some View {
        List(bundle.courses.courses, id: \.courseCode) { course in
            Button(course.name) { select(course.courseCode) }
        }
    }

    private func select(_ courseCode: String) {
        do {
            let (map, _) = try MapFacade.selectCourse(
                courseCode: courseCode, bundle: bundle, stateURL: stateURL,
                previousState: previousState, today: today)
            onSelected(map)
        } catch {
            // CoreError.expTrailInvalid / .platformStateWriteFailed: both surface: internal in
            // contracts/error-codes.json — no student-facing text exists for either. The picker stays on
            // screen; the student's next tap retries the same call (§6).
        }
    }
}
