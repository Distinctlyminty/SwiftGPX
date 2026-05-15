import Testing
import Foundation
@testable import SwiftGPX

@Suite("Serializer")
struct SerializerTests {
    @Test func emitsValidGPXHeader() {
        let document = GPXDocument(creator: "TestApp")
        let xml = GPXSerializer(creator: "TestApp").string(from: document)

        #expect(xml.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
        #expect(xml.contains("<gpx"))
        #expect(xml.contains("version=\"1.1\""))
        #expect(xml.contains("creator=\"TestApp\""))
        #expect(xml.contains("xmlns=\"http://www.topografix.com/GPX/1/1\""))
        #expect(xml.contains("</gpx>"))
    }

    @Test func omitsGarminNamespaceWhenNoExtensions() {
        let document = GPXDocument(creator: "Test", tracks: [
            GPXTrack(segments: [GPXTrackSegment(points: [
                GPXWaypoint(latitude: 1, longitude: 2),
            ])]),
        ])
        let xml = GPXSerializer().string(from: document)
        #expect(!xml.contains("xmlns:gpxtpx"))
        #expect(!xml.contains("<extensions>"))
    }

    @Test func declaresGarminNamespaceWhenExtensionsPresent() {
        let waypoint = GPXWaypoint(
            latitude: 1, longitude: 2,
            extensions: GPXExtensions(heartRate: 130)
        )
        let document = GPXDocument(creator: "Test", tracks: [
            GPXTrack(segments: [GPXTrackSegment(points: [waypoint])]),
        ])
        let xml = GPXSerializer().string(from: document)
        #expect(xml.contains("xmlns:gpxtpx=\"http://www.garmin.com/xmlschemas/TrackPointExtension/v1\""))
        #expect(xml.contains("<gpxtpx:hr>130</gpxtpx:hr>"))
    }

    @Test func escapesSpecialCharactersInTextElements() {
        let document = GPXDocument(creator: "Test", tracks: [
            GPXTrack(name: "Trip & <fun>", segments: []),
        ])
        let xml = GPXSerializer().string(from: document)
        #expect(xml.contains("<name>Trip &amp; &lt;fun&gt;</name>"))
    }

    @Test func formatsCoordinatesTo6DecimalPlaces() {
        let document = GPXDocument(creator: "Test", waypoints: [
            GPXWaypoint(latitude: 54.46094218, longitude: -3.08861234),
        ])
        let xml = GPXSerializer().string(from: document)
        #expect(xml.contains("lat=\"54.460942\""))
        #expect(xml.contains("lon=\"-3.088612\""))
    }

    @Test func emitsCompactGPXWhenPrettyPrintDisabled() {
        let document = GPXDocument(creator: "Test", waypoints: [
            GPXWaypoint(latitude: 1, longitude: 2),
        ])
        let xml = GPXSerializer(prettyPrint: false).string(from: document)
        #expect(!xml.contains("\n  "))
    }
}
