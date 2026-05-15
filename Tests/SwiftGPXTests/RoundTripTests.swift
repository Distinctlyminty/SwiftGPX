import Testing
import Foundation
@testable import SwiftGPX

@Suite("Round trip")
struct RoundTripTests {
    @Test func waypointsRoundTrip() async throws {
        let original = GPXDocument(creator: "Test", waypoints: [
            GPXWaypoint(
                latitude: 54.46094, longitude: -3.08861,
                elevation: 78.5, time: Date(timeIntervalSince1970: 1_700_000_000),
                name: "Start", comment: "Boat ramp", symbol: "Flag"
            ),
        ])
        let xml = GPXSerializer(creator: "Test").data(from: original)
        let decoded = try GPXParser().parse(xml)
        #expect(decoded == original)
    }

    @Test func trackWithExtensionsRoundTrip() async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let segment = GPXTrackSegment(points: [
            GPXWaypoint(
                latitude: 1, longitude: 2, time: date,
                extensions: GPXExtensions(heartRate: 142, cadence: 30, airTemperature: 14.5)
            ),
            GPXWaypoint(
                latitude: 1.001, longitude: 2.001, time: date.addingTimeInterval(5),
                extensions: GPXExtensions(heartRate: 145)
            ),
        ])
        let original = GPXDocument(creator: "Test", tracks: [
            GPXTrack(name: "Test track", segments: [segment]),
        ])
        let xml = GPXSerializer(creator: "Test").data(from: original)
        let decoded = try GPXParser().parse(xml)
        #expect(decoded == original)
    }

    @Test func routeRoundTrip() async throws {
        let original = GPXDocument(creator: "Test", routes: [
            GPXRoute(name: "Loop", points: [
                GPXWaypoint(latitude: 54.5, longitude: -3.1),
                GPXWaypoint(latitude: 54.6, longitude: -3.2),
            ]),
        ])
        let xml = GPXSerializer(creator: "Test").data(from: original)
        let decoded = try GPXParser().parse(xml)
        #expect(decoded == original)
    }

    @Test func metadataRoundTrip() async throws {
        let metadata = GPXMetadata(
            name: "Trip",
            description: "Notes",
            time: Date(timeIntervalSince1970: 1_700_000_000),
            keywords: "paddle,sup"
        )
        let original = GPXDocument(creator: "Test", metadata: metadata)
        let xml = GPXSerializer(creator: "Test").data(from: original)
        let decoded = try GPXParser().parse(xml)
        #expect(decoded.metadata == original.metadata)
    }
}
