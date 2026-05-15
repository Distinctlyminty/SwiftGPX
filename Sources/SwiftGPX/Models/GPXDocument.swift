import Foundation

/// A complete GPX 1.1 document — the value-type representation of an entire `.gpx` file.
///
/// All fields are public and mutable so a document can be built incrementally. Parsing
/// returns a `GPXDocument`; serialization consumes one.
public struct GPXDocument: Sendable, Codable, Equatable {
    /// GPX schema version. Fixed at `"1.1"` for documents this library produces.
    public var version: String

    /// Name of the application that produced the file.
    public var creator: String

    /// Top-level metadata describing the document as a whole.
    public var metadata: GPXMetadata?

    /// Standalone waypoints (`<wpt>` elements at the root level).
    public var waypoints: [GPXWaypoint]

    /// Planned routes (`<rte>` elements).
    public var routes: [GPXRoute]

    /// Recorded tracks (`<trk>` elements).
    public var tracks: [GPXTrack]

    public init(
        version: String = "1.1",
        creator: String,
        metadata: GPXMetadata? = nil,
        waypoints: [GPXWaypoint] = [],
        routes: [GPXRoute] = [],
        tracks: [GPXTrack] = []
    ) {
        self.version = version
        self.creator = creator
        self.metadata = metadata
        self.waypoints = waypoints
        self.routes = routes
        self.tracks = tracks
    }
}
