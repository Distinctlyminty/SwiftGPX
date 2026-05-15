import Foundation

/// Information about the GPX file itself — author, copyright, time it was created, etc.
public struct GPXMetadata: Sendable, Codable, Equatable {
    public var name: String?
    public var description: String?
    public var author: GPXPerson?
    public var copyright: GPXCopyright?
    public var links: [GPXLink]
    public var time: Date?
    public var keywords: String?
    public var bounds: GPXBounds?

    public init(
        name: String? = nil,
        description: String? = nil,
        author: GPXPerson? = nil,
        copyright: GPXCopyright? = nil,
        links: [GPXLink] = [],
        time: Date? = nil,
        keywords: String? = nil,
        bounds: GPXBounds? = nil
    ) {
        self.name = name
        self.description = description
        self.author = author
        self.copyright = copyright
        self.links = links
        self.time = time
        self.keywords = keywords
        self.bounds = bounds
    }
}

public struct GPXPerson: Sendable, Codable, Equatable {
    public var name: String?
    public var email: String?
    public var link: GPXLink?

    public init(name: String? = nil, email: String? = nil, link: GPXLink? = nil) {
        self.name = name
        self.email = email
        self.link = link
    }
}

public struct GPXCopyright: Sendable, Codable, Equatable {
    public var author: String
    public var year: Int?
    public var license: URL?

    public init(author: String, year: Int? = nil, license: URL? = nil) {
        self.author = author
        self.year = year
        self.license = license
    }
}

public struct GPXLink: Sendable, Codable, Equatable {
    public var href: String
    public var text: String?
    public var type: String?

    public init(href: String, text: String? = nil, type: String? = nil) {
        self.href = href
        self.text = text
        self.type = type
    }
}

/// A geographic bounding box, as `<bounds minlat minlon maxlat maxlon/>`.
public struct GPXBounds: Sendable, Codable, Equatable {
    public var minLatitude: Double
    public var minLongitude: Double
    public var maxLatitude: Double
    public var maxLongitude: Double

    public init(
        minLatitude: Double,
        minLongitude: Double,
        maxLatitude: Double,
        maxLongitude: Double
    ) {
        self.minLatitude = minLatitude
        self.minLongitude = minLongitude
        self.maxLatitude = maxLatitude
        self.maxLongitude = maxLongitude
    }
}
