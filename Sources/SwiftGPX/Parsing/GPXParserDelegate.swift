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

    private var stack: [Frame] = []
    private var characterBuffer: String = ""

    // MARK: - Frame model

    private enum Frame {
        case document
        case metadata(GPXMetadata)
        case author(GPXPerson)
        case copyright(GPXCopyright)
        case link(GPXLink, parent: LinkParent)
        case waypoint(GPXWaypoint, kind: WaypointKind)
        case route(GPXRoute)
        case track(GPXTrack)
        case trackSegment(GPXTrackSegment)
        case extensions(GPXExtensions, parent: ExtensionsParent)
        case garminTrackPointExtension(GPXExtensions, parent: ExtensionsParent)
        case unknown
    }

    private enum WaypointKind { case waypoint, routePoint, trackPoint }

    private enum LinkParent {
        case metadata
        case author
        case waypoint
        case route
        case track
    }

    private enum ExtensionsParent {
        case waypoint
        case route
        case track
        case trackSegment
    }

    // MARK: - XMLParserDelegate

    func parserDidStartDocument(_ parser: XMLParser) {
        stack = [.document]
    }

    func parser(
        _ parser: XMLParser, didStartElement elementName: String,
        namespaceURI: String?, qualifiedName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        flushCharacters()
        characterBuffer = ""

        let localName = stripPrefix(elementName)

        // Garmin/ClueTrust extensions: handled regardless of namespace prefix.
        if case let .extensions(extensions, parent) = stack.last,
           isGarminTrackPointExtensionElement(elementName) {
            stack[stack.count - 1] = .extensions(extensions, parent: parent)
            stack.append(.garminTrackPointExtension(GPXExtensions(), parent: parent))
            return
        }
        if case let .garminTrackPointExtension(extensions, parent) = stack.last {
            // Children of TrackPointExtension are simple leaf elements; let foundCharacters
            // accumulate text and fold in didEndElement.
            stack[stack.count - 1] = .garminTrackPointExtension(extensions, parent: parent)
            return
        }

        switch localName {
        case "gpx":
            if let version = attributeDict["version"] { document.version = version }
            if let creator = attributeDict["creator"] { document.creator = creator }
        case "metadata":
            stack.append(.metadata(GPXMetadata()))
        case "author":
            if case .metadata = stack.last { stack.append(.author(GPXPerson())) }
            else { stack.append(.unknown) }
        case "email":
            if case let .author(person) = stack.last,
               let id = attributeDict["id"], let domain = attributeDict["domain"] {
                var updated = person
                updated.email = "\(id)@\(domain)"
                stack[stack.count - 1] = .author(updated)
            }
        case "copyright":
            if let author = attributeDict["author"] {
                stack.append(.copyright(GPXCopyright(author: author)))
            } else {
                stack.append(.copyright(GPXCopyright(author: "")))
            }
        case "link":
            guard let href = attributeDict["href"] else {
                stack.append(.unknown)
                return
            }
            guard let parent = currentLinkParent() else {
                stack.append(.unknown)
                return
            }
            stack.append(.link(GPXLink(href: href), parent: parent))
        case "bounds":
            guard let metadata = currentMetadata() else { return }
            var updated = metadata
            updated.bounds = GPXBounds(
                minLatitude: Double(attributeDict["minlat"] ?? "") ?? 0,
                minLongitude: Double(attributeDict["minlon"] ?? "") ?? 0,
                maxLatitude: Double(attributeDict["maxlat"] ?? "") ?? 0,
                maxLongitude: Double(attributeDict["maxlon"] ?? "") ?? 0
            )
            replaceCurrentMetadata(updated)
        case "wpt":
            guard let coord = parseCoord(attributeDict, element: "wpt") else { return }
            stack.append(.waypoint(GPXWaypoint(latitude: coord.lat, longitude: coord.lon), kind: .waypoint))
        case "rte":
            stack.append(.route(GPXRoute()))
        case "rtept":
            guard let coord = parseCoord(attributeDict, element: "rtept") else { return }
            stack.append(.waypoint(GPXWaypoint(latitude: coord.lat, longitude: coord.lon), kind: .routePoint))
        case "trk":
            stack.append(.track(GPXTrack()))
        case "trkseg":
            stack.append(.trackSegment(GPXTrackSegment()))
        case "trkpt":
            guard let coord = parseCoord(attributeDict, element: "trkpt") else { return }
            stack.append(.waypoint(GPXWaypoint(latitude: coord.lat, longitude: coord.lon), kind: .trackPoint))
        case "extensions":
            guard let parent = currentExtensionsParent() else {
                stack.append(.unknown)
                return
            }
            stack.append(.extensions(GPXExtensions(), parent: parent))
        default:
            // Plain leaf elements (`name`, `desc`, `ele`, `time`, ...) — no frame needed; we
            // catch them by name on the end-tag using the accumulated character buffer.
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        characterBuffer.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        defer { characterBuffer = "" }
        let text = characterBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        let localName = stripPrefix(elementName)

        // Drain Garmin TrackPointExtension children first, since they look like ordinary
        // leaf elements but live under our garminTrackPointExtension frame.
        if case .garminTrackPointExtension(var extensions, let parent) = stack.last {
            if isGarminTrackPointExtensionElement(elementName) {
                // Closing the TrackPointExtension wrapper itself.
                stack.removeLast()
                guard case let .extensions(outer, outerParent) = stack.last else { return }
                var merged = outer
                merged.heartRate = merged.heartRate ?? extensions.heartRate
                merged.cadence = merged.cadence ?? extensions.cadence
                merged.airTemperature = merged.airTemperature ?? extensions.airTemperature
                merged.waterTemperature = merged.waterTemperature ?? extensions.waterTemperature
                merged.depth = merged.depth ?? extensions.depth
                merged.speed = merged.speed ?? extensions.speed
                merged.course = merged.course ?? extensions.course
                merged.bearing = merged.bearing ?? extensions.bearing
                stack[stack.count - 1] = .extensions(merged, parent: outerParent)
                return
            }
            switch localName {
            case "hr": extensions.heartRate = Int(text)
            case "cad", "cadence": extensions.cadence = Int(text)
            case "atemp": extensions.airTemperature = Double(text)
            case "wtemp", "temp": extensions.waterTemperature = Double(text)
            case "depth": extensions.depth = Double(text)
            case "speed": extensions.speed = Double(text)
            case "course": extensions.course = Double(text)
            case "bearing": extensions.bearing = Double(text)
            default:
                if !text.isEmpty {
                    extensions.custom.append(GPXCustomExtension(qualifiedName: elementName, value: text))
                }
            }
            stack[stack.count - 1] = .garminTrackPointExtension(extensions, parent: parent)
            return
        }

        // <extensions> own leaf children (no Garmin wrapper).
        if case .extensions(var extensions, let parent) = stack.last {
            switch localName {
            case "extensions":
                stack.removeLast()
                attach(extensions: extensions, to: parent)
                return
            case "hr": extensions.heartRate = Int(text)
            case "cad", "cadence": extensions.cadence = Int(text)
            case "atemp": extensions.airTemperature = Double(text)
            case "wtemp", "temp": extensions.waterTemperature = Double(text)
            case "depth": extensions.depth = Double(text)
            case "speed": extensions.speed = Double(text)
            case "course": extensions.course = Double(text)
            case "bearing": extensions.bearing = Double(text)
            case "power": extensions.power = Double(text)
            default:
                if !text.isEmpty {
                    extensions.custom.append(GPXCustomExtension(qualifiedName: elementName, value: text))
                }
            }
            stack[stack.count - 1] = .extensions(extensions, parent: parent)
            return
        }

        // Top-of-stack frame closures.
        switch (localName, stack.last) {
        case ("metadata", .metadata(let metadata)?):
            stack.removeLast()
            document.metadata = metadata
            return
        case ("author", .author(let person)?):
            stack.removeLast()
            if let parent = currentMetadata() {
                var updated = parent
                updated.author = person
                replaceCurrentMetadata(updated)
            }
            return
        case ("copyright", .copyright(let copyright)?):
            stack.removeLast()
            if let parent = currentMetadata() {
                var updated = parent
                updated.copyright = copyright
                replaceCurrentMetadata(updated)
            }
            return
        case ("link", .link(let link, let parent)?):
            stack.removeLast()
            attach(link: link, to: parent)
            return
        case ("wpt", .waypoint(let waypoint, .waypoint)?):
            stack.removeLast()
            document.waypoints.append(waypoint)
            return
        case ("rtept", .waypoint(let waypoint, .routePoint)?):
            stack.removeLast()
            if case var .route(route) = stack.last {
                route.points.append(waypoint)
                stack[stack.count - 1] = .route(route)
            }
            return
        case ("trkpt", .waypoint(let waypoint, .trackPoint)?):
            stack.removeLast()
            if case var .trackSegment(segment) = stack.last {
                segment.points.append(waypoint)
                stack[stack.count - 1] = .trackSegment(segment)
            }
            return
        case ("rte", .route(let route)?):
            stack.removeLast()
            document.routes.append(route)
            return
        case ("trk", .track(let track)?):
            stack.removeLast()
            document.tracks.append(track)
            return
        case ("trkseg", .trackSegment(let segment)?):
            stack.removeLast()
            if case var .track(track) = stack.last {
                track.segments.append(segment)
                stack[stack.count - 1] = .track(track)
            }
            return
        default:
            break
        }

        if localName == "gpx" { return }

        // Leaf element belonging to the current open frame.
        applyLeaf(elementName: localName, text: text)

        // Any other stack frame (unknown wrapper) just pops away when its tag closes.
        if case .unknown = stack.last, !isLeafElement(localName) {
            stack.removeLast()
        }
    }

    // MARK: - Leaf folding

    private func applyLeaf(elementName: String, text: String) {
        guard !text.isEmpty || elementName == "year" else { return }
        guard let top = stack.last else { return }

        switch top {
        case var .metadata(metadata):
            switch elementName {
            case "name": metadata.name = text
            case "desc": metadata.description = text
            case "time": metadata.time = GPXDateFormatter.date(from: text)
            case "keywords": metadata.keywords = text
            default: return
            }
            stack[stack.count - 1] = .metadata(metadata)
        case var .author(person):
            switch elementName {
            case "name": person.name = text
            default: return
            }
            stack[stack.count - 1] = .author(person)
        case var .copyright(copyright):
            switch elementName {
            case "year": copyright.year = Int(text)
            case "license": copyright.license = URL(string: text)
            default: return
            }
            stack[stack.count - 1] = .copyright(copyright)
        case .link(var link, let parent):
            switch elementName {
            case "text": link.text = text
            case "type": link.type = text
            default: return
            }
            stack[stack.count - 1] = .link(link, parent: parent)
        case .waypoint(var waypoint, let kind):
            apply(leaf: elementName, value: text, to: &waypoint)
            stack[stack.count - 1] = .waypoint(waypoint, kind: kind)
        case var .route(route):
            apply(leafToTrackOrRoute: elementName, value: text, to: &route)
            stack[stack.count - 1] = .route(route)
        case var .track(track):
            apply(leafToTrackOrRoute: elementName, value: text, to: &track)
            stack[stack.count - 1] = .track(track)
        default:
            _ = top
        }
    }

    private func apply(leaf name: String, value: String, to point: inout GPXWaypoint) {
        switch name {
        case "ele": point.elevation = Double(value)
        case "time": point.time = GPXDateFormatter.date(from: value)
        case "magvar": point.magneticVariation = Double(value)
        case "geoidheight": point.geoidHeight = Double(value)
        case "name": point.name = value
        case "cmt": point.comment = value
        case "desc": point.description = value
        case "src": point.source = value
        case "sym": point.symbol = value
        case "type": point.type = value
        case "fix": point.fix = GPXFix(rawValue: value)
        case "sat": point.satellites = Int(value)
        case "hdop": point.horizontalDilution = Double(value)
        case "vdop": point.verticalDilution = Double(value)
        case "pdop": point.positionDilution = Double(value)
        case "ageofdgpsdata": point.ageOfDGPSData = Double(value)
        case "dgpsid": point.dgpsId = Int(value)
        default: break
        }
    }

    private func apply<T>(leafToTrackOrRoute name: String, value: String, to container: inout T) {
        if var route = container as? GPXRoute {
            switch name {
            case "name": route.name = value
            case "cmt": route.comment = value
            case "desc": route.description = value
            case "src": route.source = value
            case "number": route.number = Int(value)
            case "type": route.type = value
            default: return
            }
            container = route as! T
        } else if var track = container as? GPXTrack {
            switch name {
            case "name": track.name = value
            case "cmt": track.comment = value
            case "desc": track.description = value
            case "src": track.source = value
            case "number": track.number = Int(value)
            case "type": track.type = value
            default: return
            }
            container = track as! T
        }
    }

    // MARK: - Helpers

    private func flushCharacters() {}

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

    private func isLeafElement(_ localName: String) -> Bool {
        switch localName {
        case "name", "desc", "ele", "time", "magvar", "geoidheight", "cmt", "src",
             "sym", "type", "fix", "sat", "hdop", "vdop", "pdop", "ageofdgpsdata",
             "dgpsid", "number", "keywords", "year", "license", "text":
            return true
        default:
            return false
        }
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
        guard let lat = Double(latString) else {
            error = .invalidCoordinate(latString)
            return nil
        }
        guard let lon = Double(lonString) else {
            error = .invalidCoordinate(lonString)
            return nil
        }
        return (lat, lon)
    }

    private func currentMetadata() -> GPXMetadata? {
        for frame in stack.reversed() {
            if case let .metadata(metadata) = frame { return metadata }
        }
        return nil
    }

    private func replaceCurrentMetadata(_ updated: GPXMetadata) {
        for index in stride(from: stack.count - 1, through: 0, by: -1) {
            if case .metadata = stack[index] {
                stack[index] = .metadata(updated)
                return
            }
        }
    }

    private func currentLinkParent() -> LinkParent? {
        for frame in stack.reversed() {
            switch frame {
            case .metadata: return .metadata
            case .author: return .author
            case .waypoint: return .waypoint
            case .route: return .route
            case .track: return .track
            default: continue
            }
        }
        return nil
    }

    private func currentExtensionsParent() -> ExtensionsParent? {
        for frame in stack.reversed() {
            switch frame {
            case .waypoint: return .waypoint
            case .route: return .route
            case .track: return .track
            case .trackSegment: return .trackSegment
            default: continue
            }
        }
        return nil
    }

    private func attach(link: GPXLink, to parent: LinkParent) {
        switch parent {
        case .metadata:
            if let metadata = currentMetadata() {
                var updated = metadata
                updated.links.append(link)
                replaceCurrentMetadata(updated)
            }
        case .author:
            for index in stride(from: stack.count - 1, through: 0, by: -1) {
                if case var .author(person) = stack[index] {
                    person.link = link
                    stack[index] = .author(person)
                    return
                }
            }
        case .waypoint:
            for index in stride(from: stack.count - 1, through: 0, by: -1) {
                if case .waypoint(var waypoint, let kind) = stack[index] {
                    waypoint.links.append(link)
                    stack[index] = .waypoint(waypoint, kind: kind)
                    return
                }
            }
        case .route:
            for index in stride(from: stack.count - 1, through: 0, by: -1) {
                if case var .route(route) = stack[index] {
                    route.links.append(link)
                    stack[index] = .route(route)
                    return
                }
            }
        case .track:
            for index in stride(from: stack.count - 1, through: 0, by: -1) {
                if case var .track(track) = stack[index] {
                    track.links.append(link)
                    stack[index] = .track(track)
                    return
                }
            }
        }
    }

    private func attach(extensions: GPXExtensions, to parent: ExtensionsParent) {
        switch parent {
        case .waypoint:
            for index in stride(from: stack.count - 1, through: 0, by: -1) {
                if case .waypoint(var waypoint, let kind) = stack[index] {
                    waypoint.extensions = extensions
                    stack[index] = .waypoint(waypoint, kind: kind)
                    return
                }
            }
        case .route:
            for index in stride(from: stack.count - 1, through: 0, by: -1) {
                if case var .route(route) = stack[index] {
                    route.extensions = extensions
                    stack[index] = .route(route)
                    return
                }
            }
        case .track:
            for index in stride(from: stack.count - 1, through: 0, by: -1) {
                if case var .track(track) = stack[index] {
                    track.extensions = extensions
                    stack[index] = .track(track)
                    return
                }
            }
        case .trackSegment:
            for index in stride(from: stack.count - 1, through: 0, by: -1) {
                if case var .trackSegment(segment) = stack[index] {
                    segment.extensions = extensions
                    stack[index] = .trackSegment(segment)
                    return
                }
            }
        }
    }
}
