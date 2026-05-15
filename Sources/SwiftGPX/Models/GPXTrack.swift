import Foundation

/// An ordered list of one or more track segments representing a recorded path.
public struct GPXTrack: Sendable, Codable, Equatable {
    public var name: String?
    public var comment: String?
    public var description: String?
    public var source: String?
    public var links: [GPXLink]
    public var number: Int?
    public var type: String?
    public var segments: [GPXTrackSegment]
    public var extensions: GPXExtensions?

    public init(
        name: String? = nil,
        comment: String? = nil,
        description: String? = nil,
        source: String? = nil,
        links: [GPXLink] = [],
        number: Int? = nil,
        type: String? = nil,
        segments: [GPXTrackSegment] = [],
        extensions: GPXExtensions? = nil
    ) {
        self.name = name
        self.comment = comment
        self.description = description
        self.source = source
        self.links = links
        self.number = number
        self.type = type
        self.segments = segments
        self.extensions = extensions
    }
}

/// A contiguous run of track points. A new segment indicates a GPS gap or pause.
public struct GPXTrackSegment: Sendable, Codable, Equatable {
    public var points: [GPXWaypoint]
    public var extensions: GPXExtensions?

    public init(points: [GPXWaypoint] = [], extensions: GPXExtensions? = nil) {
        self.points = points
        self.extensions = extensions
    }
}
