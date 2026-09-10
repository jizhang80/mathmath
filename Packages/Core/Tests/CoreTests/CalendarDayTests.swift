import Foundation
import Testing

@testable import Core

@Suite("CalendarDay")
struct CalendarDayTests {
    // T1 happy path / AC2: valid ISO strings parse; arithmetic crosses month/year/leap boundaries.
    @Test("valid ISO strings parse and round-trip")
    func validIsoParses() {
        #expect(CalendarDay(iso: "2026-09-10")?.iso == "2026-09-10")
    }

    @Test("adding across a leap-year February boundary")
    func leapYearFebruaryBoundary() throws {
        let day = try #require(CalendarDay(iso: "2028-02-28"))
        #expect(day.adding(days: 1).iso == "2028-02-29")
    }

    @Test("adding across a non-leap-year February boundary")
    func nonLeapYearFebruaryBoundary() throws {
        let day = try #require(CalendarDay(iso: "2027-02-28"))
        #expect(day.adding(days: 1).iso == "2027-03-01")
    }

    @Test("adding across a year boundary")
    func yearBoundary() throws {
        let day = try #require(CalendarDay(iso: "2026-12-31"))
        #expect(day.adding(days: 1).iso == "2027-01-01")
    }

    // T2 negative — invalid input rejected at the boundary (AC2).
    @Test(
        "malformed, out-of-range, and non-existent dates return nil",
        arguments: ["2026-02-30", "2026-13-01", "26-01-01", "2026/01/01", "2026-00-01", "2026-01-32"]
    )
    func invalidIsoReturnsNil(_ iso: String) {
        #expect(CalendarDay(iso: iso) == nil)
    }

    // T5 negative control: a shape-only validator wrongly accepts a non-existent date.
    @Test("regex-shape-only validation wrongly accepts a non-existent date (negative control)")
    func shapeOnlyValidatorWronglyAccepts() {
        func shapeOnlyIsValid(_ iso: String) -> Bool {
            let chars = Array(iso)
            guard chars.count == 10, chars[4] == "-", chars[7] == "-" else {
                return false
            }
            return chars[0..<4].allSatisfy(\.isNumber) && chars[5..<7].allSatisfy(\.isNumber)
                && chars[8..<10].allSatisfy(\.isNumber)
        }
        #expect(shapeOnlyIsValid("2026-02-30"))
        #expect(CalendarDay(iso: "2026-02-30") == nil)
    }

    // T6 idempotency: adding then subtracting the same offset round-trips.
    @Test("adding(days:) then adding(days: -n) round-trips", arguments: [-400, -30, -1, 0, 1, 30, 400])
    func addingRoundTrips(_ n: Int) throws {
        let day = try #require(CalendarDay(iso: "2026-09-10"))
        #expect(day.adding(days: n).adding(days: -n).iso == day.iso)
    }
}
