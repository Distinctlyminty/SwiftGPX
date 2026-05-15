#if canImport(CoreLocation)
import CoreLocation
import Foundation

extension GPXDocument {
    /// Builds a single-track GPX document from a `[CLLocation]` recording, with an optional
    /// heart-rate hook applied to each track point.
    ///
    /// - Parameters:
    ///   - locations: Ordered samples from a recorded workout.
    ///   - creator: Application name embedded in the root `<gpx creator=...>` attribute.
    ///   - name: Optional `<trk><name>` value.
    ///   - heartRateAt: Closure called per location with the location's `timestamp`. Return
    ///     a BPM value to embed it as a Garmin TrackPointExtension `<hr>` element, or `nil`
    ///     to omit. The closure may keep state between calls if you want to binary-search
    ///     a sorted sample list (recommended for long workouts).
    public static func track(
        from locations: [CLLocation],
        creator: String = "SwiftGPX",
        name: String? = nil,
        heartRateAt: (Date) -> Int? = { _ in nil }
    ) -> GPXDocument {
        var segment = GPXTrackSegment()
        segment.points.reserveCapacity(locations.count)
        for location in locations {
            var point = GPXWaypoint(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                elevation: location.verticalAccuracy >= 0 ? location.altitude : nil,
                time: location.timestamp
            )
            if let bpm = heartRateAt(location.timestamp) {
                point.extensions = GPXExtensions(heartRate: bpm)
            }
            segment.points.append(point)
        }
        let track = GPXTrack(name: name, segments: [segment])
        return GPXDocument(creator: creator, tracks: [track])
    }
}
#endif
