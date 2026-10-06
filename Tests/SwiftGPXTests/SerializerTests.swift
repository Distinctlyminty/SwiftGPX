import Testing
import Foundation
@testable import SwiftGPX

@Suite("Serializer")
struct SerializerTests {
    @Test func emitsValidGPXHeader() throws {
        let document = GPXDocument(creator: "TestApp")
        let xml = try GPXSerializer(creator: "TestApp").string(from: document)

        #expect(xml.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        #expect(xml.contains("<gpx"))
        #expect(xml.contains("version=\"1.1\""))
        #expect(xml.contains("creator=\"TestApp\""))
        #expect(xml.contains("xmlns=\"http://www.topografix.com/GPX/1/1\""))
        #expect(xml.contains("</gpx>"))
    }

    @Test func omitsGarminNamespaceWhenNoExtensions() throws {
        let document = GPXDocument(creator: "Test", tracks: [
            GPXTrack(segments: [GPXTrackSegment(points: [
                GPXWaypoint(latitude: 1, longitude: 2),
            ])]),
        ])
        let xml = try GPXSerializer().string(from: document)
        #expect(!xml.contains("xmlns:gpxtpx"))
        #expect(!xml.contains("<extensions>"))
    }

    @Test func declaresGarminNamespaceWhenExtensionsPresent() throws {
        let waypoint = GPXWaypoint(
            latitude: 1, longitude: 2,
            extensions: GPXExtensions(heartRate: 130)
        )
        let document = GPXDocument(creator: "Test", tracks: [
            GPXTrack(segments: [GPXTrackSegment(points: [waypoint])]),
        ])
        let xml = try GPXSerializer().string(from: document)
        #expect(xml.contains("xmlns:gpxtpx=\"http://www.garmin.com/xmlschemas/TrackPointExtension/v1\""))
        #expect(xml.contains("<gpxtpx:hr>130</gpxtpx:hr>"))
    }

    @Test func escapesSpecialCharactersInTextElements() throws {
        let document = GPXDocument(creator: "Test", tracks: [
            GPXTrack(name: "Trip & <fun>", segments: []),
        ])
        let xml = try GPXSerializer().string(from: document)
        #expect(xml.contains("<name>Trip &amp; &lt;fun&gt;</name>"))
    }

    @Test func formatsCoordinatesTo6DecimalPlaces() throws {
        let document = GPXDocument(creator: "Test", waypoints: [
            GPXWaypoint(latitude: 54.46094218, longitude: -3.08861234),
        ])
        let xml = try GPXSerializer().string(from: document)
        #expect(xml.contains("lat=\"54.460942\""))
        #expect(xml.contains("lon=\"-3.088612\""))
    }

    @Test func emitsCompactGPXWhenPrettyPrintDisabled() throws {
        let document = GPXDocument(creator: "Test", waypoints: [
            GPXWaypoint(latitude: 1, longitude: 2),
        ])
        let xml = try GPXSerializer(prettyPrint: false).string(from: document)
        #expect(!xml.contains("\n"))
        expectSchemaShapedGPX(Data(xml.utf8))
    }

    @Test func declaresV2NamespaceWhenV2FieldsPresent() throws {
        let waypoint = GPXWaypoint(
            latitude: 1, longitude: 2,
            extensions: GPXExtensions(heartRate: 130, speed: 2.5)
        )
        let document = GPXDocument(creator: "Test", tracks: [
            GPXTrack(segments: [GPXTrackSegment(points: [waypoint])]),
        ])
        let xml = try GPXSerializer().string(from: document)
        #expect(xml.contains("xmlns:gpxtpx=\"http://www.garmin.com/xmlschemas/TrackPointExtension/v2\""))
        #expect(!xml.contains("TrackPointExtension/v1"))
        #expect(xml.contains("<gpxtpx:speed>2.5</gpxtpx:speed>"))
    }

    @Test func defaultCreatorPreservesDocumentCreator() throws {
        let document = GPXDocument(creator: "PaddlePal")
        let xml = try GPXSerializer().string(from: document)
        #expect(xml.contains("creator=\"PaddlePal\""))
    }

    @Test func explicitCreatorOverridesDocumentCreator() throws {
        let document = GPXDocument(creator: "PaddlePal")
        let xml = try GPXSerializer(creator: "OtherApp").string(from: document)
        #expect(xml.contains("creator=\"OtherApp\""))
    }

    @Test func normalizesVersionTo11OnOutput() throws {
        let document = GPXDocument(version: "1.0", creator: "Test")
        let xml = try GPXSerializer().string(from: document)
        #expect(xml.contains("version=\"1.1\""))
    }

    @Test func throwsOnOutOfRangeLatitude() throws {
        let document = GPXDocument(creator: "Test", waypoints: [
            GPXWaypoint(latitude: 200, longitude: 1),
        ])
        #expect(throws: GPXError.invalidValue(element: "wpt lat", value: 200)) {
            _ = try GPXSerializer().string(from: document)
        }
    }

    @Test func throwsOnNaNElevation() throws {
        let document = GPXDocument(creator: "Test", waypoints: [
            GPXWaypoint(latitude: 1, longitude: 2, elevation: .nan),
        ])
        #expect(throws: GPXError.self) {
            _ = try GPXSerializer().string(from: document)
        }
    }

    @Test func throwsOnInfiniteExtensionValue() throws {
        let waypoint = GPXWaypoint(
            latitude: 1, longitude: 2,
            extensions: GPXExtensions(speed: .infinity)
        )
        let document = GPXDocument(creator: "Test", tracks: [
            GPXTrack(segments: [GPXTrackSegment(points: [waypoint])]),
        ])
        #expect(throws: GPXError.invalidValue(element: "speed", value: .infinity)) {
            _ = try GPXSerializer().string(from: document)
        }
    }

    @Test func throwsOnOutOfRangeBounds() throws {
        var metadata = GPXMetadata()
        metadata.bounds = GPXBounds(minLatitude: -91, minLongitude: 0, maxLatitude: 0, maxLongitude: 0)
        let document = GPXDocument(creator: "Test", metadata: metadata)
        #expect(throws: GPXError.invalidValue(element: "bounds.minlat", value: -91)) {
            _ = try GPXSerializer().string(from: document)
        }
    }

    @Test func stripsUndeclaredCustomExtensionPrefix() throws {
        let waypoint = GPXWaypoint(
            latitude: 1, longitude: 2,
            extensions: GPXExtensions(custom: [
                GPXCustomExtension(qualifiedName: "mystery:value", value: "7"),
            ])
        )
        let document = GPXDocument(creator: "Test", waypoints: [waypoint])
        let xml = try GPXSerializer().string(from: document)
        #expect(xml.contains("<value>7</value>"))
        #expect(!xml.contains("mystery:"))
    }

    @Test(arguments: [
        (42.0, "42"),
        (42.5, "42.5"),
        (-0.0, "0"),
        (0.1, "0.1"),
        (14.50, "14.5"),
        (3.1415926535, "3.1415927"),    // 7 decimal places max
        (-3.2, "-3.2"),
        (1_000_000.0, "1000000"),
        (-0.00000001, "0"),             // rounds to zero — no "-0"
        (0.00000006, "0.0000001"),
    ])
    func formatNumberTable(value: Double, expected: String) {
        #expect(formatNumber(value) == expected)
    }

    @Test func escapesAttributeValues() throws {
        let document = GPXDocument(creator: "Test", waypoints: [
            GPXWaypoint(latitude: 1, longitude: 2, links: [
                GPXLink(href: "https://example.com/?a=1&b=\"x\"<>'"),
            ]),
        ])
        let xml = try GPXSerializer().string(from: document)
        #expect(xml.contains("href=\"https://example.com/?a=1&amp;b=&quot;x&quot;&lt;&gt;&apos;\""))
    }

    @Test func prettyPrintedOutputIsExactlyDeterministic() throws {
        let document = GPXDocument(creator: "Pin", waypoints: [
            GPXWaypoint(latitude: 54.5, longitude: -3.1, elevation: 10, name: "A"),
        ])
        let xml = try GPXSerializer().string(from: document)
        let expected = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Pin" xmlns="http://www.topografix.com/GPX/1/1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <wpt lat="54.500000" lon="-3.100000">
            <ele>10</ele>
            <name>A</name>
          </wpt>
        </gpx>

        """
        #expect(xml == expected)
    }

    /// The TrackPointExtension schema is an xsd:sequence, so child order is part of validity.
    @Test func emitsGarminFieldsInSchemaOrder() throws {
        let waypoint = GPXWaypoint(
            latitude: 1, longitude: 2,
            extensions: GPXExtensions(
                heartRate: 142, cadence: 75, airTemperature: 14.5, waterTemperature: 9.5,
                depth: 3.2, speed: 2.5, course: 184.5, bearing: 190
            )
        )
        let document = GPXDocument(creator: "Test", waypoints: [waypoint])
        let xml = try GPXSerializer(prettyPrint: false).string(from: document)
        let expected = [
            "<gpxtpx:TrackPointExtension>",
            "<gpxtpx:atemp>14.5</gpxtpx:atemp>",
            "<gpxtpx:wtemp>9.5</gpxtpx:wtemp>",
            "<gpxtpx:depth>3.2</gpxtpx:depth>",
            "<gpxtpx:hr>142</gpxtpx:hr>",
            "<gpxtpx:cad>75</gpxtpx:cad>",
            "<gpxtpx:speed>2.5</gpxtpx:speed>",
            "<gpxtpx:course>184.5</gpxtpx:course>",
            "<gpxtpx:bearing>190</gpxtpx:bearing>",
            "</gpxtpx:TrackPointExtension>",
        ].joined()
        #expect(xml.contains(expected))
    }

    @Test func dropsCharactersXMLCannotRepresent() throws {
        let document = GPXDocument(creator: "A\u{0}pp", waypoints: [
            GPXWaypoint(latitude: 1, longitude: 2, name: "Pier\u{1}\u{B} & \u{FFFE}jetty\u{1F}"),
        ])
        let data = try GPXSerializer().data(from: document)
        expectSchemaShapedGPX(data)
        let decoded = try GPXParser().parse(data)
        #expect(decoded.creator == "App")
        #expect(decoded.waypoints[0].name == "Pier & jetty")
    }

    /// A namespace map that collides with the declarations the serializer writes itself,
    /// or that isn't expressible as an attribute, must not produce a malformed root.
    @Test func skipsNamespaceDeclarationsThatWouldBreakTheRoot() throws {
        let waypoint = GPXWaypoint(
            latitude: 1, longitude: 2,
            extensions: GPXExtensions(heartRate: 130, custom: [
                GPXCustomExtension(qualifiedName: "bad prefix:lap", value: "1"),
                GPXCustomExtension(qualifiedName: "ok:lap", value: "2"),
            ])
        )
        let document = GPXDocument(
            creator: "Test", waypoints: [waypoint],
            namespaces: [
                "gpxtpx": "urn:example:not-garmin",
                "xsi": "urn:example:not-xsi",
                "xml": "urn:example:reserved",
                "bad prefix": "urn:example:bad",
                "empty": "",
                "ok": "urn:example:ok",
            ]
        )
        let xml = try GPXSerializer().string(from: document)
        expectSchemaShapedGPX(Data(xml.utf8))
        #expect(xml.contains("xmlns:gpxtpx=\"http://www.garmin.com/xmlschemas/TrackPointExtension/v1\""))
        #expect(xml.contains("xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\""))
        #expect(xml.contains("xmlns:ok=\"urn:example:ok\""))
        #expect(!xml.contains("urn:example:not-"))
        #expect(!xml.contains("urn:example:reserved"))
        #expect(!xml.contains("urn:example:bad"))
        #expect(!xml.contains("xmlns:empty"))
        #expect(xml.contains("<lap>1</lap>"))
        #expect(xml.contains("<ok:lap>2</ok:lap>"))
    }

    @Test(arguments: [
        ("lap count", "lap_count"),
        ("1st", "_1st"),
        ("a<b>", "a_b_"),
        ("", "_"),
        ("gpxdata:lap:count", "gpxdata:lap_count"),
        ("gpxdata:", "gpxdata:_"),
        ("gpxdata:run-cadence.avg_2", "gpxdata:run-cadence.avg_2"),
        ("Länge", "Länge"),
    ])
    func sanitizesCustomExtensionNames(name: String, expected: String) throws {
        let waypoint = GPXWaypoint(
            latitude: 1, longitude: 2,
            extensions: GPXExtensions(custom: [GPXCustomExtension(qualifiedName: name, value: "7")])
        )
        let document = GPXDocument(
            creator: "Test", waypoints: [waypoint],
            namespaces: ["gpxdata": "http://www.cluetrust.com/XML/GPXDATA/1/0"]
        )
        let xml = try GPXSerializer().string(from: document)
        expectSchemaShapedGPX(Data(xml.utf8))
        #expect(xml.contains("<\(expected)>7</\(expected)>"))
    }

    @Test func redeclaresHarvestedNamespaces() throws {
        let waypoint = GPXWaypoint(
            latitude: 1, longitude: 2,
            extensions: GPXExtensions(custom: [
                GPXCustomExtension(qualifiedName: "gpxdata:lap", value: "1"),
            ])
        )
        let document = GPXDocument(
            creator: "Test", waypoints: [waypoint],
            namespaces: ["gpxdata": "http://www.cluetrust.com/XML/GPXDATA/1/0"]
        )
        let xml = try GPXSerializer().string(from: document)
        #expect(xml.contains("xmlns:gpxdata=\"http://www.cluetrust.com/XML/GPXDATA/1/0\""))
        #expect(xml.contains("<gpxdata:lap>1</gpxdata:lap>"))
    }
}
