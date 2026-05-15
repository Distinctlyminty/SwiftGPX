import Foundation

/// Typed access to common fitness extensions plus a verbatim escape hatch for unknown elements.
///
/// Known fields map onto these namespaces:
/// - Garmin TrackPointExtension v1 — `hr`, `cadence`, `airTemperature`, `waterTemperature`, `depth`
/// - Garmin TrackPointExtension v2 — adds `speed`, `course`, `bearing`
/// - ClueTrust GPXData — `hr` and `cadence` alternative spellings
///
/// Anything the parser doesn't recognise is preserved in ``custom`` so round-tripping never
/// silently drops data.
public struct GPXExtensions: Sendable, Codable, Equatable {
    public var heartRate: Int?
    public var cadence: Int?
    public var airTemperature: Double?
    public var waterTemperature: Double?
    public var depth: Double?
    public var speed: Double?
    public var course: Double?
    public var bearing: Double?
    public var power: Double?

    /// Unrecognised extension elements, preserved verbatim by namespace and element name.
    public var custom: [GPXCustomExtension]

    public init(
        heartRate: Int? = nil,
        cadence: Int? = nil,
        airTemperature: Double? = nil,
        waterTemperature: Double? = nil,
        depth: Double? = nil,
        speed: Double? = nil,
        course: Double? = nil,
        bearing: Double? = nil,
        power: Double? = nil,
        custom: [GPXCustomExtension] = []
    ) {
        self.heartRate = heartRate
        self.cadence = cadence
        self.airTemperature = airTemperature
        self.waterTemperature = waterTemperature
        self.depth = depth
        self.speed = speed
        self.course = course
        self.bearing = bearing
        self.power = power
        self.custom = custom
    }

    /// `true` if every known and custom field is nil/empty — no `<extensions>` block should be emitted.
    public var isEmpty: Bool {
        heartRate == nil && cadence == nil && airTemperature == nil && waterTemperature == nil
            && depth == nil && speed == nil && course == nil && bearing == nil && power == nil
            && custom.isEmpty
    }
}

/// An extension element preserved verbatim during round-trip.
///
/// Stored as fully-qualified-name (including any namespace prefix as seen in the source XML)
/// plus the text content of the leaf element. Nested custom structures aren't supported in v1.
public struct GPXCustomExtension: Sendable, Codable, Equatable {
    public var qualifiedName: String
    public var value: String

    public init(qualifiedName: String, value: String) {
        self.qualifiedName = qualifiedName
        self.value = value
    }
}
