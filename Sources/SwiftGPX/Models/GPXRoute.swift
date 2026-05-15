import Foundation

/// An ordered list of waypoints representing a planned course.
public struct GPXRoute: Sendable, Codable, Equatable {
    public var name: String?
    public var comment: String?
    public var description: String?
    public var source: String?
    public var links: [GPXLink]
    public var number: Int?
    public var type: String?
    public var points: [GPXWaypoint]
    public var extensions: GPXExtensions?

    public init(
        name: String? = nil,
        comment: String? = nil,
        description: String? = nil,
        source: String? = nil,
        links: [GPXLink] = [],
        number: Int? = nil,
        type: String? = nil,
        points: [GPXWaypoint] = [],
        extensions: GPXExtensions? = nil
    ) {
        self.name = name
        self.comment = comment
        self.description = description
        self.source = source
        self.links = links
        self.number = number
        self.type = type
        self.points = points
        self.extensions = extensions
    }
}
