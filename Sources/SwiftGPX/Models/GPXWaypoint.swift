import Foundation

/// A single geographic point. Used for `<wpt>` (standalone), `<rtept>` (route point),
/// and `<trkpt>` (track point) — they share the same GPX schema.
public struct GPXWaypoint: Sendable, Codable, Equatable {
    public var latitude: Double
    public var longitude: Double

    public var elevation: Double?
    public var time: Date?
    public var magneticVariation: Double?
    public var geoidHeight: Double?

    public var name: String?
    public var comment: String?
    public var description: String?
    public var source: String?
    public var links: [GPXLink]
    public var symbol: String?
    public var type: String?

    public var fix: GPXFix?
    public var satellites: Int?
    public var horizontalDilution: Double?
    public var verticalDilution: Double?
    public var positionDilution: Double?
    public var ageOfDGPSData: Double?
    public var dgpsId: Int?

    public var extensions: GPXExtensions?

    public init(
        latitude: Double,
        longitude: Double,
        elevation: Double? = nil,
        time: Date? = nil,
        magneticVariation: Double? = nil,
        geoidHeight: Double? = nil,
        name: String? = nil,
        comment: String? = nil,
        description: String? = nil,
        source: String? = nil,
        links: [GPXLink] = [],
        symbol: String? = nil,
        type: String? = nil,
        fix: GPXFix? = nil,
        satellites: Int? = nil,
        horizontalDilution: Double? = nil,
        verticalDilution: Double? = nil,
        positionDilution: Double? = nil,
        ageOfDGPSData: Double? = nil,
        dgpsId: Int? = nil,
        extensions: GPXExtensions? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.time = time
        self.magneticVariation = magneticVariation
        self.geoidHeight = geoidHeight
        self.name = name
        self.comment = comment
        self.description = description
        self.source = source
        self.links = links
        self.symbol = symbol
        self.type = type
        self.fix = fix
        self.satellites = satellites
        self.horizontalDilution = horizontalDilution
        self.verticalDilution = verticalDilution
        self.positionDilution = positionDilution
        self.ageOfDGPSData = ageOfDGPSData
        self.dgpsId = dgpsId
        self.extensions = extensions
    }
}

/// GPS fix type from `<fix>`.
public enum GPXFix: String, Sendable, Codable, Equatable {
    case none
    case twoDimensional = "2d"
    case threeDimensional = "3d"
    case dgps
    case pps
}
