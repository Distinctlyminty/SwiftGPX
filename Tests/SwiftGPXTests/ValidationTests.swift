import Testing
import Foundation
@testable import SwiftGPX

@Suite("Validation")
struct ValidationTests {
    private func trackDocument(points: [GPXWaypoint]) -> GPXDocument {
        GPXDocument(creator: "Test", tracks: [
            GPXTrack(segments: [GPXTrackSegment(points: points)]),
        ])
    }

    @Test func validDocumentHasNoIssues() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let document = trackDocument(points: [
            GPXWaypoint(latitude: 54.5, longitude: -3.1, time: date),
            GPXWaypoint(latitude: 54.51, longitude: -3.11, time: date.addingTimeInterval(5)),
        ])
        #expect(document.validate().isEmpty)
        #expect(document.validateForStrava().isEmpty)
    }

    @Test func reportsEmptyDocument() {
        let document = GPXDocument(creator: "Test")
        #expect(document.validate() == [.emptyDocument])
    }

    @Test func reportsOutOfRangeCoordinates() {
        let document = GPXDocument(creator: "Test", waypoints: [
            GPXWaypoint(latitude: 91, longitude: -181),
        ])
        let issues = document.validate()
        #expect(issues.contains(.latitudeOutOfRange(value: 91, path: "waypoints[0]")))
        #expect(issues.contains(.longitudeOutOfRange(value: -181, path: "waypoints[0]")))
    }

    @Test func reportsNonFiniteValues() {
        let document = trackDocument(points: [
            GPXWaypoint(
                latitude: 54.5, longitude: -3.1, elevation: .nan,
                extensions: GPXExtensions(speed: .infinity)
            ),
        ])
        let issues = document.validate()
        let path = "tracks[0].segments[0].points[0]"
        #expect(issues.contains(.nonFiniteValue(element: "ele", path: path)))
        #expect(issues.contains(.nonFiniteValue(element: "speed", path: path)))
    }

    @Test func reportsOutOfRangeBounds() {
        var metadata = GPXMetadata()
        metadata.bounds = GPXBounds(minLatitude: -95, minLongitude: 0, maxLatitude: 0, maxLongitude: 0)
        let document = GPXDocument(creator: "Test", metadata: metadata, waypoints: [
            GPXWaypoint(latitude: 1, longitude: 2),
        ])
        #expect(document.validate() == [.latitudeOutOfRange(value: -95, path: "metadata.bounds.minlat")])
    }

    @Test func stravaValidationRequiresTimeOnEveryTrackPoint() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let document = trackDocument(points: [
            GPXWaypoint(latitude: 54.5, longitude: -3.1, time: date),
            GPXWaypoint(latitude: 54.51, longitude: -3.11),
        ])
        #expect(document.validate().isEmpty)
        #expect(document.validateForStrava() == [.missingTrackPointTime(track: 0, segment: 0, point: 1)])
    }

    @Test func stravaValidationDetectsBackwardsTime() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let document = trackDocument(points: [
            GPXWaypoint(latitude: 54.5, longitude: -3.1, time: date),
            GPXWaypoint(latitude: 54.51, longitude: -3.11, time: date.addingTimeInterval(-5)),
        ])
        #expect(document.validateForStrava() == [.nonMonotonicTime(track: 0, segment: 0, point: 1)])
    }

    @Test func stravaValidationRejectsDocumentWithoutTrackPoints() {
        let document = GPXDocument(creator: "Test", waypoints: [
            GPXWaypoint(latitude: 54.5, longitude: -3.1),
        ])
        #expect(document.validate().isEmpty)
        #expect(document.validateForStrava() == [.emptyDocument])
    }

    @Test func issueDescriptionsAreHumanReadable() {
        #expect(
            GPXValidationIssue.missingTrackPointTime(track: 0, segment: 1, point: 42).description
                .contains("tracks[0].segments[1].points[42]")
        )
        #expect(GPXValidationIssue.emptyDocument.description.contains("no waypoints"))
    }

    @Test func stravaPresetSetsCreatorAndCompactOutput() throws {
        let document = GPXDocument(creator: "Ignored", tracks: [
            GPXTrack(segments: [GPXTrackSegment(points: [
                GPXWaypoint(latitude: 54.5, longitude: -3.1, time: Date(timeIntervalSince1970: 1_700_000_000)),
            ])]),
        ])

        let plain = try GPXSerializer.strava(appName: "PaddlePal").string(from: document)
        #expect(plain.contains("creator=\"PaddlePal\""))
        #expect(!plain.contains("\n  "))

        let barometric = try GPXSerializer.strava(appName: "PaddlePal", hasBarometer: true).string(from: document)
        #expect(barometric.contains("creator=\"PaddlePal with Barometer\""))
        expectSchemaShapedGPX(Data(barometric.utf8))
    }

    @Test func bareExtensionTagsParseIntoTypedFields() async throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="t">
        <trk><trkseg><trkpt lat="1" lon="2"><extensions>
        <heartrate>142</heartrate><temperature>11.5</temperature><power>250</power>
        </extensions></trkpt></trkseg></trk>
        </gpx>
        """
        let document = try GPXParser().parse(Data(xml.utf8))
        let extensions = try #require(document.tracks[0].segments[0].points[0].extensions)
        #expect(extensions.heartRate == 142)
        #expect(extensions.airTemperature == 11.5)
        #expect(extensions.power == 250)
        #expect(extensions.custom.isEmpty)
    }
}
