import Foundation

/// Summary statistics computed from track points.
public struct GPXTrackStatistics: Sendable, Equatable {
    /// Total point-to-point haversine distance in meters.
    public var distance: Double

    /// Elapsed time between the first and last timestamped points, or `nil` when fewer
    /// than two points carry timestamps.
    public var duration: TimeInterval?

    /// Time spent moving — the sum of intervals whose average speed met the threshold.
    /// `nil` when no consecutive pair of points carries timestamps.
    public var movingTime: TimeInterval?

    /// Sum of positive elevation deltas, in meters. Points without elevation are skipped.
    public var elevationGain: Double

    /// Sum of negative elevation deltas, expressed as a positive number of meters.
    public var elevationLoss: Double

    /// Number of track points the statistics were computed over.
    public var pointCount: Int

    public init(
        distance: Double = 0, duration: TimeInterval? = nil, movingTime: TimeInterval? = nil,
        elevationGain: Double = 0, elevationLoss: Double = 0, pointCount: Int = 0
    ) {
        self.distance = distance
        self.duration = duration
        self.movingTime = movingTime
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.pointCount = pointCount
    }
}

extension GPXTrackSegment {
    /// Computes distance, duration, moving time, and elevation gain/loss for this segment.
    ///
    /// - Parameter movingSpeedThreshold: Minimum average speed in m/s for an interval to
    ///   count as moving. The 0.5 default suits paddling, where drift is slow.
    public func statistics(movingSpeedThreshold: Double = 0.5) -> GPXTrackStatistics {
        var stats = GPXTrackStatistics(pointCount: points.count)
        var firstTime: Date?
        var lastTime: Date?
        var timestampedCount = 0
        var lastElevation: Double?
        var hasTimedInterval = false
        var movingTime: TimeInterval = 0

        for (index, point) in points.enumerated() {
            if let time = point.time {
                if firstTime == nil { firstTime = time }
                lastTime = time
                timestampedCount += 1
            }
            if let elevation = point.elevation {
                if let last = lastElevation {
                    let delta = elevation - last
                    if delta > 0 { stats.elevationGain += delta } else { stats.elevationLoss -= delta }
                }
                lastElevation = elevation
            }
            guard index > 0 else { continue }
            let previous = points[index - 1]
            let stepDistance = previous.distance(to: point)
            stats.distance += stepDistance
            if let start = previous.time, let end = point.time {
                let interval = end.timeIntervalSince(start)
                if interval > 0 {
                    hasTimedInterval = true
                    if stepDistance / interval >= movingSpeedThreshold {
                        movingTime += interval
                    }
                }
            }
        }

        if timestampedCount >= 2, let firstTime, let lastTime {
            stats.duration = lastTime.timeIntervalSince(firstTime)
        }
        if hasTimedInterval {
            stats.movingTime = movingTime
        }
        return stats
    }
}

extension GPXTrack {
    /// Computes statistics across all segments.
    ///
    /// Distance, elevation gain/loss, and point count are summed. `duration` is the
    /// elapsed time from the first to the last timestamped point in the track (pauses
    /// between segments included); `movingTime` sums the per-segment values, so
    /// inter-segment gaps never count as moving.
    public func statistics(movingSpeedThreshold: Double = 0.5) -> GPXTrackStatistics {
        var total = GPXTrackStatistics()
        var firstTime: Date?
        var lastTime: Date?
        var timestampedCount = 0

        for segment in segments {
            let stats = segment.statistics(movingSpeedThreshold: movingSpeedThreshold)
            total.distance += stats.distance
            total.elevationGain += stats.elevationGain
            total.elevationLoss += stats.elevationLoss
            total.pointCount += stats.pointCount
            if let moving = stats.movingTime {
                total.movingTime = (total.movingTime ?? 0) + moving
            }
            for point in segment.points {
                guard let time = point.time else { continue }
                if firstTime == nil { firstTime = time }
                lastTime = time
                timestampedCount += 1
            }
        }

        if timestampedCount >= 2, let firstTime, let lastTime {
            total.duration = lastTime.timeIntervalSince(firstTime)
        }
        return total
    }

    /// A copy of this track with all segments concatenated into one, in order.
    ///
    /// Useful before Strava upload when segment breaks (GPS dropouts) would otherwise
    /// split a workout. The merged segment keeps the first non-nil segment-level
    /// extensions; the rest are dropped.
    public func mergingSegments() -> GPXTrack {
        guard segments.count > 1 else { return self }
        var merged = GPXTrackSegment()
        merged.points = segments.flatMap(\.points)
        merged.extensions = segments.lazy.compactMap(\.extensions).first
        var track = self
        track.segments = [merged]
        return track
    }
}
