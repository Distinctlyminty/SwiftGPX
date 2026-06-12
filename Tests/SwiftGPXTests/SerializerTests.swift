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
        #expect(!xml.contains("\n  "))
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
