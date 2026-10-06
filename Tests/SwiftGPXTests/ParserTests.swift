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
        #expect(throws: GPXError.missingRequiredAttribute(element: "wpt", attribute: "lat")) {
            _ = try GPXParser().parse(Data(xml.utf8))
        }
    }

    @Test func raisesInvalidCoordinateError() async throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="t"><wpt lat="not-a-number" lon="1"></wpt></gpx>
        """
        #expect(throws: GPXError.invalidCoordinate("not-a-number")) {
            _ = try GPXParser().parse(Data(xml.utf8))
        }
    }

    @Test func parsesBounds() async throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="t"><metadata>
        <bounds minlat="54.4" minlon="-3.2" maxlat="54.6" maxlon="-3.0"/>
        </metadata></gpx>
        """
        let document = try GPXParser().parse(Data(xml.utf8))
        let bounds = try #require(document.metadata?.bounds)
        #expect(bounds == GPXBounds(minLatitude: 54.4, minLongitude: -3.2, maxLatitude: 54.6, maxLongitude: -3.0))
    }

    @Test(arguments: [
        #"minlat="54.4" minlon="-3.2" maxlat="54.6""#,        // missing maxlon
        #"minlat="abc" minlon="-3.2" maxlat="54.6" maxlon="-3.0""#,  // malformed minlat
    ])
    func skipsIncompleteBounds(attributes: String) async throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="t"><metadata><bounds \(attributes)/></metadata></gpx>
        """
        let document = try GPXParser().parse(Data(xml.utf8))
        #expect(document.metadata?.bounds == nil)
    }

    @Test func parsesCDATAContent() async throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="t">
        <metadata><desc><![CDATA[A & B <fast>]]></desc></metadata>
        <trk><trkseg><trkpt lat="1" lon="2"><name><![CDATA[Pier & jetty]]></name></trkpt></trkseg></trk>
        </gpx>
        """
        let document = try GPXParser().parse(Data(xml.utf8))
        #expect(document.metadata?.description == "A & B <fast>")
        #expect(document.tracks[0].segments[0].points[0].name == "Pier & jetty")
    }

    @Test func unknownWrapperChildrenDoNotLeakIntoParent() async throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="t">
        <metadata><foo><name>Leaked</name><bar><desc>Deep</desc></bar></foo><name>Real</name></metadata>
        <trk><trkseg><trkpt lat="1" lon="2"><widget><ele>99</ele></widget></trkpt></trkseg></trk>
        </gpx>
        """
        let document = try GPXParser().parse(Data(xml.utf8))
        #expect(document.metadata?.name == "Real")
        #expect(document.metadata?.description == nil)
        #expect(document.tracks[0].segments[0].points[0].elevation == nil)
    }

    @Test func unknownLeafInsideExtensionsStillCapturedAsCustom() async throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="t">
        <trk><trkseg><trkpt lat="1" lon="2"><extensions><mystery>42</mystery></extensions></trkpt></trkseg></trk>
        </gpx>
        """
        let document = try GPXParser().parse(Data(xml.utf8))
        let extensions = try #require(document.tracks[0].segments[0].points[0].extensions)
        #expect(extensions.custom == [GPXCustomExtension(qualifiedName: "mystery", value: "42")])
    }

    @Test func invalidTrackPointCoordinateThrowsSpecificError() async throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="t">
        <trk><trkseg><trkpt lat="abc" lon="1"><name>X</name></trkpt></trkseg></trk>
        </gpx>
        """
        #expect(throws: GPXError.invalidCoordinate("abc")) {
            _ = try GPXParser().parse(Data(xml.utf8))
        }
    }

    @Test func missingLongitudeThrows() async throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="t"><wpt lat="1"></wpt></gpx>
        """
        #expect(throws: GPXError.missingRequiredAttribute(element: "wpt", attribute: "lon")) {
            _ = try GPXParser().parse(Data(xml.utf8))
        }
    }

    @Test func rejectsUnsupportedVersion() async throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="2.0" creator="t"></gpx>
        """
        #expect(throws: GPXError.unsupportedVersion("2.0")) {
            _ = try GPXParser().parse(Data(xml.utf8))
        }
    }

    @Test func acceptsGPX10Input() async throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.0" creator="OldApp" xmlns="http://www.topografix.com/GPX/1/0">
        <wpt lat="54.5" lon="-3.1"><ele>10</ele></wpt>
        </gpx>
        """
        let document = try GPXParser().parse(Data(xml.utf8))
        #expect(document.version == "1.0")
        #expect(document.waypoints.count == 1)
    }

    @Test func emptyLeafElements() async throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="t">
        <wpt lat="1" lon="2"><ele></ele><name></name></wpt>
        </gpx>
        """
        let document = try GPXParser().parse(Data(xml.utf8))
        #expect(document.waypoints[0].elevation == nil)
        #expect(document.waypoints[0].name == "")
    }

    // MARK: - Structure

    @Test func nonGPXRootThrowsMalformedXML() throws {
        let xml = """
        <?xml version="1.0"?>
        <kml xmlns="http://www.opengis.net/kml/2.2"><Document><name>Not GPX</name></Document></kml>
        """
        do {
            _ = try GPXParser().parse(Data(xml.utf8))
            Issue.record("expected malformedXML error")
        } catch let error as GPXError {
            // The line number comes from XMLParser and isn't identical across platforms.
            guard case .malformedXML(_, let message) = error else {
                Issue.record("expected malformedXML, got \(error)")
                return
            }
            #expect(message == "root element is <kml>, expected <gpx>")
        }
    }

    @Test func prefixedRootElementParses() throws {
        let xml = """
        <?xml version="1.0"?>
        <g:gpx version="1.1" creator="Prefixed" xmlns:g="http://www.topografix.com/GPX/1/1">
        <g:wpt lat="1" lon="2"><g:name>A</g:name></g:wpt>
        </g:gpx>
        """
        let document = try GPXParser().parse(Data(xml.utf8))
        #expect(document.creator == "Prefixed")
        #expect(document.waypoints.map(\.name) == ["A"])
        #expect(document.namespaces.isEmpty)
    }

    /// Elements are only recognised under the parent the schema gives them. Anything
    /// inside an unrecognised wrapper is ignored as a unit — including attribute-only
    /// elements like `<email>` and `<bounds>`, which once closed the wrapper early.
    @Test func misplacedElementsAreIgnored() throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="Outer">
        <metadata>
          <foo>
            <email id="a" domain="b.com"/>
            <bounds minlat="1" minlon="2" maxlat="3" maxlon="4"/>
            <name>Leaked</name>
            <link href="https://example.com/leaked"/>
            <author><name>Leaked</name></author>
            <copyright author="Leaked"/>
          </foo>
        </metadata>
        <foo>
          <gpx creator="Inner"/>
          <wpt lat="1" lon="2"/>
          <rte><rtept lat="1" lon="2"/></rte>
          <trk><trkseg><trkpt lat="1" lon="2"/></trkseg></trk>
        </foo>
        <trk>
          <wpt lat="1" lon="2"/>
          <trkpt lat="1" lon="2"/>
          <trkseg><link href="https://example.com/leaked"/><trkpt lat="5" lon="6"/></trkseg>
        </trk>
        </gpx>
        """
        let document = try GPXParser().parse(Data(xml.utf8))
        #expect(document.creator == "Outer")
        #expect(document.metadata == GPXMetadata())
        #expect(document.waypoints.isEmpty)
        #expect(document.routes.isEmpty)
        #expect(document.tracks == [
            GPXTrack(segments: [GPXTrackSegment(points: [GPXWaypoint(latitude: 5, longitude: 6)])]),
        ])
    }

    @Test func nestedExtensionsFixtureDoesNotLeakIntoDocument() throws {
        let url = try fixtureURL(named: "nested-extensions", ext: "gpx")
        let document = try GPXParser().parse(contentsOf: url)

        // Structural element names inside <extensions> stay extension data.
        #expect(document.metadata == GPXMetadata(name: "Harbour loop"))
        #expect(document.waypoints.count == 1)
        #expect(document.tracks.count == 1)
        #expect(document.namespaces == [
            "gpxx": "http://www.garmin.com/xmlschemas/GpxExtensions/v3",
            "app": "https://example.com/app/1",
        ])

        // Wrappers flatten to their leaves; a childless element is kept with an empty value.
        #expect(document.waypoints[0].links.isEmpty)
        #expect(document.waypoints[0].extensions == GPXExtensions(custom: [
            GPXCustomExtension(qualifiedName: "gpxx:DisplayMode", value: "SymbolAndName"),
            GPXCustomExtension(qualifiedName: "app:pinned", value: ""),
        ]))

        let points = try #require(document.tracks.first?.segments.first?.points)
        #expect(points.count == 3)

        // Decimal-formatted integers parse; unknown TrackPointExtension children survive.
        #expect(points[0].links.isEmpty)
        #expect(points[0].extensions == GPXExtensions(heartRate: 96, cadence: 71, custom: [
            GPXCustomExtension(qualifiedName: "ns3:stress", value: "12"),
            GPXCustomExtension(qualifiedName: "name", value: "Not the document name either"),
            GPXCustomExtension(qualifiedName: "app:wpt", value: ""),
            GPXCustomExtension(qualifiedName: "app:trkpt", value: ""),
            GPXCustomExtension(qualifiedName: "app:link", value: ""),
        ]))

        // Non-finite numbers become nil; an unusable typed value is kept verbatim.
        #expect(points[1].elevation == nil)
        #expect(points[1].extensions == GPXExtensions(custom: [
            GPXCustomExtension(qualifiedName: "ns3:hr", value: "resting"),
        ]))

        // An extensions block carrying nothing is absent, as the serializer would write it.
        #expect(points[2].extensions == nil)

        // Re-serialized output parses back to the same thing once prefixes are normalized.
        let reserialized = try GPXSerializer().data(from: document)
        expectSchemaShapedGPX(reserialized)
        try assertRoundTrips(GPXParser().parse(reserialized))
    }

    @Test(arguments: ["nan", "inf", "-infinity"])
    func nonFiniteCoordinateThrows(raw: String) throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="t"><wpt lat="\(raw)" lon="1"/></gpx>
        """
        #expect(throws: GPXError.invalidCoordinate(raw)) {
            _ = try GPXParser().parse(Data(xml.utf8))
        }
    }

    @Test func nonFiniteOptionalValuesBecomeNil() throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="t">
        <metadata><bounds minlat="nan" minlon="-3.2" maxlat="54.6" maxlon="-3.0"/></metadata>
        <wpt lat=" 1 " lon="2"><ele>inf</ele><hdop>NaN</hdop><sat>7.0</sat></wpt>
        </gpx>
        """
        let document = try GPXParser().parse(Data(xml.utf8))
        #expect(document.metadata?.bounds == nil)
        #expect(document.waypoints == [GPXWaypoint(latitude: 1, longitude: 2, satellites: 7)])
    }

    @Test func valuesOutsideTheGarminWrapperWinOverThoseInside() throws {
        let xml = """
        <?xml version="1.0"?>
        <gpx version="1.1" creator="t">
        <wpt lat="1" lon="2"><extensions>
        <hr>100</hr>
        <gpxtpx:TrackPointExtension><gpxtpx:hr>90</gpxtpx:hr><gpxtpx:power>250</gpxtpx:power></gpxtpx:TrackPointExtension>
        </extensions></wpt>
        </gpx>
        """
        let document = try GPXParser().parse(Data(xml.utf8))
        #expect(document.waypoints[0].extensions == GPXExtensions(heartRate: 100, custom: [
            GPXCustomExtension(qualifiedName: "gpxtpx:power", value: "250"),
        ]))
    }

    /// Appending each point used to copy the whole segment, making parse time quadratic —
    /// minutes for a recording this size. The time limit is what guards against that.
    /// The document is also deliberately over 10 MB, the size at which Linux's
    /// `XMLParser(data:)` starts rejecting input.
    @Test(.timeLimit(.minutes(1)))
    func largeTrackParsesInLinearTime() throws {
        let pointCount = 100_000
        let points = (0..<pointCount).map {
            GPXWaypoint(latitude: 54.5, longitude: -3.1, elevation: Double($0))
        }
        let original = GPXDocument(
            creator: "Test",
            routes: [GPXRoute(points: points)],
            tracks: [GPXTrack(segments: [GPXTrackSegment(points: points)])]
        )
        let data = try GPXSerializer(prettyPrint: false).data(from: original)
        #expect(data.count > 10_000_000)
        let decoded = try GPXParser().parse(data)
        #expect(decoded.routes.first?.points.count == pointCount)
        #expect(decoded.tracks.first?.segments.first?.points.count == pointCount)
        #expect(decoded.tracks.first?.segments.first?.points.last?.elevation == Double(pointCount - 1))
    }

    private func fixtureURL(named name: String, ext: String) throws -> URL {
        let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures")
        return try #require(url, "Fixture \(name).\(ext) not found")
    }
}
