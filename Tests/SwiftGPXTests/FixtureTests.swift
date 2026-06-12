import Testing
import Foundation
@testable import SwiftGPX

/// Parses fixtures captured from (or shaped like) real-world producers — Strava, Garmin
/// Connect, ClueTrust/pytrainer, COROS, legacy GPX 1.0 — and verifies both the decoded
/// values and that re-serialized output stays schema-shaped and stable.
@Suite("Real-world fixtures")
struct FixtureTests {
    @Test func stravaExportParsesAndReserializes() async throws {
        let document = try parseFixture("strava-export-sample")
        #expect(document.creator == "StravaGPX iPhone")
        #expect(document.tracks[0].type == "kayaking")
        let points = try #require(document.tracks.first?.segments.first?.points)
        #expect(points.count == 3)
        #expect(points.map(\.extensions?.heartRate) == [96, 98, 101])
        #expect(points[0].extensions?.airTemperature == 12.0)
        #expect(points.allSatisfy { $0.time != nil })
        try assertReserializationIsStable(document)
    }

    @Test func garminV2ExportParsesAndKeepsV2Namespace() async throws {
        let document = try parseFixture("garmin-v2-sample")
        let points = try #require(document.tracks.first?.segments.first?.points)
        #expect(points[0].extensions?.speed == 2.31)
        #expect(points[0].extensions?.course == 184.2)
        #expect(points[0].extensions?.waterTemperature == 8.5)
        #expect(points[1].extensions?.heartRate == 107)

        let reserialized = try GPXSerializer().string(from: document)
        #expect(reserialized.contains("xmlns:gpxtpx=\"http://www.garmin.com/xmlschemas/TrackPointExtension/v2\""))
        try assertReserializationIsStable(document)
    }

    @Test func cluetrustExtensionsParse() async throws {
        let document = try parseFixture("cluetrust-extensions")
        #expect(document.namespaces["gpxdata"] == "http://www.cluetrust.com/XML/GPXDATA/1/0")
        let points = try #require(document.tracks.first?.segments.first?.points)
        #expect(points[0].extensions?.heartRate == 96)
        #expect(points[0].extensions?.cadence == 72)
        #expect(points[0].extensions?.waterTemperature == 11.5)
        #expect(points[1].extensions?.custom.contains(GPXCustomExtension(qualifiedName: "gpxdata:distance", value: "4.2")) == true)
        try assertReserializationIsStable(document)
    }

    @Test func corosStyleTimestampsParse() async throws {
        let document = try parseFixture("coros-style-times")
        let points = try #require(document.tracks.first?.segments.first?.points)
        #expect(points.count == 3)
        // .5Z fractional, +0100 compact offset, and missing-zone timestamps all parse.
        #expect(points.allSatisfy { $0.time != nil })
        // 09:12:45.123456+0100 == 08:12:45.123Z (truncated to milliseconds)
        let second = try #require(points[1].time)
        #expect(abs(second.timeIntervalSince1970 - 1_777_795_965.123) < 0.001)
        #expect(points.map(\.extensions?.cadence) == [71, 73, 74])
        #expect(points[0].extensions?.power == 180)
        try assertReserializationIsStable(document)
    }

    @Test func gpx10InputParses() async throws {
        let document = try parseFixture("gpx-1.0-sample")
        #expect(document.version == "1.0")
        #expect(document.waypoints.count == 1)
        #expect(document.tracks[0].segments[0].points.count == 2)
        // Output is normalized to 1.1.
        let reserialized = try GPXSerializer().string(from: document)
        #expect(reserialized.contains("version=\"1.1\""))
    }

    @Test func cdataFieldsParse() async throws {
        let document = try parseFixture("cdata-fields")
        #expect(document.metadata?.name == "Weekend & holiday paddles")
        #expect(document.metadata?.description == "Notes with <markup> & ampersands")
        #expect(document.waypoints[0].name == "Pier & jetty")
        try assertReserializationIsStable(document)
    }

    @Test func truncatedFileThrowsMalformedXML() async throws {
        let url = try fixtureURL("malformed-truncated")
        do {
            _ = try GPXParser().parse(contentsOf: url)
            Issue.record("expected malformedXML error")
        } catch let error as GPXError {
            guard case .malformedXML = error else {
                Issue.record("expected malformedXML, got \(error)")
                return
            }
        }
    }

    @Test func missingFileThrowsIOFailure() async throws {
        let url = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).gpx")
        do {
            _ = try GPXParser().parse(contentsOf: url)
            Issue.record("expected ioFailure error")
        } catch let error as GPXError {
            guard case .ioFailure = error else {
                Issue.record("expected ioFailure, got \(error)")
                return
            }
        }
    }

    @Test func largeSimulatorFixtureParsesAndRoundTrips() async throws {
        let document = try parseFixture("derwent-water-simulator")
        #expect(!document.waypoints.isEmpty || !document.tracks.isEmpty)
        try assertReserializationIsStable(document)
    }

    // MARK: - Helpers

    private func parseFixture(_ name: String) throws -> GPXDocument {
        try GPXParser().parse(contentsOf: fixtureURL(name))
    }

    private func fixtureURL(_ name: String) throws -> URL {
        let url = Bundle.module.url(forResource: name, withExtension: "gpx", subdirectory: "Fixtures")
        return try #require(url, "Fixture \(name).gpx not found")
    }

    /// Serialize → shape-check → re-parse → serialize again; the second pass must be
    /// byte-identical (determinism) and the re-parsed document equal to the first parse.
    private func assertReserializationIsStable(
        _ document: GPXDocument, sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        let serializer = GPXSerializer()
        let first = try serializer.string(from: document)
        expectSchemaShapedGPX(Data(first.utf8), sourceLocation: sourceLocation)
        let reparsed = try GPXParser().parse(Data(first.utf8))
        let second = try serializer.string(from: reparsed)
        #expect(first == second, sourceLocation: sourceLocation)
    }
}
