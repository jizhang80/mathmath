import Foundation

/// An exact rational (`numerator / denominator`, `denominator > 0`, always kept in lowest terms). Private
/// to `ItemChecker` — the sole mechanism behind the numeric-normalisation grammar
/// (`contracts/interaction-contract.md` v0.9.1 § 2). All arithmetic uses Swift's overflow-reporting
/// operators; no operation here ever traps (I1's "no floating-point comparison" and the contract's
/// "never a crash" rule both hold structurally).
private struct Rational: Equatable {
    let numerator: Int
    let denominator: Int

    /// Implements the contract's grammar exactly: trimmed whitespace; optional leading sign; one or more
    /// digits; an optional `.` followed by one or more digits; an optional `/` followed by one or more
    /// digits (`b ≠ 0`). Any leftover character, or a missing mandatory digit group where the grammar
    /// requires one, means the string does not parse.
    static func parse(_ raw: String) -> Rational? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let chars = Array(trimmed)
        var index = 0

        var negative = false
        if chars[index] == "+" || chars[index] == "-" {
            negative = chars[index] == "-"
            index += 1
        }

        let intStart = index
        while index < chars.count, chars[index].isASCII, chars[index].isNumber { index += 1 }
        guard index > intStart else { return nil }
        guard let intValue = Int(String(chars[intStart..<index])) else { return nil }

        var numerator = intValue
        var denominator = 1

        if index < chars.count, chars[index] == "." {
            index += 1
            let decStart = index
            while index < chars.count, chars[index].isASCII, chars[index].isNumber { index += 1 }
            guard index > decStart else { return nil }
            guard let decValue = Int(String(chars[decStart..<index])) else { return nil }
            guard let pow10 = Rational.pow10(index - decStart) else { return nil }
            let (scaledInt, overflow1) = intValue.multipliedReportingOverflow(by: pow10)
            guard !overflow1 else { return nil }
            let (combined, overflow2) = scaledInt.addingReportingOverflow(decValue)
            guard !overflow2 else { return nil }
            numerator = combined
            denominator = pow10
        }

        if index < chars.count, chars[index] == "/" {
            index += 1
            let fracStart = index
            while index < chars.count, chars[index].isASCII, chars[index].isNumber { index += 1 }
            guard index > fracStart else { return nil }
            guard let fracValue = Int(String(chars[fracStart..<index])), fracValue != 0 else { return nil }
            let (scaledDenominator, overflow) = denominator.multipliedReportingOverflow(by: fracValue)
            guard !overflow else { return nil }
            denominator = scaledDenominator
        }

        guard index == chars.count else { return nil }

        if negative { numerator = -numerator }
        return Rational(numerator: numerator, denominator: denominator).reduced()
    }

    /// Decomposes a `Double`'s IEEE-754 bit pattern into an exact fraction — no floating-point
    /// multiplication or division anywhere (I1). `0` (including `-0.0`) maps to `0/1` directly.
    static func exact(fromTolerance tolerance: Double) -> Rational {
        guard tolerance != 0 else { return Rational(numerator: 0, denominator: 1) }
        let bits = tolerance.bitPattern
        let signBit = (bits >> 63) & 1
        let rawExponent = Int((bits >> 52) & 0x7FF)
        let rawMantissa = Int(bits & 0xF_FFFF_FFFF_FFFF)

        let mantissa: Int
        let exponent: Int
        if rawExponent == 0 {
            mantissa = rawMantissa
            exponent = -1074
        } else {
            mantissa = rawMantissa | (1 << 52)
            exponent = rawExponent - 1075
        }

        var numerator = mantissa
        var denominator = 1
        if exponent >= 0 {
            numerator = mantissa << exponent
        } else {
            denominator = 1 << (-exponent)
        }
        if signBit == 1 { numerator = -numerator }
        return Rational(numerator: numerator, denominator: denominator).reduced()
    }

    /// `self - other`, as an exact non-negative rational. `nil` iff any intermediate step overflows —
    /// the caller treats `nil` as "not within tolerance" (never a crash).
    func absoluteDifference(from other: Rational) -> Rational? {
        let (ad, overflow1) = numerator.multipliedReportingOverflow(by: other.denominator)
        guard !overflow1 else { return nil }
        let (cb, overflow2) = other.numerator.multipliedReportingOverflow(by: denominator)
        guard !overflow2 else { return nil }
        let (diffNumerator, overflow3) = ad.subtractingReportingOverflow(cb)
        guard !overflow3 else { return nil }
        let (diffDenominator, overflow4) = denominator.multipliedReportingOverflow(by: other.denominator)
        guard !overflow4 else { return nil }

        let absNumerator: Int
        if diffNumerator < 0 {
            let (negated, overflow5) = 0.subtractingReportingOverflow(diffNumerator)
            guard !overflow5 else { return nil }
            absNumerator = negated
        } else {
            absNumerator = diffNumerator
        }
        return Rational(numerator: absNumerator, denominator: diffDenominator).reduced()
    }

    /// `self <= other` (both non-negative, both `denominator > 0`). `false` on overflow (never a crash) —
    /// a conservative "not within tolerance" fallback.
    func isLessThanOrEqual(to other: Rational) -> Bool {
        let (lhs, overflow1) = numerator.multipliedReportingOverflow(by: other.denominator)
        let (rhs, overflow2) = other.numerator.multipliedReportingOverflow(by: denominator)
        guard !overflow1, !overflow2 else { return false }
        return lhs <= rhs
    }

    private func reduced() -> Rational {
        guard numerator != 0 else { return Rational(numerator: 0, denominator: 1) }
        let g = Rational.gcd(Rational.safeAbs(numerator), denominator)
        return Rational(numerator: numerator / g, denominator: denominator / g)
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var a = a
        var b = b
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return a == 0 ? 1 : a
    }

    private static func safeAbs(_ x: Int) -> Int {
        x == Int.min ? Int.max : (x < 0 ? -x : x)
    }

    private static func pow10(_ n: Int) -> Int? {
        var result = 1
        for _ in 0..<n {
            let (product, overflow) = result.multipliedReportingOverflow(by: 10)
            guard !overflow else { return nil }
            result = product
        }
        return result
    }
}

/// The sole, deterministic code path that decides whether a submitted answer is correct
/// (`contracts/interaction-contract.md` v0.9.1 § 2 `answer(item)`; I1, I10). No model, no CAS, no adapter
/// anywhere in this file — `check`'s only inputs are a `ProbeItem` and a `String`.
public enum ItemChecker {
    /// `numeric`: both `submitted` and `item.answer.value` are parsed under the exact-rational grammar and
    /// compared for exact equality, or within `item.answer.tolerance` (default `0`). A submission that
    /// does not parse, or an item with no `answer`, is a miss. `mc`: `submitted` is compared to
    /// `item.correctChoiceId` only, never to any `choices[].latex` text (I10).
    public static func check(item: ProbeItem, submitted: String) -> Bool {
        switch item.type {
        case .numeric:
            guard let answer = item.answer, let target = Rational.parse(answer.value),
                let submittedValue = Rational.parse(submitted)
            else { return false }
            if submittedValue == target { return true }
            guard let diff = submittedValue.absoluteDifference(from: target) else { return false }
            let tolerance = Rational.exact(fromTolerance: answer.tolerance ?? 0)
            return diff.isLessThanOrEqual(to: tolerance)
        case .mc:
            return submitted == item.correctChoiceId
        }
    }

    /// The correct answer's display string — `item.answer.value` verbatim for `numeric`, the matching
    /// choice's `latex` for `mc` — always shown alongside `why` (I3).
    public static func correctAnswerDisplay(for item: ProbeItem) -> String {
        switch item.type {
        case .numeric:
            return item.answer?.value ?? ""
        case .mc:
            return item.choices?.first(where: { $0.id == item.correctChoiceId })?.latex ?? ""
        }
    }
}
