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
        return nil
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
