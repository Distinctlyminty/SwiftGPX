import Testing
import Foundation
@testable import SwiftGPX
#if canImport(CoreLocation)
import CoreLocation
#endif

@Suite("Errors and conveniences")
struct ErrorAndConvenienceTests {
    @Test func errorDescriptionsAreHumanReadable() {
        let cases: [(GPXError, String)] = [
            (.malformedXML(line: 12, message: "boom"), "Malformed GPX at line 12: boom"),
            (.missingRequiredAttribute(element: "wpt", attribute: "lat"), "<wpt> is missing required attribute 'lat'."),
            (.invalidCoordinate("abc"), "Could not parse coordinate value 'abc'."),
            (.unsupportedVersion("2.0"), "GPX version '2.0' is not supported."),
            (.invalidValue(element: "ele", value: 1.0), "Value 1.0 for <ele> cannot be represented in valid GPX."),
            (.ioFailure("denied"), "Could not read GPX data: denied"),
        ]
        for (error, expected) in cases {
            #expect(error.errorDescription == expected)
        }
    }

    @Test func parsesFromInputStream() throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="Stream"><wpt lat="1" lon="2"/></gpx>
        """
        let stream = InputStream(data: Data(xml.utf8))
        let document = try GPXParser().parse(stream)
        #expect(document.creator == "Stream")
        #expect(document.waypoints.count == 1)
    }

    #if canImport(CoreLocation)
    @Test func buildsTrackFromCLLocations() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var locations: [CLLocation] = []
        for index in 0..<3 {
            let offset = Double(index)
            let coordinate = CLLocationCoordinate2D(latitude: 54.5 + offset * 0.001, longitude: -3.1)
            locations.append(CLLocation(
                coordinate: coordinate,
                altitude: 10 + offset,
                horizontalAccuracy: 5,
                verticalAccuracy: index == 2 ? -1 : 3,
                timestamp: start.addingTimeInterval(offset * 5)
            ))
        }
        let document = GPXDocument.track(
            from: locations, creator: "PaddlePal", name: "Morning"
        ) { timestamp in
            timestamp == start ? 120 : nil
        }
        #expect(document.creator == "PaddlePal")
        let points = try #require(document.tracks.first?.segments.first?.points)
        #expect(points.count == 3)
        #expect(points[0].extensions?.heartRate == 120)
        #expect(points[1].extensions == nil)
        #expect(points[0].elevation == 10)
        // Negative verticalAccuracy means no altitude fix — elevation omitted.
        #expect(points[2].elevation == nil)
        try assertRoundTrips(document)
    }
    #endif
}
