import Testing
import Foundation
@testable import SwiftGPX

@Suite("Geometry")
struct GeometryTests {
    @Test func haversineMatchesKnownDistances() {
        // Big Ben to the Eiffel Tower: ~340.5 km great-circle.
        let london = GPXWaypoint(latitude: 51.5007, longitude: -0.1246)
        let paris = GPXWaypoint(latitude: 48.8584, longitude: 2.2945)
        let distance = london.distance(to: paris)
        #expect(abs(distance - 340_500) / 340_500 < 0.005)

        // One degree of longitude at the equator: ~111.19 km.
        let origin = GPXWaypoint(latitude: 0, longitude: 0)
        let oneDegreeEast = GPXWaypoint(latitude: 0, longitude: 1)
        #expect(abs(origin.distance(to: oneDegreeEast) - 111_195) < 10)
    }

    @Test func distanceIsSymmetricAndZeroToSelf() {
        let a = GPXWaypoint(latitude: 54.5, longitude: -3.1)
        let b = GPXWaypoint(latitude: 54.6, longitude: -3.2)
        #expect(a.distance(to: a) == 0)
        #expect(abs(a.distance(to: b) - b.distance(to: a)) < 0.000001)
    }

    @Test func boundsOfEmptySequenceIsNil() {
        #expect(GPXBounds(containing: [GPXWaypoint]()) == nil)
        #expect(GPXTrack().bounds == nil)
        #expect(GPXDocument(creator: "Test").bounds == nil)
    }

    @Test func boundsContainAllPoints() {
        let points = [
            GPXWaypoint(latitude: 54.5, longitude: -3.1),
            GPXWaypoint(latitude: 54.7, longitude: -3.3),
            GPXWaypoint(latitude: 54.6, longitude: -3.0),
        ]
        let bounds = try! #require(GPXBounds(containing: points))
        #expect(bounds == GPXBounds(minLatitude: 54.5, minLongitude: -3.3, maxLatitude: 54.7, maxLongitude: -3.0))
    }

    @Test func singlePointBoundsAreDegenerate() throws {
        let bounds = try #require(GPXBounds(containing: [GPXWaypoint(latitude: 54.5, longitude: -3.1)]))
        #expect(bounds.minLatitude == 54.5)
        #expect(bounds.maxLatitude == 54.5)
    }

    @Test func formUnionExpandsBounds() {
        var bounds = GPXBounds(minLatitude: 54.5, minLongitude: -3.1, maxLatitude: 54.6, maxLongitude: -3.0)
        bounds.formUnion(GPXBounds(minLatitude: 54.4, minLongitude: -3.2, maxLatitude: 54.55, maxLongitude: -2.9))
        #expect(bounds == GPXBounds(minLatitude: 54.4, minLongitude: -3.2, maxLatitude: 54.6, maxLongitude: -2.9))
    }

    @Test func documentBoundsSpanWaypointsRoutesAndTracks() {
        let document = GPXDocument(
            creator: "Test",
            waypoints: [GPXWaypoint(latitude: 54.0, longitude: -3.0)],
            routes: [GPXRoute(points: [GPXWaypoint(latitude: 55.0, longitude: -3.5)])],
            tracks: [GPXTrack(segments: [GPXTrackSegment(points: [
                GPXWaypoint(latitude: 54.5, longitude: -2.5),
            ])])]
        )
        #expect(document.bounds == GPXBounds(minLatitude: 54.0, minLongitude: -3.5, maxLatitude: 55.0, maxLongitude: -2.5))
    }
}

@Suite("Statistics")
struct StatisticsTests {
    /// Points along the equator, 0.001° (~111.19m) apart, 60s apart, with a stationary
    /// interval (p2→p3) and a nil elevation in the middle.
    private func sampleSegment() -> GPXTrackSegment {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        func point(_ lon: Double, _ minute: Double, _ ele: Double?) -> GPXWaypoint {
            GPXWaypoint(
                latitude: 0, longitude: lon, elevation: ele,
                time: start.addingTimeInterval(minute * 60)
            )
        }
        return GPXTrackSegment(points: [
            point(0.000, 0, 10),
            point(0.001, 1, 15),
            point(0.002, 2, 12),
            point(0.002, 3, nil),   // stationary minute, no elevation sample
            point(0.003, 4, 20),
        ])
    }

    @Test func segmentStatistics() {
        let stats = sampleSegment().statistics()
        #expect(abs(stats.distance - 3 * 111.195) < 0.5)
        #expect(stats.duration == 240)
        #expect(stats.movingTime == 180)            // the stationary minute is excluded
        #expect(abs(stats.elevationGain - 13) < 0.0001)   // 10→15 (+5), 12→20 (+8)
        #expect(abs(stats.elevationLoss - 3) < 0.0001)    // 15→12 (−3)
        #expect(stats.pointCount == 5)
    }

    @Test func statisticsWithoutTimestamps() {
        let segment = GPXTrackSegment(points: [
            GPXWaypoint(latitude: 0, longitude: 0),
            GPXWaypoint(latitude: 0, longitude: 0.001),
        ])
        let stats = segment.statistics()
        #expect(stats.duration == nil)
        #expect(stats.movingTime == nil)
        #expect(stats.distance > 100)
    }

    @Test func emptySegmentStatisticsAreZero() {
        let stats = GPXTrackSegment().statistics()
        #expect(stats == GPXTrackStatistics())
    }

    @Test func trackStatisticsSumSegmentsAndSpanDuration() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let track = GPXTrack(segments: [
            GPXTrackSegment(points: [
                GPXWaypoint(latitude: 0, longitude: 0.000, time: start),
                GPXWaypoint(latitude: 0, longitude: 0.001, time: start.addingTimeInterval(60)),
            ]),
            // 10-minute pause between segments.
            GPXTrackSegment(points: [
                GPXWaypoint(latitude: 0, longitude: 0.002, time: start.addingTimeInterval(660)),
                GPXWaypoint(latitude: 0, longitude: 0.003, time: start.addingTimeInterval(720)),
            ]),
        ])
        let stats = track.statistics()
        #expect(abs(stats.distance - 2 * 111.195) < 0.5)  // inter-segment gap distance not counted
        #expect(stats.duration == 720)                    // elapsed, pause included
        #expect(stats.movingTime == 120)                  // pause excluded
        #expect(stats.pointCount == 4)
    }

    @Test func mergingSegmentsConcatenatesInOrder() throws {
        let track = GPXTrack(segments: [
            GPXTrackSegment(points: [GPXWaypoint(latitude: 0, longitude: 0)]),
            GPXTrackSegment(
                points: [GPXWaypoint(latitude: 0, longitude: 0.001)],
                extensions: GPXExtensions(custom: [GPXCustomExtension(qualifiedName: "note", value: "x")])
            ),
        ])
        let merged = track.mergingSegments()
        #expect(merged.segments.count == 1)
        #expect(merged.segments[0].points.map(\.longitude) == [0, 0.001])
        #expect(merged.segments[0].extensions?.custom.first?.value == "x")

        let document = GPXDocument(creator: "Test", tracks: [merged])
        try assertRoundTrips(document)
    }
}

@Suite("Simplification")
struct SimplificationTests {
    @Test func straightLineCollapsesToEndpoints() {
        let segment = GPXTrackSegment(points: (0...10).map {
            GPXWaypoint(latitude: 0, longitude: Double($0) * 0.001)
        })
        let simplified = segment.simplified(tolerance: 5)
        #expect(simplified.points.count == 2)
        #expect(simplified.points.first == segment.points.first)
        #expect(simplified.points.last == segment.points.last)
    }

    @Test func cornerIsPreserved() {
        let corner = GPXWaypoint(latitude: 0, longitude: 0.001)
        let segment = GPXTrackSegment(points: [
            GPXWaypoint(latitude: 0.001, longitude: 0),
            corner,
            GPXWaypoint(latitude: 0.001, longitude: 0.002),
        ])
        // The corner sits ~111m from the straight line between the endpoints.
        #expect(segment.simplified(tolerance: 5).points.count == 3)
        #expect(segment.simplified(tolerance: 5).points[1] == corner)
        #expect(segment.simplified(tolerance: 500).points.count == 2)
    }

    @Test func keptPointsRetainAllValues() {
        let corner = GPXWaypoint(
            latitude: 0, longitude: 0.001,
            elevation: 12, time: Date(timeIntervalSince1970: 1_700_000_000),
            name: "Turn", extensions: GPXExtensions(heartRate: 140)
        )
        let segment = GPXTrackSegment(points: [
            GPXWaypoint(latitude: 0.001, longitude: 0),
            corner,
            GPXWaypoint(latitude: 0.001, longitude: 0.002),
        ])
        #expect(segment.simplified(tolerance: 5).points[1] == corner)
    }

    @Test func simplificationIsIdempotent() {
        let segment = GPXTrackSegment(points: (0...100).map {
            GPXWaypoint(
                latitude: Double($0).truncatingRemainder(dividingBy: 7) * 0.00001,
                longitude: Double($0) * 0.0001
            )
        })
        let once = segment.simplified(tolerance: 10)
        let twice = once.simplified(tolerance: 10)
        #expect(once == twice)
    }

    @Test func shortSegmentsAndZeroToleranceAreUntouched() {
        let two = GPXTrackSegment(points: [
            GPXWaypoint(latitude: 0, longitude: 0),
            GPXWaypoint(latitude: 0, longitude: 0.001),
        ])
        #expect(two.simplified(tolerance: 50) == two)

        let three = GPXTrackSegment(points: [
            GPXWaypoint(latitude: 0, longitude: 0),
            GPXWaypoint(latitude: 0.001, longitude: 0.001),
            GPXWaypoint(latitude: 0, longitude: 0.002),
        ])
        #expect(three.simplified(tolerance: 0) == three)
    }

    @Test func simplifiesRealRecording() async throws {
        let url = try #require(
            Bundle.module.url(forResource: "derwent-water-simulator", withExtension: "gpx", subdirectory: "Fixtures")
        )
        let document = try GPXParser().parse(contentsOf: url)
        for track in document.tracks {
            let simplified = track.simplified(tolerance: 10)
            for (original, reduced) in zip(track.segments, simplified.segments) {
                #expect(reduced.points.count <= original.points.count)
                #expect(reduced.points.first == original.points.first)
                #expect(reduced.points.last == original.points.last)
            }
        }
    }
}
