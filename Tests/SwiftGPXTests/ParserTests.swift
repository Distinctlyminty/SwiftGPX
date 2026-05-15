import Testing
import Foundation
@testable import SwiftGPX

@Suite("Parser")
struct ParserTests {
    @Test func parsesEmptyDocument() async throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="TestApp" xmlns="http://www.topografix.com/GPX/1/1"></gpx>
        """
        let document = try GPXParser().parse(Data(xml.utf8))
        #expect(document.creator == "TestApp")
        #expect(document.version == "1.1")
        #expect(document.waypoints.isEmpty)
        #expect(document.routes.isEmpty)
        #expect(document.tracks.isEmpty)
    }

    @Test func parsesPaddlePalWaypointFixture() async throws {
        let url = try fixtureURL(named: "Location", ext: "gpx")
        let document = try GPXParser().parse(contentsOf: url)
        #expect(document.creator == "PaddlePal")
        #expect(document.waypoints.count > 100)
        let first = document.waypoints[0]
        #expect(first.latitude == 56.65477058)
        #expect(first.longitude == 9.97823920)
        #expect(first.elevation == 3.11)
        #expect(first.time != nil)
    }

    @Test func parsesGarminTrackPointExtensions() async throws {
        let url = try fixtureURL(named: "track-with-hr", ext: "gpx")
        let document = try GPXParser().parse(contentsOf: url)
        #expect(document.tracks.count == 1)
        let segment = try #require(document.tracks.first?.segments.first)
        #expect(segment.points.count == 3)
        #expect(segment.points[0].extensions?.heartRate == 112)
        #expect(segment.points[0].extensions?.cadence == 34)
        #expect(segment.points[0].extensions?.airTemperature == 14.5)
        #expect(segment.points[1].extensions?.heartRate == 118)
        #expect(segment.points[2].extensions == nil)
    }

    @Test func parsesRoutes() async throws {
        let url = try fixtureURL(named: "route", ext: "gpx")
        let document = try GPXParser().parse(contentsOf: url)
        #expect(document.routes.count == 1)
        #expect(document.routes[0].name == "Derwent Water loop")
        #expect(document.routes[0].points.count == 3)
    }

    @Test func raisesMissingAttributeError() async throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="t"><wpt lon="1"></wpt></gpx>
        """
        await #expect(throws: GPXError.missingRequiredAttribute(element: "wpt", attribute: "lat")) {
            _ = try GPXParser().parse(Data(xml.utf8))
        }
    }

    @Test func raisesInvalidCoordinateError() async throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="t"><wpt lat="not-a-number" lon="1"></wpt></gpx>
        """
        await #expect(throws: GPXError.invalidCoordinate("not-a-number")) {
            _ = try GPXParser().parse(Data(xml.utf8))
        }
    }

    private func fixtureURL(named name: String, ext: String) throws -> URL {
        let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures")
        return try #require(url, "Fixture \(name).\(ext) not found")
    }
}
