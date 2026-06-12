import Foundation

/// Mean Earth radius in meters, as used by the haversine great-circle formula.
private let earthRadius = 6_371_000.0

extension GPXWaypoint {
    /// Great-circle (haversine) distance to another point, in meters.
    ///
    /// Elevation is ignored. Accurate to ~0.5% (the spherical-Earth assumption), which
    /// is well inside GPS noise for workout-length distances.
    public func distance(to other: GPXWaypoint) -> Double {
        let lat1 = latitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let dLat = (other.latitude - latitude) * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180

        let h = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }
}

extension GPXBounds {
    /// The smallest bounding box containing every point, or `nil` for an empty sequence.
    public init?(containing points: some Sequence<GPXWaypoint>) {
        var iterator = points.makeIterator()
        guard let first = iterator.next() else { return nil }
        self.init(
            minLatitude: first.latitude, minLongitude: first.longitude,
            maxLatitude: first.latitude, maxLongitude: first.longitude
        )
        while let point = iterator.next() {
            minLatitude = Swift.min(minLatitude, point.latitude)
            minLongitude = Swift.min(minLongitude, point.longitude)
            maxLatitude = Swift.max(maxLatitude, point.latitude)
            maxLongitude = Swift.max(maxLongitude, point.longitude)
        }
    }

    /// Expands these bounds to also contain `other`.
    public mutating func formUnion(_ other: GPXBounds) {
        minLatitude = Swift.min(minLatitude, other.minLatitude)
        minLongitude = Swift.min(minLongitude, other.minLongitude)
        maxLatitude = Swift.max(maxLatitude, other.maxLatitude)
        maxLongitude = Swift.max(maxLongitude, other.maxLongitude)
    }
}

extension GPXTrackSegment {
    /// Bounding box of this segment's points, or `nil` if it has none.
    public var bounds: GPXBounds? {
        GPXBounds(containing: points)
    }
}

extension GPXTrack {
    /// Bounding box of every point in every segment, or `nil` for an empty track.
    public var bounds: GPXBounds? {
        GPXBounds(containing: segments.lazy.flatMap(\.points))
    }
}

extension GPXDocument {
    /// Bounding box of every waypoint, route point, and track point in the document,
    /// or `nil` if it contains no points.
    public var bounds: GPXBounds? {
        let all = waypoints
            + routes.flatMap(\.points)
            + tracks.flatMap { $0.segments.flatMap(\.points) }
        return GPXBounds(containing: all)
    }
}

// MARK: - Internal geometry used by simplification

/// Perpendicular distance in meters from `point` to the segment `lineStart`–`lineEnd`,
/// using an equirectangular projection around the line start. Accurate for the small
/// extents Douglas–Peucker operates over.
func perpendicularDistance(
    _ point: GPXWaypoint, lineStart: GPXWaypoint, lineEnd: GPXWaypoint
) -> Double {
    let cosLat = cos(lineStart.latitude * .pi / 180)
    func project(_ p: GPXWaypoint) -> (x: Double, y: Double) {
        (
            x: earthRadius * (p.longitude - lineStart.longitude) * .pi / 180 * cosLat,
            y: earthRadius * (p.latitude - lineStart.latitude) * .pi / 180
        )
    }
    let p = project(point)
    let end = project(lineEnd)

    let lengthSquared = end.x * end.x + end.y * end.y
    guard lengthSquared > 0 else {
        return (p.x * p.x + p.y * p.y).squareRoot()
    }
    let t = max(0, min(1, (p.x * end.x + p.y * end.y) / lengthSquared))
    let dx = p.x - t * end.x
    let dy = p.y - t * end.y
    return (dx * dx + dy * dy).squareRoot()
}
