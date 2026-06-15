import Foundation

/// A problem found by ``GPXDocument/validate()`` or ``GPXDocument/validateForStrava()``.
///
/// `path` locates the offending value in the document, e.g.
/// `"tracks[0].segments[1].points[42]"`.
public enum GPXValidationIssue: Sendable, Equatable, CustomStringConvertible {
    case latitudeOutOfRange(value: Double, path: String)
    case longitudeOutOfRange(value: Double, path: String)
    case nonFiniteValue(element: String, path: String)
    case missingTrackPointTime(track: Int, segment: Int, point: Int)
    case nonMonotonicTime(track: Int, segment: Int, point: Int)
    case emptyDocument

    public var description: String {
        switch self {
        case let .latitudeOutOfRange(value, path):
            return "Latitude \(value) at \(path) is outside -90...90."
        case let .longitudeOutOfRange(value, path):
            return "Longitude \(value) at \(path) is outside -180...180."
        case let .nonFiniteValue(element, path):
            return "<\(element)> at \(path) is not a finite number."
        case let .missingTrackPointTime(track, segment, point):
            return "tracks[\(track)].segments[\(segment)].points[\(point)] has no <time> — required for Strava upload."
        case let .nonMonotonicTime(track, segment, point):
            return "tracks[\(track)].segments[\(segment)].points[\(point)] has a timestamp earlier than the previous point."
        case .emptyDocument:
            return "The document contains no waypoints, routes, or track points."
        }
    }
}

extension GPXDocument {
    /// Checks structural validity — everything ``GPXSerializer`` would reject, found in
    /// one pass so a UI can report all problems at once instead of failing on the first.
    public func validate() -> [GPXValidationIssue] {
        var issues: [GPXValidationIssue] = []

        if waypoints.isEmpty && routes.isEmpty && tracks.isEmpty {
            issues.append(.emptyDocument)
        }

        for (index, waypoint) in waypoints.enumerated() {
            check(waypoint, path: "waypoints[\(index)]", into: &issues)
        }
        for (routeIndex, route) in routes.enumerated() {
            for (pointIndex, point) in route.points.enumerated() {
                check(point, path: "routes[\(routeIndex)].points[\(pointIndex)]", into: &issues)
            }
        }
        for (trackIndex, track) in tracks.enumerated() {
            for (segmentIndex, segment) in track.segments.enumerated() {
                for (pointIndex, point) in segment.points.enumerated() {
                    check(
                        point,
                        path: "tracks[\(trackIndex)].segments[\(segmentIndex)].points[\(pointIndex)]",
                        into: &issues
                    )
                }
            }
        }

        if let bounds = metadata?.bounds {
            checkLatitude(bounds.minLatitude, path: "metadata.bounds.minlat", into: &issues)
            checkLongitude(bounds.minLongitude, path: "metadata.bounds.minlon", into: &issues)
            checkLatitude(bounds.maxLatitude, path: "metadata.bounds.maxlat", into: &issues)
            checkLongitude(bounds.maxLongitude, path: "metadata.bounds.maxlon", into: &issues)
        }

        return issues
    }

    /// ``validate()`` plus Strava's upload requirements: at least one track point, a
    /// `<time>` on every track point, and timestamps that never go backwards within a
    /// segment. Run this before exporting a workout for upload.
    public func validateForStrava() -> [GPXValidationIssue] {
        var issues = validate()

        var hasTrackPoints = false
        for (trackIndex, track) in tracks.enumerated() {
            for (segmentIndex, segment) in track.segments.enumerated() {
                var previousTime: Date?
                for (pointIndex, point) in segment.points.enumerated() {
                    hasTrackPoints = true
                    guard let time = point.time else {
                        issues.append(.missingTrackPointTime(
                            track: trackIndex, segment: segmentIndex, point: pointIndex
                        ))
                        continue
                    }
                    if let previous = previousTime, time < previous {
                        issues.append(.nonMonotonicTime(
                            track: trackIndex, segment: segmentIndex, point: pointIndex
                        ))
                    }
                    previousTime = time
                }
            }
        }
        if !hasTrackPoints && !issues.contains(.emptyDocument) {
            issues.append(.emptyDocument)
        }
        return issues
    }

    // MARK: - Per-value checks

    private func check(_ point: GPXWaypoint, path: String, into issues: inout [GPXValidationIssue]) {
        checkLatitude(point.latitude, path: path, into: &issues)
        checkLongitude(point.longitude, path: path, into: &issues)

        let numericFields: [(String, Double?)] = [
            ("ele", point.elevation),
            ("magvar", point.magneticVariation),
            ("geoidheight", point.geoidHeight),
            ("hdop", point.horizontalDilution),
            ("vdop", point.verticalDilution),
            ("pdop", point.positionDilution),
            ("ageofdgpsdata", point.ageOfDGPSData),
            ("atemp", point.extensions?.airTemperature),
            ("wtemp", point.extensions?.waterTemperature),
            ("depth", point.extensions?.depth),
            ("speed", point.extensions?.speed),
            ("course", point.extensions?.course),
            ("bearing", point.extensions?.bearing),
            ("power", point.extensions?.power),
        ]
        for (element, value) in numericFields {
            if let value, !value.isFinite {
                issues.append(.nonFiniteValue(element: element, path: path))
            }
        }
    }

    private func checkLatitude(_ value: Double, path: String, into issues: inout [GPXValidationIssue]) {
        if !value.isFinite {
            issues.append(.nonFiniteValue(element: "lat", path: path))
        } else if !(-90.0...90.0).contains(value) {
            issues.append(.latitudeOutOfRange(value: value, path: path))
        }
    }

    private func checkLongitude(_ value: Double, path: String, into issues: inout [GPXValidationIssue]) {
        if !value.isFinite {
            issues.append(.nonFiniteValue(element: "lon", path: path))
        } else if !(-180.0...180.0).contains(value) {
            issues.append(.longitudeOutOfRange(value: value, path: path))
        }
    }
}
