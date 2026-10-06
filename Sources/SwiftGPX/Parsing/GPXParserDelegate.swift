import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// SAX delegate that builds a ``GPXDocument`` as it walks the XML.
///
/// State machine: the parser maintains a stack of "frames" — one per open element of interest.
/// Each frame knows what kind of element it is (`waypoint`, `track`, `metadata`, …) and
/// accumulates either child elements (by pushing more frames) or text content. When the
/// element closes, the frame is popped and folded into its parent.
final class GPXParserDelegate: NSObject, XMLParserDelegate {
    private(set) var document = GPXDocument(creator: "")
    var error: GPXError?

    /// True once a root `<gpx>` element has been opened. An XML document that never
    /// produces one (swift-corelibs-foundation accepts empty input) is not GPX.
    private(set) var foundRoot = false

    private var stack: [Frame] = []
    private var characterBuffer: String = ""

    /// True when the parser stopped with element frames still open. Every open element has
    /// exactly one frame, so a balanced document always unwinds to an empty stack. We check
    /// this explicitly because swift-corelibs-foundation's `XMLParser` (Linux) does not
    /// report truncated XML as a parse error the way the libxml2-backed Darwin parser does —
    /// without it, truncated input parses "successfully".
    var hasUnterminatedElements: Bool { !stack.isEmpty }

    // MARK: - Frame model

    /// One frame per open element, so the top of the stack is always the direct parent of
    /// whatever opens or closes next. Containers are only recognised under the parent the
    /// GPX schema gives them; anything else becomes `.leaf` or `.unknown` and can't leak
    /// into an enclosing frame.
    private enum Frame {
        case document
        case metadata(GPXMetadata)
        case author(GPXPerson)
        case copyright(GPXCopyright)
        case link(GPXLink)
        case waypoint(GPXWaypoint, kind: WaypointKind)
        case route(GPXRoute)
        case track(GPXTrack)
        case trackSegment(GPXTrackSegment)
        case extensions(GPXExtensions)
        case garminTrackPointExtension(GPXExtensions)
        /// A child of `<extensions>` (at any depth). Elements that turn out to have child
        /// elements are wrappers; the rest are leaves folded into the enclosing extensions.
        case extensionElement(hasChildren: Bool)
        /// A child of a known container whose text is folded into that container by name
        /// when it closes (`name`, `ele`, `time`, …). Unrecognised names fold to nothing.
        case leaf
        /// An element that is ignored along with everything inside it.
        case unknown
    }

    private enum WaypointKind { case waypoint, routePoint, trackPoint }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser, didStartElement elementName: String,
        namespaceURI: String?, qualifiedName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        characterBuffer = ""
        let localName = stripPrefix(elementName)

        guard let top = stack.last else {
            startRoot(elementName, localName: localName, attributes: attributeDict, parser: parser)
            return
        }

        switch top {
        case .unknown, .leaf:
            stack.append(.unknown)

        case .extensions, .garminTrackPointExtension, .extensionElement:
            if case .extensionElement(hasChildren: false) = top {
                stack[stack.count - 1] = .extensionElement(hasChildren: true)
            }
            // Garmin/ClueTrust extensions: handled regardless of namespace prefix.
            if isGarminTrackPointExtensionElement(elementName) {
                stack.append(.garminTrackPointExtension(GPXExtensions()))
            } else {
                stack.append(.extensionElement(hasChildren: false))
            }

        case .document:
            switch localName {
            case "metadata": stack.append(.metadata(GPXMetadata()))
            case "wpt": startWaypoint(.waypoint, element: "wpt", attributes: attributeDict, parser: parser)
            case "rte": stack.append(.route(GPXRoute()))
            case "trk": stack.append(.track(GPXTrack()))
            default: stack.append(.unknown)
            }

        case .metadata(var metadata):
            switch localName {
            case "author": stack.append(.author(GPXPerson()))
            case "copyright": stack.append(.copyright(GPXCopyright(author: attributeDict["author"] ?? "")))
            case "link": startLink(attributeDict)
            case "bounds":
                // Lenient: a bounds element with missing or malformed attributes is skipped
                // entirely rather than fabricating 0.0 coordinates.
                if let minLat = parseDouble(attributeDict["minlat"]),
                   let minLon = parseDouble(attributeDict["minlon"]),
                   let maxLat = parseDouble(attributeDict["maxlat"]),
                   let maxLon = parseDouble(attributeDict["maxlon"]) {
                    metadata.bounds = GPXBounds(
                        minLatitude: minLat,
                        minLongitude: minLon,
                        maxLatitude: maxLat,
                        maxLongitude: maxLon
                    )
                    stack[stack.count - 1] = .metadata(metadata)
                }
                stack.append(.unknown)
            default: stack.append(.leaf)
            }

        case .author(var person):
            switch localName {
            case "email":
                if let id = attributeDict["id"], let domain = attributeDict["domain"] {
                    person.email = "\(id)@\(domain)"
                    stack[stack.count - 1] = .author(person)
                }
                stack.append(.unknown)
            case "link": startLink(attributeDict)
            default: stack.append(.leaf)
            }

        case .copyright, .link:
            stack.append(.leaf)

        case .waypoint:
            switch localName {
            case "link": startLink(attributeDict)
            case "extensions": stack.append(.extensions(GPXExtensions()))
            default: stack.append(.leaf)
            }

        case .route:
            switch localName {
            case "rtept": startWaypoint(.routePoint, element: "rtept", attributes: attributeDict, parser: parser)
            case "link": startLink(attributeDict)
            case "extensions": stack.append(.extensions(GPXExtensions()))
            default: stack.append(.leaf)
            }

        case .track:
            switch localName {
            case "trkseg": stack.append(.trackSegment(GPXTrackSegment()))
            case "link": startLink(attributeDict)
            case "extensions": stack.append(.extensions(GPXExtensions()))
            default: stack.append(.leaf)
            }

        case .trackSegment:
            switch localName {
            case "trkpt": startWaypoint(.trackPoint, element: "trkpt", attributes: attributeDict, parser: parser)
            case "extensions": stack.append(.extensions(GPXExtensions()))
            default: stack.append(.unknown)
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer.append(string)
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        characterBuffer.append(String(decoding: CDATABlock, as: UTF8.self))
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        defer { characterBuffer = "" }
        let text = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let localName = stripPrefix(elementName)

        // Popping first hands us the only reference to the closing frame's value, and
        // leaves its parent on top of the stack.
        guard let frame = stack.popLast() else { return }
        let parent = stack.count - 1

        switch frame {
        case .document, .unknown:
            break
        case .leaf:
            applyLeaf(elementName: localName, text: text)
        case .extensionElement(let hasChildren):
            // Wrappers contribute nothing themselves — their leaf descendants already folded.
            if !hasChildren {
                applyExtensionLeaf(qualifiedName: elementName, localName: localName, text: text)
            }
        case .garminTrackPointExtension(let inner):
            mergeIntoEnclosingExtensions(inner)
        case .extensions(let extensions):
            // An `<extensions>` block that carried nothing is treated as absent, matching
            // the serializer, which never emits an empty block.
            guard !extensions.isEmpty else { return }
            switch stack[parent] {
            case .waypoint(var waypoint, let kind):
                waypoint.extensions = extensions
                stack[parent] = .waypoint(waypoint, kind: kind)
            case .route(var route):
                route.extensions = extensions
                stack[parent] = .route(route)
            case .track(var track):
                track.extensions = extensions
                stack[parent] = .track(track)
            case .trackSegment(var segment):
                segment.extensions = extensions
                stack[parent] = .trackSegment(segment)
            default:
                break
            }
        case .metadata(let metadata):
            document.metadata = metadata
        case .author(let person):
            if case .metadata(var metadata) = stack[parent] {
                metadata.author = person
                stack[parent] = .metadata(metadata)
            }
        case .copyright(let copyright):
            if case .metadata(var metadata) = stack[parent] {
                metadata.copyright = copyright
                stack[parent] = .metadata(metadata)
            }
        case .link(let link):
            attach(link: link, toFrameAt: parent)
        case .waypoint(let waypoint, .waypoint):
            document.waypoints.append(waypoint)
        // The point arrays below are large. Each parent frame is overwritten with a
        // placeholder before appending so the array is uniquely referenced and grows in
        // place — otherwise every point would copy the whole array (quadratic parse time).
        case .waypoint(let waypoint, .routePoint):
            if case .route(var route) = stack[parent] {
                stack[parent] = .unknown
                route.points.append(waypoint)
                stack[parent] = .route(route)
            }
        case .waypoint(let waypoint, .trackPoint):
            if case .trackSegment(var segment) = stack[parent] {
                stack[parent] = .unknown
                segment.points.append(waypoint)
                stack[parent] = .trackSegment(segment)
            }
        case .route(let route):
            document.routes.append(route)
        case .track(let track):
            document.tracks.append(track)
        case .trackSegment(let segment):
            if case .track(var track) = stack[parent] {
                stack[parent] = .unknown
                track.segments.append(segment)
                stack[parent] = .track(track)
            }
        }
    }

    // MARK: - Element starts

    private func startRoot(
        _ elementName: String, localName: String, attributes: [String: String], parser: XMLParser
    ) {
        guard localName == "gpx" else {
            error = .malformedXML(
                line: parser.lineNumber,
                message: "root element is <\(elementName)>, expected <gpx>"
            )
            parser.abortParsing()
            return
        }
        // Accept 1.0 and 1.1; a missing version attribute is treated as 1.1.
        // Anything else is a structural failure — abort with unsupportedVersion.
        if let version = attributes["version"] {
            guard version == "1.0" || version == "1.1" else {
                error = .unsupportedVersion(version)
                parser.abortParsing()
                return
            }
            document.version = version
        }
        if let creator = attributes["creator"] { document.creator = creator }
        harvestNamespaces(attributes)
        foundRoot = true
        stack.append(.document)
    }

    private func startWaypoint(
        _ kind: WaypointKind, element: String, attributes: [String: String], parser: XMLParser
    ) {
        guard let coord = parseCoord(attributes, element: element) else {
            parser.abortParsing()
            return
        }
        stack.append(.waypoint(GPXWaypoint(latitude: coord.lat, longitude: coord.lon), kind: kind))
    }

    private func startLink(_ attributes: [String: String]) {
        if let href = attributes["href"] {
            stack.append(.link(GPXLink(href: href)))
        } else {
            stack.append(.unknown)
        }
    }

    // MARK: - Leaf folding

    /// Folds a closed leaf element into the frame on top of the stack (its parent).
    private func applyLeaf(elementName: String, text: String) {
        // Empty text is allowed through: `<name></name>` round-trips as an empty string,
        // and numeric/date leaves naturally fall out as nil via the failable conversions.
        guard let top = stack.last else { return }
        let index = stack.count - 1

        switch top {
        case var .metadata(metadata):
            switch elementName {
            case "name": metadata.name = text
            case "desc": metadata.description = text
            case "time": metadata.time = GPXDateFormatter.date(from: text)
            case "keywords": metadata.keywords = text
            default: return
            }
            stack[index] = .metadata(metadata)
        case var .author(person):
            switch elementName {
            case "name": person.name = text
            default: return
            }
            stack[index] = .author(person)
        case var .copyright(copyright):
            switch elementName {
            case "year": copyright.year = parseInt(text)
            case "license": copyright.license = URL(string: text)
            default: return
            }
            stack[index] = .copyright(copyright)
        case var .link(link):
            switch elementName {
            case "text": link.text = text
            case "type": link.type = text
            default: return
            }
            stack[index] = .link(link)
        case .waypoint(var waypoint, let kind):
            apply(leaf: elementName, value: text, to: &waypoint)
            stack[index] = .waypoint(waypoint, kind: kind)
        case var .route(route):
            switch elementName {
            case "name": route.name = text
            case "cmt": route.comment = text
            case "desc": route.description = text
            case "src": route.source = text
            case "number": route.number = parseInt(text)
            case "type": route.type = text
            default: return
            }
            stack[index] = .route(route)
        case var .track(track):
            switch elementName {
            case "name": track.name = text
            case "cmt": track.comment = text
            case "desc": track.description = text
            case "src": track.source = text
            case "number": track.number = parseInt(text)
            case "type": track.type = text
            default: return
            }
            stack[index] = .track(track)
        default:
            break
        }
    }

    private func apply(leaf name: String, value: String, to point: inout GPXWaypoint) {
        switch name {
        case "ele": point.elevation = parseDouble(value)
        case "time": point.time = GPXDateFormatter.date(from: value)
        case "magvar": point.magneticVariation = parseDouble(value)
        case "geoidheight": point.geoidHeight = parseDouble(value)
        case "name": point.name = value
        case "cmt": point.comment = value
        case "desc": point.description = value
        case "src": point.source = value
        case "sym": point.symbol = value
        case "type": point.type = value
        case "fix": point.fix = GPXFix(rawValue: value)
        case "sat": point.satellites = parseInt(value)
        case "hdop": point.horizontalDilution = parseDouble(value)
        case "vdop": point.verticalDilution = parseDouble(value)
        case "pdop": point.positionDilution = parseDouble(value)
        case "ageofdgpsdata": point.ageOfDGPSData = parseDouble(value)
        case "dgpsid": point.dgpsId = parseInt(value)
        default: break
        }
    }

    // MARK: - Extensions

    /// Folds a childless element from inside `<extensions>` into the nearest enclosing
    /// extensions frame — the Garmin TrackPointExtension wrapper if one is open, otherwise
    /// the `<extensions>` block itself.
    private func applyExtensionLeaf(qualifiedName: String, localName: String, text: String) {
        guard let index = stack.lastIndex(where: {
            switch $0 {
            case .extensions, .garminTrackPointExtension: return true
            default: return false
            }
        }) else { return }

        switch stack[index] {
        case .extensions(var extensions):
            // Aliases cover bare tags from Strava generic extensions and COROS exports:
            // `heartrate` → heartRate, `temperature` → airTemperature. `temp` stays mapped
            // to waterTemperature for ClueTrust GPXData compatibility.
            fold(qualifiedName: qualifiedName, localName: localName, text: text,
                 into: &extensions, acceptsBareAliases: true)
            stack[index] = .extensions(extensions)
        case .garminTrackPointExtension(var extensions):
            fold(qualifiedName: qualifiedName, localName: localName, text: text,
                 into: &extensions, acceptsBareAliases: false)
            stack[index] = .garminTrackPointExtension(extensions)
        default:
            break
        }
    }

    /// Sets the typed field a known extension element maps to. Anything else — an unknown
    /// element, or a known one whose text isn't a usable number — is kept verbatim in
    /// `custom` so no extension data is silently dropped.
    private func fold(
        qualifiedName: String, localName: String, text: String,
        into extensions: inout GPXExtensions, acceptsBareAliases: Bool
    ) {
        func set<Value>(_ keyPath: WritableKeyPath<GPXExtensions, Value?>, _ value: Value?) {
            if let value {
                extensions[keyPath: keyPath] = value
            } else if !text.isEmpty {
                extensions.custom.append(GPXCustomExtension(qualifiedName: qualifiedName, value: text))
            }
        }

        switch localName {
        case "hr": set(\.heartRate, parseInt(text))
        case "cad", "cadence": set(\.cadence, parseInt(text))
        case "atemp": set(\.airTemperature, parseDouble(text))
        case "wtemp", "temp": set(\.waterTemperature, parseDouble(text))
        case "depth": set(\.depth, parseDouble(text))
        case "speed": set(\.speed, parseDouble(text))
        case "course": set(\.course, parseDouble(text))
        case "bearing": set(\.bearing, parseDouble(text))
        case "heartrate" where acceptsBareAliases: set(\.heartRate, parseInt(text))
        case "temperature" where acceptsBareAliases: set(\.airTemperature, parseDouble(text))
        case "power" where acceptsBareAliases: set(\.power, parseDouble(text))
        default:
            extensions.custom.append(GPXCustomExtension(qualifiedName: qualifiedName, value: text))
        }
    }

    /// Merges a closed Garmin TrackPointExtension wrapper into its `<extensions>` block.
    /// Values set directly on the block win over the wrapper's.
    private func mergeIntoEnclosingExtensions(_ inner: GPXExtensions) {
        guard let index = stack.lastIndex(where: {
            if case .extensions = $0 { return true }
            return false
        }), case .extensions(var merged) = stack[index] else { return }

        merged.heartRate = merged.heartRate ?? inner.heartRate
        merged.cadence = merged.cadence ?? inner.cadence
        merged.airTemperature = merged.airTemperature ?? inner.airTemperature
        merged.waterTemperature = merged.waterTemperature ?? inner.waterTemperature
        merged.depth = merged.depth ?? inner.depth
        merged.speed = merged.speed ?? inner.speed
        merged.course = merged.course ?? inner.course
        merged.bearing = merged.bearing ?? inner.bearing
        merged.custom.append(contentsOf: inner.custom)
        stack[index] = .extensions(merged)
    }

    // MARK: - Helpers

    /// Namespaces the library declares itself on output; harvesting them would duplicate
    /// the declarations.
    private static let managedNamespaceURIs: Set<String> = [
        "http://www.topografix.com/GPX/1/0",
        "http://www.topografix.com/GPX/1/1",
        "http://www.w3.org/2001/XMLSchema-instance",
        GPXSerializer.garminV1Namespace,
        GPXSerializer.garminV2Namespace,
    ]

    private func harvestNamespaces(_ attributes: [String: String]) {
        for (key, uri) in attributes where key.hasPrefix("xmlns:") {
            guard !Self.managedNamespaceURIs.contains(uri) else { continue }
            document.namespaces[String(key.dropFirst("xmlns:".count))] = uri
        }
    }

    private func stripPrefix(_ name: String) -> String {
        if let colon = name.firstIndex(of: ":") {
            return String(name[name.index(after: colon)...])
        }
        return name
    }

    private func isGarminTrackPointExtensionElement(_ qualifiedName: String) -> Bool {
        // Accept any namespace prefix — Garmin GPX uses `gpxtpx:TrackPointExtension`,
        // but third-party producers sometimes use a different prefix or none.
        stripPrefix(qualifiedName) == "TrackPointExtension"
    }

    /// Parses a finite number. `Double.init` also accepts "nan" and "inf", which GPX can't
    /// represent and the serializer would refuse to write back, so those become nil.
    private func parseDouble(_ text: String?) -> Double? {
        guard let text, let value = Double(text.trimmingCharacters(in: .whitespaces)),
              value.isFinite else { return nil }
        return value
    }

    /// Parses an integer, tolerating producers that write integral fields as decimals
    /// (`<hr>72.0</hr>`).
    private func parseInt(_ text: String) -> Int? {
        if let value = Int(text) { return value }
        guard let value = parseDouble(text) else { return nil }
        return Int(exactly: value.rounded())
    }

    private func parseCoord(_ attributes: [String: String], element: String) -> (lat: Double, lon: Double)? {
        guard let latString = attributes["lat"] else {
            error = .missingRequiredAttribute(element: element, attribute: "lat")
            return nil
        }
        guard let lonString = attributes["lon"] else {
            error = .missingRequiredAttribute(element: element, attribute: "lon")
            return nil
        }
        guard let lat = parseDouble(latString) else {
            error = .invalidCoordinate(latString)
            return nil
        }
        guard let lon = parseDouble(lonString) else {
            error = .invalidCoordinate(lonString)
            return nil
        }
        return (lat, lon)
    }

    private func attach(link: GPXLink, toFrameAt index: Int) {
        switch stack[index] {
        case .metadata(var metadata):
            metadata.links.append(link)
            stack[index] = .metadata(metadata)
        case .author(var person):
            person.link = link
            stack[index] = .author(person)
        case .waypoint(var waypoint, let kind):
            waypoint.links.append(link)
            stack[index] = .waypoint(waypoint, kind: kind)
        case .route(var route):
            route.links.append(link)
            stack[index] = .route(route)
        case .track(var track):
            track.links.append(link)
            stack[index] = .track(track)
        default:
            break
        }
    }
}
