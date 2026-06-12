import Foundation

/// Encodes a ``GPXDocument`` as GPX 1.1 XML.
///
/// Output is deterministic — same input always produces the same bytes — which makes
/// round-trip tests possible. The serializer is strict: a document carrying values that
/// cannot be represented in valid GPX (non-finite numbers, out-of-range coordinates)
/// throws ``GPXError/invalidValue(element:value:)`` rather than emitting invalid XML.
///
/// The Garmin TrackPointExtension namespace is declared on the root `<gpx>` element only
/// when the document actually carries Garmin extension data; the v2 namespace is used when
/// any v2-only field (`speed`, `course`, `bearing`) is present, v1 otherwise.
public struct GPXSerializer: Sendable {
    /// Application name embedded in the `creator` attribute. When `nil` (the default),
    /// `GPXDocument.creator` is used; a non-nil value overrides it verbatim.
    public var creator: String?

    /// When `true`, emits indented XML (default). When `false`, emits a single-line document.
    public var prettyPrint: Bool

    public init(creator: String? = nil, prettyPrint: Bool = true) {
        self.creator = creator
        self.prettyPrint = prettyPrint
    }

    static let garminV1Namespace = "http://www.garmin.com/xmlschemas/TrackPointExtension/v1"
    static let garminV2Namespace = "http://www.garmin.com/xmlschemas/TrackPointExtension/v2"

    /// Serializes the document to UTF-8 encoded XML data.
    public func data(from document: GPXDocument) throws -> Data {
        Data(try string(from: document).utf8)
    }

    /// Serializes the document to an XML string.
    public func string(from document: GPXDocument) throws -> String {
        var writer = GPXXMLWriter(prettyPrint: prettyPrint)
        let resolvedCreator = creator ?? document.creator
        let garmin = garminUsage(document)

        writer.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        writer.newline()

        // Output is always GPX 1.1 regardless of the version a parsed document declared —
        // the document is emitted in the 1.1 namespace, so the attribute must match.
        var rootAttributes: [(String, String)] = [
            ("version", "1.1"),
            ("creator", resolvedCreator),
            ("xmlns", "http://www.topografix.com/GPX/1/1"),
            ("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance"),
            (
                "xsi:schemaLocation",
                "http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd"
            ),
        ]
        if garmin.any {
            rootAttributes.append(
                ("xmlns:gpxtpx", garmin.v2 ? Self.garminV2Namespace : Self.garminV1Namespace)
            )
        }
        // Re-declare namespaces harvested from the parsed input (sorted for determinism).
        for prefix in document.namespaces.keys.sorted() {
            rootAttributes.append(("xmlns:\(prefix)", document.namespaces[prefix]!))
        }

        var declaredPrefixes = Set(document.namespaces.keys)
        if garmin.any { declaredPrefixes.insert("gpxtpx") }

        writer.openElement("gpx", attributes: rootAttributes)

        if let metadata = document.metadata {
            try writeMetadata(metadata, into: &writer)
        }

        for waypoint in document.waypoints {
            try writeWaypoint(waypoint, tag: "wpt", declaredPrefixes: declaredPrefixes, into: &writer)
        }

        for route in document.routes {
            try writeRoute(route, declaredPrefixes: declaredPrefixes, into: &writer)
        }

        for track in document.tracks {
            try writeTrack(track, declaredPrefixes: declaredPrefixes, into: &writer)
        }

        writer.closeElement("gpx")
        return writer.output
    }

    // MARK: - Element writers

    private func writeMetadata(_ metadata: GPXMetadata, into writer: inout GPXXMLWriter) throws {
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
                ("minlat", try latitude(bounds.minLatitude, element: "bounds.minlat")),
                ("minlon", try longitude(bounds.minLongitude, element: "bounds.minlon")),
                ("maxlat", try latitude(bounds.maxLatitude, element: "bounds.maxlat")),
                ("maxlon", try longitude(bounds.maxLongitude, element: "bounds.maxlon")),
            ])
            writer.closeElement("bounds")
        }
        writer.closeElement("metadata")
    }

    private func writeWaypoint(
        _ point: GPXWaypoint, tag: String, declaredPrefixes: Set<String>,
        into writer: inout GPXXMLWriter
    ) throws {
        writer.openElement(tag, attributes: [
            ("lat", try latitude(point.latitude, element: "\(tag) lat")),
            ("lon", try longitude(point.longitude, element: "\(tag) lon")),
        ])
        if let elevation = point.elevation { writer.textElement("ele", value: try number(elevation, element: "ele")) }
        if let time = point.time { writer.textElement("time", value: GPXDateFormatter.string(from: time)) }
        if let mv = point.magneticVariation { writer.textElement("magvar", value: try number(mv, element: "magvar")) }
        if let gh = point.geoidHeight { writer.textElement("geoidheight", value: try number(gh, element: "geoidheight")) }
        if let name = point.name { writer.textElement("name", value: name) }
        if let comment = point.comment { writer.textElement("cmt", value: comment) }
        if let description = point.description { writer.textElement("desc", value: description) }
        if let source = point.source { writer.textElement("src", value: source) }
        for link in point.links { writeLink(link, into: &writer) }
        if let symbol = point.symbol { writer.textElement("sym", value: symbol) }
        if let type = point.type { writer.textElement("type", value: type) }
        if let fix = point.fix { writer.textElement("fix", value: fix.rawValue) }
        if let sats = point.satellites { writer.textElement("sat", value: String(sats)) }
        if let h = point.horizontalDilution { writer.textElement("hdop", value: try number(h, element: "hdop")) }
        if let v = point.verticalDilution { writer.textElement("vdop", value: try number(v, element: "vdop")) }
        if let p = point.positionDilution { writer.textElement("pdop", value: try number(p, element: "pdop")) }
        if let age = point.ageOfDGPSData { writer.textElement("ageofdgpsdata", value: try number(age, element: "ageofdgpsdata")) }
        if let dgpsId = point.dgpsId { writer.textElement("dgpsid", value: String(dgpsId)) }
        if let ext = point.extensions, !ext.isEmpty {
            try writeExtensions(ext, declaredPrefixes: declaredPrefixes, into: &writer)
        }
        writer.closeElement(tag)
    }

    private func writeRoute(
        _ route: GPXRoute, declaredPrefixes: Set<String>, into writer: inout GPXXMLWriter
    ) throws {
        writer.openElement("rte")
        writeTrackOrRouteMetadata(
            name: route.name, comment: route.comment, description: route.description,
            source: route.source, links: route.links, number: route.number, type: route.type,
            into: &writer
        )
        if let ext = route.extensions, !ext.isEmpty {
            try writeExtensions(ext, declaredPrefixes: declaredPrefixes, into: &writer)
        }
        for point in route.points {
            try writeWaypoint(point, tag: "rtept", declaredPrefixes: declaredPrefixes, into: &writer)
        }
        writer.closeElement("rte")
    }

    private func writeTrack(
        _ track: GPXTrack, declaredPrefixes: Set<String>, into writer: inout GPXXMLWriter
    ) throws {
        writer.openElement("trk")
        writeTrackOrRouteMetadata(
            name: track.name, comment: track.comment, description: track.description,
            source: track.source, links: track.links, number: track.number, type: track.type,
            into: &writer
        )
        if let ext = track.extensions, !ext.isEmpty {
            try writeExtensions(ext, declaredPrefixes: declaredPrefixes, into: &writer)
        }
        for segment in track.segments {
            writer.openElement("trkseg")
            for point in segment.points {
                try writeWaypoint(point, tag: "trkpt", declaredPrefixes: declaredPrefixes, into: &writer)
            }
            if let ext = segment.extensions, !ext.isEmpty {
                try writeExtensions(ext, declaredPrefixes: declaredPrefixes, into: &writer)
            }
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

    private func writeExtensions(
        _ ext: GPXExtensions, declaredPrefixes: Set<String>, into writer: inout GPXXMLWriter
    ) throws {
        writer.openElement("extensions")

        if hasGarmin(ext) {
            writer.openElement("gpxtpx:TrackPointExtension")
            if let hr = ext.heartRate { writer.textElement("gpxtpx:hr", value: String(hr)) }
            if let cad = ext.cadence { writer.textElement("gpxtpx:cad", value: String(cad)) }
            if let atemp = ext.airTemperature { writer.textElement("gpxtpx:atemp", value: try number(atemp, element: "atemp")) }
            if let wtemp = ext.waterTemperature { writer.textElement("gpxtpx:wtemp", value: try number(wtemp, element: "wtemp")) }
            if let depth = ext.depth { writer.textElement("gpxtpx:depth", value: try number(depth, element: "depth")) }
            if let speed = ext.speed { writer.textElement("gpxtpx:speed", value: try number(speed, element: "speed")) }
            if let course = ext.course { writer.textElement("gpxtpx:course", value: try number(course, element: "course")) }
            if let bearing = ext.bearing { writer.textElement("gpxtpx:bearing", value: try number(bearing, element: "bearing")) }
            writer.closeElement("gpxtpx:TrackPointExtension")
        }
        if let power = ext.power {
            writer.textElement("power", value: try number(power, element: "power"))
        }
        for custom in ext.custom {
            // A prefix that was never declared on the root would make the output invalid —
            // strip it and emit the local name instead (validity over verbatim fidelity).
            writer.textElement(
                qualifiedName(custom.qualifiedName, declaredPrefixes: declaredPrefixes),
                value: custom.value
            )
        }
        writer.closeElement("extensions")
    }

    // MARK: - Helpers

    /// Which generation of the Garmin TrackPointExtension schema the document needs.
    private struct GarminUsage {
        var v1 = false
        var v2 = false
        var any: Bool { v1 || v2 }
    }

    private func garminUsage(_ document: GPXDocument) -> GarminUsage {
        var usage = GarminUsage()
        func scan(_ ext: GPXExtensions?) {
            guard let ext else { return }
            if ext.heartRate != nil || ext.cadence != nil || ext.airTemperature != nil
                || ext.waterTemperature != nil || ext.depth != nil {
                usage.v1 = true
            }
            if ext.speed != nil || ext.course != nil || ext.bearing != nil {
                usage.v2 = true
            }
        }
        for waypoint in document.waypoints { scan(waypoint.extensions) }
        for route in document.routes {
            scan(route.extensions)
            for point in route.points { scan(point.extensions) }
        }
        for track in document.tracks {
            scan(track.extensions)
            for segment in track.segments {
                scan(segment.extensions)
                for point in segment.points { scan(point.extensions) }
            }
        }
        return usage
    }

    private func hasGarmin(_ ext: GPXExtensions) -> Bool {
        ext.heartRate != nil || ext.cadence != nil || ext.airTemperature != nil
            || ext.waterTemperature != nil || ext.depth != nil || ext.speed != nil
            || ext.course != nil || ext.bearing != nil
    }

    private func qualifiedName(_ name: String, declaredPrefixes: Set<String>) -> String {
        guard let colon = name.firstIndex(of: ":") else { return name }
        let prefix = String(name[..<colon])
        guard declaredPrefixes.contains(prefix) else {
            return String(name[name.index(after: colon)...])
        }
        return name
    }

    private func latitude(_ value: Double, element: String) throws -> String {
        guard value.isFinite, (-90.0...90.0).contains(value) else {
            throw GPXError.invalidValue(element: element, value: value)
        }
        return formatCoordinate(value)
    }

    private func longitude(_ value: Double, element: String) throws -> String {
        guard value.isFinite, (-180.0...180.0).contains(value) else {
            throw GPXError.invalidValue(element: element, value: value)
        }
        return formatCoordinate(value)
    }

    private func number(_ value: Double, element: String) throws -> String {
        guard value.isFinite else {
            throw GPXError.invalidValue(element: element, value: value)
        }
        return formatNumber(value)
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
/// how most fitness apps emit GPX) but `42.5` stays `"42.5"`. Callers are responsible for
/// rejecting non-finite values first.
func formatNumber(_ value: Double) -> String {
    if value == value.rounded() && abs(value) < 1e15 {
        return String(Int64(value))
    }
    var s = String(format: "%.7f", value)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s
}
