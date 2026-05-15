import Foundation

/// Encodes a ``GPXDocument`` as GPX 1.1 XML.
///
/// Output is deterministic — same input always produces the same bytes — which makes
/// round-trip tests possible. The Garmin namespace is declared on the root `<gpx>` element
/// only when the document actually carries Garmin extension data.
public struct GPXSerializer: Sendable {
    /// Application name embedded in the `creator` attribute. Overrides `GPXDocument.creator`
    /// only when this value is non-empty.
    public var creator: String

    /// When `true`, emits indented XML (default). When `false`, emits a single-line document.
    public var prettyPrint: Bool

    public init(creator: String = "SwiftGPX", prettyPrint: Bool = true) {
        self.creator = creator
        self.prettyPrint = prettyPrint
    }

    /// Serializes the document to UTF-8 encoded XML data.
    public func data(from document: GPXDocument) -> Data {
        Data(string(from: document).utf8)
    }

    /// Serializes the document to an XML string.
    public func string(from document: GPXDocument) -> String {
        var writer = GPXXMLWriter(prettyPrint: prettyPrint)
        let resolvedCreator = creator.isEmpty ? document.creator : creator
        let needsGarminNamespace = documentUsesGarminExtensions(document)

        writer.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        writer.newline()

        var rootAttributes: [(String, String)] = [
            ("version", document.version),
            ("creator", resolvedCreator),
            ("xmlns", "http://www.topografix.com/GPX/1/1"),
            ("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance"),
            (
                "xsi:schemaLocation",
                "http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd"
            ),
        ]
        if needsGarminNamespace {
            rootAttributes.append(
                ("xmlns:gpxtpx", "http://www.garmin.com/xmlschemas/TrackPointExtension/v1")
            )
        }

        writer.openElement("gpx", attributes: rootAttributes)

        if let metadata = document.metadata {
            writeMetadata(metadata, into: &writer)
        }

        for waypoint in document.waypoints {
            writeWaypoint(waypoint, tag: "wpt", into: &writer)
        }

        for route in document.routes {
            writeRoute(route, into: &writer)
        }

        for track in document.tracks {
            writeTrack(track, into: &writer)
        }

        writer.closeElement("gpx")
        return writer.output
    }

    // MARK: - Element writers

    private func writeMetadata(_ metadata: GPXMetadata, into writer: inout GPXXMLWriter) {
        writer.openElement("metadata")
        if let name = metadata.name { writer.textElement("name", value: name) }
        if let description = metadata.description { writer.textElement("desc", value: description) }
        if let author = metadata.author {
            writer.openElement("author")
            if let name = author.name { writer.textElement("name", value: name) }
            if let email = author.email, let split = splitEmail(email) {
                writer.openElement("email", attributes: [("id", split.id), ("domain", split.domain)])
                writer.closeElement("email")
            }
            if let link = author.link { writeLink(link, into: &writer) }
            writer.closeElement("author")
        }
        if let copyright = metadata.copyright {
            writer.openElement("copyright", attributes: [("author", copyright.author)])
            if let year = copyright.year { writer.textElement("year", value: String(year)) }
            if let license = copyright.license {
                writer.textElement("license", value: license.absoluteString)
            }
            writer.closeElement("copyright")
        }
        for link in metadata.links { writeLink(link, into: &writer) }
        if let time = metadata.time { writer.textElement("time", value: GPXDateFormatter.string(from: time)) }
        if let keywords = metadata.keywords { writer.textElement("keywords", value: keywords) }
        if let bounds = metadata.bounds {
            writer.openElement("bounds", attributes: [
                ("minlat", formatCoordinate(bounds.minLatitude)),
                ("minlon", formatCoordinate(bounds.minLongitude)),
                ("maxlat", formatCoordinate(bounds.maxLatitude)),
                ("maxlon", formatCoordinate(bounds.maxLongitude)),
            ])
            writer.closeElement("bounds")
        }
        writer.closeElement("metadata")
    }

    private func writeWaypoint(_ point: GPXWaypoint, tag: String, into writer: inout GPXXMLWriter) {
        writer.openElement(tag, attributes: [
            ("lat", formatCoordinate(point.latitude)),
            ("lon", formatCoordinate(point.longitude)),
        ])
        if let elevation = point.elevation { writer.textElement("ele", value: formatNumber(elevation)) }
        if let time = point.time { writer.textElement("time", value: GPXDateFormatter.string(from: time)) }
        if let mv = point.magneticVariation { writer.textElement("magvar", value: formatNumber(mv)) }
        if let gh = point.geoidHeight { writer.textElement("geoidheight", value: formatNumber(gh)) }
        if let name = point.name { writer.textElement("name", value: name) }
        if let comment = point.comment { writer.textElement("cmt", value: comment) }
        if let description = point.description { writer.textElement("desc", value: description) }
        if let source = point.source { writer.textElement("src", value: source) }
        for link in point.links { writeLink(link, into: &writer) }
        if let symbol = point.symbol { writer.textElement("sym", value: symbol) }
        if let type = point.type { writer.textElement("type", value: type) }
        if let fix = point.fix { writer.textElement("fix", value: fix.rawValue) }
        if let sats = point.satellites { writer.textElement("sat", value: String(sats)) }
        if let h = point.horizontalDilution { writer.textElement("hdop", value: formatNumber(h)) }
        if let v = point.verticalDilution { writer.textElement("vdop", value: formatNumber(v)) }
        if let p = point.positionDilution { writer.textElement("pdop", value: formatNumber(p)) }
        if let age = point.ageOfDGPSData { writer.textElement("ageofdgpsdata", value: formatNumber(age)) }
        if let dgpsId = point.dgpsId { writer.textElement("dgpsid", value: String(dgpsId)) }
        if let ext = point.extensions, !ext.isEmpty {
            writeExtensions(ext, into: &writer)
        }
        writer.closeElement(tag)
    }

    private func writeRoute(_ route: GPXRoute, into writer: inout GPXXMLWriter) {
        writer.openElement("rte")
        writeTrackOrRouteMetadata(
            name: route.name, comment: route.comment, description: route.description,
            source: route.source, links: route.links, number: route.number, type: route.type,
            into: &writer
        )
        if let ext = route.extensions, !ext.isEmpty { writeExtensions(ext, into: &writer) }
        for point in route.points { writeWaypoint(point, tag: "rtept", into: &writer) }
        writer.closeElement("rte")
    }

    private func writeTrack(_ track: GPXTrack, into writer: inout GPXXMLWriter) {
        writer.openElement("trk")
        writeTrackOrRouteMetadata(
            name: track.name, comment: track.comment, description: track.description,
            source: track.source, links: track.links, number: track.number, type: track.type,
            into: &writer
        )
        if let ext = track.extensions, !ext.isEmpty { writeExtensions(ext, into: &writer) }
        for segment in track.segments {
            writer.openElement("trkseg")
            for point in segment.points {
                writeWaypoint(point, tag: "trkpt", into: &writer)
            }
            if let ext = segment.extensions, !ext.isEmpty { writeExtensions(ext, into: &writer) }
            writer.closeElement("trkseg")
        }
        writer.closeElement("trk")
    }

    private func writeTrackOrRouteMetadata(
        name: String?, comment: String?, description: String?, source: String?,
        links: [GPXLink], number: Int?, type: String?, into writer: inout GPXXMLWriter
    ) {
        if let name { writer.textElement("name", value: name) }
        if let comment { writer.textElement("cmt", value: comment) }
        if let description { writer.textElement("desc", value: description) }
        if let source { writer.textElement("src", value: source) }
        for link in links { writeLink(link, into: &writer) }
        if let number { writer.textElement("number", value: String(number)) }
        if let type { writer.textElement("type", value: type) }
    }

    private func writeLink(_ link: GPXLink, into writer: inout GPXXMLWriter) {
        writer.openElement("link", attributes: [("href", link.href)])
        if let text = link.text { writer.textElement("text", value: text) }
        if let type = link.type { writer.textElement("type", value: type) }
        writer.closeElement("link")
    }

    private func writeExtensions(_ ext: GPXExtensions, into writer: inout GPXXMLWriter) {
        writer.openElement("extensions")

        let hasGarmin = ext.heartRate != nil || ext.cadence != nil || ext.airTemperature != nil
            || ext.waterTemperature != nil || ext.depth != nil || ext.speed != nil
            || ext.course != nil || ext.bearing != nil
        if hasGarmin {
            writer.openElement("gpxtpx:TrackPointExtension")
            if let hr = ext.heartRate { writer.textElement("gpxtpx:hr", value: String(hr)) }
            if let cad = ext.cadence { writer.textElement("gpxtpx:cad", value: String(cad)) }
            if let atemp = ext.airTemperature { writer.textElement("gpxtpx:atemp", value: formatNumber(atemp)) }
            if let wtemp = ext.waterTemperature { writer.textElement("gpxtpx:wtemp", value: formatNumber(wtemp)) }
            if let depth = ext.depth { writer.textElement("gpxtpx:depth", value: formatNumber(depth)) }
            if let speed = ext.speed { writer.textElement("gpxtpx:speed", value: formatNumber(speed)) }
            if let course = ext.course { writer.textElement("gpxtpx:course", value: formatNumber(course)) }
            if let bearing = ext.bearing { writer.textElement("gpxtpx:bearing", value: formatNumber(bearing)) }
            writer.closeElement("gpxtpx:TrackPointExtension")
        }
        if let power = ext.power {
            writer.textElement("power", value: formatNumber(power))
        }
        for custom in ext.custom {
            writer.textElement(custom.qualifiedName, value: custom.value)
        }
        writer.closeElement("extensions")
    }

    // MARK: - Helpers

    private func documentUsesGarminExtensions(_ document: GPXDocument) -> Bool {
        if document.waypoints.contains(where: { hasGarmin($0.extensions) }) { return true }
        if document.routes.contains(where: { $0.points.contains(where: { hasGarmin($0.extensions) }) }) {
            return true
        }
        for track in document.tracks {
            for segment in track.segments {
                if segment.points.contains(where: { hasGarmin($0.extensions) }) { return true }
            }
        }
        return false
    }

    private func hasGarmin(_ ext: GPXExtensions?) -> Bool {
        guard let ext else { return false }
        return ext.heartRate != nil || ext.cadence != nil || ext.airTemperature != nil
            || ext.waterTemperature != nil || ext.depth != nil || ext.speed != nil
            || ext.course != nil || ext.bearing != nil
    }

    private func splitEmail(_ address: String) -> (id: String, domain: String)? {
        guard let at = address.firstIndex(of: "@") else { return nil }
        let id = String(address[..<at])
        let domain = String(address[address.index(after: at)...])
        guard !id.isEmpty, !domain.isEmpty else { return nil }
        return (id, domain)
    }
}

/// 6 decimal places of latitude/longitude is roughly 11cm — more than enough for GPX, and
/// avoids the noise of trailing 9s/0s from `Double`'s default `description`.
func formatCoordinate(_ value: Double) -> String {
    String(format: "%.6f", value)
}

/// Generic numeric formatter. Trims trailing zeros so `42.0` round-trips as `"42"` (matches
/// how most fitness apps emit GPX) but `42.5` stays `"42.5"`.
func formatNumber(_ value: Double) -> String {
    if value == value.rounded() && abs(value) < 1e15 {
        return String(Int64(value))
    }
    var s = String(format: "%.7f", value)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}
