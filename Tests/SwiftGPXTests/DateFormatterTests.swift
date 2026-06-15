import Testing
import Foundation
@testable import SwiftGPX

@Suite("Date formatter")
struct DateFormatterTests {
    /// 2024-06-01T14:30:45Z
    private let baseEpoch: TimeInterval = 1_717_252_245

    @Test(arguments: [
        ("2024-06-01T14:30:45Z", 0.0),
        ("2024-06-01T14:30:45.500Z", 0.5),
        ("2024-06-01T14:30:45.5Z", 0.5),          // 1-digit fraction
        ("2024-06-01T14:30:45.12Z", 0.12),        // 2-digit fraction
        ("2024-06-01T14:30:45.123456Z", 0.123),   // microseconds truncated to millis
        ("2024-06-01T15:30:45+01:00", 0.0),       // offset with colon
        ("2024-06-01T15:30:45+0100", 0.0),        // compact offset
        ("2024-06-01T13:30:45-01:00", 0.0),       // negative offset
        ("2024-06-01T14:30:45", 0.0),             // no zone designator — treated as UTC
        ("2024-06-01T14:30:45.25", 0.25),         // fraction and no zone
    ])
    func parsesTimestampVariants(input: String, fraction: Double) throws {
        let date = try #require(GPXDateFormatter.date(from: input), "failed to parse \(input)")
        #expect(abs(date.timeIntervalSince1970 - (baseEpoch + fraction)) < 0.001)
    }

    @Test(arguments: ["", "not-a-date", "2024-06-01", "14:30:45Z", "2024-06-01T14:30:45.12a3Z"])
    func rejectsGarbage(input: String) {
        #expect(GPXDateFormatter.date(from: input) == nil)
    }

    @Test func emitsUTCWithoutFractionalSeconds() {
        let date = Date(timeIntervalSince1970: baseEpoch)
        #expect(GPXDateFormatter.string(from: date) == "2024-06-01T14:30:45Z")
    }
}
