import Foundation

/// ISO-8601 date formatter used for GPX `<time>` elements.
///
/// GPX 1.1 requires `xsd:dateTime` — typically rendered as `YYYY-MM-DDTHH:MM:SSZ` in UTC.
/// We emit without fractional seconds (most fitness apps do) but accept both forms on input.
enum GPXDateFormatter {
    static func string(from date: Date) -> String {
        Self.encoder.string(from: date)
    }

    static func date(from string: String) -> Date? {
        if let date = Self.decoder.date(from: string) { return date }
        if let date = Self.decoderFractional.date(from: string) { return date }
        // Real-world GPX timestamps stray from the two forms ISO8601DateFormatter accepts:
        // variable-length fractional seconds (.5, .12, .123456), compact offsets (+0100),
        // and missing zone designators. Normalize and retry before giving up.
        if let normalized = normalize(string), normalized != string {
            if let date = Self.decoder.date(from: normalized) { return date }
            if let date = Self.decoderFractional.date(from: normalized) { return date }
        }
        return nil
    }

    /// Rewrites near-ISO8601 timestamps into a form the strict formatters accept:
    /// fractional seconds padded/truncated to exactly 3 digits, `+0100`-style offsets
    /// given their colon, and a missing zone designator treated as UTC (GPX times are UTC).
    private static func normalize(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        guard let tIndex = s.firstIndex(where: { $0 == "T" || $0 == "t" }) else { return nil }

        // Split off the zone designator (Z, or the last +/- after the T).
        let timePart = s[s.index(after: tIndex)...]
        var zone = "Z"
        if s.hasSuffix("Z") || s.hasSuffix("z") {
            s.removeLast()
        } else if let signIndex = timePart.lastIndex(where: { $0 == "+" || $0 == "-" }) {
            zone = String(s[signIndex...])
            s = String(s[..<signIndex])
            // Compact offset (+0100 → +01:00).
            if zone.count == 5, !zone.contains(":") {
                zone.insert(":", at: zone.index(zone.startIndex, offsetBy: 3))
            }
        }

        // Pad or truncate fractional seconds to exactly 3 digits.
        if let dot = s.lastIndex(of: ".") {
            let fraction = s[s.index(after: dot)...]
            guard fraction.allSatisfy(\.isNumber) else { return nil }
            let digits = String(fraction.prefix(3))
            s = String(s[..<dot]) + "." + digits.padding(toLength: 3, withPad: "0", startingAt: 0)
        }

        return s + zone
    }

    // ISO8601DateFormatter is documented as thread-safe for read use; the singletons are
    // marked nonisolated(unsafe) to satisfy Swift 6 strict-concurrency checking while
    // avoiding per-call allocation on the parsing hot path.
    private nonisolated(unsafe) static let encoder: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private nonisolated(unsafe) static let decoder: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private nonisolated(unsafe) static let decoderFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
