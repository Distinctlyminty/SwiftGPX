import Foundation

extension GPXTrackSegment {
    /// Reduces the segment's point count with the Douglas–Peucker algorithm.
    ///
    /// Points whose perpendicular distance from the simplified line stays within
    /// `tolerance` (meters) are dropped; kept points retain all their values — times,
    /// extensions, everything. The first and last points are always kept. Typical
    /// tolerances: 5–10m preserves workout detail, 50m+ produces map overviews.
    ///
    /// The implementation is iterative (explicit stack), so 50k+-point recordings
    /// can't overflow the call stack.
    public func simplified(tolerance: Double) -> GPXTrackSegment {
        guard points.count > 2, tolerance > 0 else { return self }

        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true

        var ranges: [(start: Int, end: Int)] = [(0, points.count - 1)]
        while let (start, end) = ranges.popLast() {
            guard end > start + 1 else { continue }
            var maxDistance = 0.0
            var maxIndex = start
            for index in (start + 1)..<end {
                let distance = perpendicularDistance(
                    points[index], lineStart: points[start], lineEnd: points[end]
                )
                if distance > maxDistance {
                    maxDistance = distance
                    maxIndex = index
                }
            }
            if maxDistance > tolerance {
                keep[maxIndex] = true
                ranges.append((start, maxIndex))
                ranges.append((maxIndex, end))
            }
        }

        var result = self
        result.points = zip(points, keep).compactMap { point, kept in kept ? point : nil }
        return result
    }
}

extension GPXTrack {
    /// A copy of this track with every segment simplified. See
    /// ``GPXTrackSegment/simplified(tolerance:)``.
    public func simplified(tolerance: Double) -> GPXTrack {
        var track = self
        track.segments = segments.map { $0.simplified(tolerance: tolerance) }
        return track
    }
}
