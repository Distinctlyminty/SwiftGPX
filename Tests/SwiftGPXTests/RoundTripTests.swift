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
        try assertRoundTrips(original)
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
        try assertRoundTrips(original)
    }

    @Test func routeRoundTrip() async throws {
        let original = GPXDocument(creator: "Test", routes: [
            GPXRoute(name: "Loop", points: [
                GPXWaypoint(latitude: 54.5, longitude: -3.1),
                GPXWaypoint(latitude: 54.6, longitude: -3.2),
            ]),
        ])
        try assertRoundTrips(original)
    }

    @Test func metadataRoundTrip() async throws {
        let metadata = GPXMetadata(
            name: "Trip",
            description: "Notes",
            time: Date(timeIntervalSince1970: 1_700_000_000),
            keywords: "paddle,sup"
        )
        let original = GPXDocument(creator: "Test", metadata: metadata)
        try assertRoundTrips(original)
    }

    @Test func authorAndCopyrightRoundTrip() async throws {
        let metadata = GPXMetadata(
            name: "Trip",
            author: GPXPerson(
                name: "James",
                email: "james@example.com",
                link: GPXLink(href: "https://example.com", text: "Site", type: "text/html")
            ),
            copyright: GPXCopyright(
                author: "James",
                year: 2026,
                license: URL(string: "https://creativecommons.org/licenses/by/4.0/")
            )
        )
        let original = GPXDocument(creator: "Test", metadata: metadata)
        try assertRoundTrips(original)
    }

    @Test func metadataLinksAndBoundsRoundTrip() async throws {
        let metadata = GPXMetadata(
            links: [
                GPXLink(href: "https://paddlepal.app", text: "PaddlePal"),
                GPXLink(href: "https://example.com/route?a=1&b=2"),
            ],
            bounds: GPXBounds(minLatitude: 54.4, minLongitude: -3.2, maxLatitude: 54.6, maxLongitude: -3.0)
        )
        let original = GPXDocument(creator: "Test", metadata: metadata)
        try assertRoundTrips(original)
    }

    @Test(arguments: [GPXFix.none, .twoDimensional, .threeDimensional, .dgps, .pps])
    func fullWaypointRoundTrip(fix: GPXFix) async throws {
        let original = GPXDocument(creator: "Test", waypoints: [
            GPXWaypoint(
                latitude: 54.46094, longitude: -3.08861,
                elevation: 78.5, time: Date(timeIntervalSince1970: 1_700_000_000),
                magneticVariation: 1.5, geoidHeight: 48.2,
                name: "Start", comment: "Boat ramp", description: "Western shore",
                source: "GPS", links: [GPXLink(href: "https://example.com/wpt")],
                symbol: "Flag", type: "launch",
                fix: fix, satellites: 9,
                horizontalDilution: 1.2, verticalDilution: 2.4, positionDilution: 2.8,
                ageOfDGPSData: 4.5, dgpsId: 23
            ),
        ])
        try assertRoundTrips(original)
    }

    @Test func allGarminFieldsRoundTrip() async throws {
        let point = GPXWaypoint(
            latitude: 54.5, longitude: -3.1,
            extensions: GPXExtensions(
                heartRate: 142, cadence: 75, airTemperature: 14.5,
                waterTemperature: 9.5, depth: 3.2,
                speed: 2.5, course: 184.5, bearing: 190,
                power: 220.5
            )
        )
        let original = GPXDocument(creator: "Test", tracks: [
            GPXTrack(segments: [GPXTrackSegment(points: [point])]),
        ])
        try assertRoundTrips(original)
    }

    @Test func customExtensionsWithNamespaceRoundTrip() async throws {
        let point = GPXWaypoint(
            latitude: 54.5, longitude: -3.1,
            extensions: GPXExtensions(custom: [
                GPXCustomExtension(qualifiedName: "gpxdata:lap", value: "1"),
                GPXCustomExtension(qualifiedName: "gpxdata:distance", value: "1520.5"),
            ])
        )
        let original = GPXDocument(
            creator: "Test",
            tracks: [GPXTrack(segments: [GPXTrackSegment(points: [point])])],
            namespaces: ["gpxdata": "http://www.cluetrust.com/XML/GPXDATA/1/0"]
        )
        try assertRoundTrips(original)
    }

    @Test func multiSegmentMultiTrackRoundTrip() async throws {
        let original = GPXDocument(creator: "Test", tracks: [
            GPXTrack(name: "Day 1", number: 1, type: "kayaking", segments: [
                GPXTrackSegment(points: [
                    GPXWaypoint(latitude: 54.5, longitude: -3.1),
                    GPXWaypoint(latitude: 54.51, longitude: -3.11),
                ]),
                GPXTrackSegment(points: [
                    GPXWaypoint(latitude: 54.52, longitude: -3.12),
                ]),
            ]),
            GPXTrack(
                name: "Day 2", comment: "Windy", description: "Crossed the lake",
                source: "PaddlePal", links: [GPXLink(href: "https://example.com/day2")],
                segments: [GPXTrackSegment(points: [
                    GPXWaypoint(latitude: 54.6, longitude: -3.2),
                ])]
            ),
        ])
        try assertRoundTrips(original)
    }

    @Test func routeMetadataRoundTrip() async throws {
        let original = GPXDocument(creator: "Test", routes: [
            GPXRoute(
                name: "Loop", comment: "Easy", description: "Around the island",
                source: "Planner", links: [GPXLink(href: "https://example.com/rte")],
                number: 3, type: "paddle",
                points: [GPXWaypoint(latitude: 54.5, longitude: -3.1)]
            ),
        ])
        try assertRoundTrips(original)
    }

    @Test func trackAndSegmentLevelExtensionsRoundTrip() async throws {
        let original = GPXDocument(creator: "Test", tracks: [
            GPXTrack(
                segments: [GPXTrackSegment(
                    points: [GPXWaypoint(latitude: 54.5, longitude: -3.1)],
                    extensions: GPXExtensions(custom: [
                        GPXCustomExtension(qualifiedName: "note", value: "segment"),
                    ])
                )],
                extensions: GPXExtensions(custom: [
                    GPXCustomExtension(qualifiedName: "note", value: "track"),
                ])
            ),
        ])
        try assertRoundTrips(original)
    }

    @Test func emptyCollectionsRoundTrip() async throws {
        try assertRoundTrips(GPXDocument(creator: "Test"))
        try assertRoundTrips(GPXDocument(creator: "Test", tracks: [GPXTrack()]))
        try assertRoundTrips(GPXDocument(creator: "Test", tracks: [GPXTrack(segments: [GPXTrackSegment()])]))
        try assertRoundTrips(GPXDocument(creator: "Test", routes: [GPXRoute(name: "Empty")]))
    }

    @Test func emptyStringNameRoundTrips() async throws {
        let original = GPXDocument(creator: "Test", waypoints: [
            GPXWaypoint(latitude: 1, longitude: 2, name: ""),
        ])
        try assertRoundTrips(original)
    }

    @Test func defaultCreatorRoundTrips() async throws {
        let original = GPXDocument(creator: "PaddlePal", waypoints: [
            GPXWaypoint(latitude: 1, longitude: 2),
        ])
        let decoded = try assertRoundTrips(original)
        #expect(decoded.creator == "PaddlePal")
    }

    /// GPX `<time>` is emitted without fractional seconds (matching the fitness-app
    /// ecosystem), so sub-second precision is intentionally truncated on output.
    @Test func fractionalSecondTimesTruncateOnOutput() async throws {
        let original = GPXDocument(creator: "Test", waypoints: [
            GPXWaypoint(latitude: 1, longitude: 2, time: Date(timeIntervalSince1970: 1_700_000_000.75)),
        ])
        let data = try GPXSerializer().data(from: original)
        expectSchemaShapedGPX(data)
        let decoded = try GPXParser().parse(data)
        #expect(decoded.waypoints[0].time == Date(timeIntervalSince1970: 1_700_000_000))
    }
}
