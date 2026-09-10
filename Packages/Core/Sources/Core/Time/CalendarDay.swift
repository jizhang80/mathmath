import Foundation

/// A calendar day (`YYYY-MM-DD`, device-local), never finer-grained (`contracts/data-model.md` § Time,
/// I5). Day arithmetic uses Howard Hinnant's proleptic-Gregorian civil-calendar algorithm (public
/// domain, <http://howardhinnant.github.io/date_algorithms.html>) — pure integer math, never
/// `Foundation.Calendar`/`Date`/`TimeZone.current` (I14).
public struct CalendarDay: Equatable, Hashable, Comparable, Sendable {
    public let iso: String

    public init?(iso: String) {
        guard let (year, month, day) = CalendarDay.parseShape(iso) else {
            return nil
        }
        let days = CalendarDay.daysFromCivil(year, month, day)
        let roundTrip = CalendarDay.civilFromDays(days)
        guard roundTrip.y == year, roundTrip.m == month, roundTrip.d == day else {
            return nil
        }
        self.iso = iso
    }

    private init(canonical y: Int, _ m: Int, _ d: Int) {
        self.iso = String(format: "%04d-%02d-%02d", y, m, d)
    }

    public func adding(days: Int) -> CalendarDay {
        // `iso` was validated by `init?(iso:)`, so this parse cannot fail.
        guard let (year, month, day) = CalendarDay.parseShape(iso) else {
            preconditionFailure("CalendarDay.iso failed to re-parse a previously validated value")
        }
        let z = CalendarDay.daysFromCivil(year, month, day) + days
        let civil = CalendarDay.civilFromDays(z)
        return CalendarDay(canonical: civil.y, civil.m, civil.d)
    }

    public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        lhs.iso < rhs.iso
    }

    /// Matches `^\d{4}-\d{2}-\d{2}$` and parses the three integer components. Does not validate that
    /// the resulting date exists — `init?(iso:)` does that via the `daysFromCivil`/`civilFromDays`
    /// round trip.
    private static func parseShape(_ iso: String) -> (y: Int, m: Int, d: Int)? {
        let chars = Array(iso)
        guard chars.count == 10 else {
            return nil
        }
        guard chars[4] == "-", chars[7] == "-" else {
            return nil
        }
        let digitRanges = [0..<4, 5..<7, 8..<10]
        for range in digitRanges where chars[range].contains(where: { !$0.isASCII || !$0.isNumber }) {
            return nil
        }
        guard let year = Int(String(chars[0..<4])), let month = Int(String(chars[5..<7])),
            let day = Int(String(chars[8..<10]))
        else {
            return nil
        }
        return (y: year, m: month, d: day)
    }

    /// Days since 1970-01-01 (may be negative). `m` is 1...12, `d` is 1...31.
    private static func daysFromCivil(_ y: Int, _ m: Int, _ d: Int) -> Int {
        let y2 = y - (m <= 2 ? 1 : 0)
        let era = (y2 >= 0 ? y2 : y2 - 399) / 400
        let yoe = y2 - era * 400  // [0, 399]
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1  // [0, 365]
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy  // [0, 146096]
        return era * 146097 + doe - 719468
    }

    /// Inverse of `daysFromCivil`.
    private static func civilFromDays(_ z: Int) -> (y: Int, m: Int, d: Int) {
        let z2 = z + 719468
        let era = (z2 >= 0 ? z2 : z2 - 146096) / 146097
        let doe = z2 - era * 146097  // [0, 146096]
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365  // [0, 399]
        let y = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)  // [0, 365]
        let mp = (5 * doy + 2) / 153  // [0, 11]
        let d = doy - (153 * mp + 2) / 5 + 1  // [1, 31]
        let m = mp + (mp < 10 ? 3 : -9)  // [1, 12]
        return (y: m <= 2 ? y + 1 : y, m: m, d: d)
    }
}
