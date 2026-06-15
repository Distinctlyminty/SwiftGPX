import Foundation

/// Errors raised by the parser and serializer.
public enum GPXError: Error, Sendable, Equatable {
    /// The XML failed to parse at the given line, with the underlying parser message.
    case malformedXML(line: Int, message: String)

    /// A required attribute was missing on an element.
    case missingRequiredAttribute(element: String, attribute: String)

    /// A latitude/longitude value could not be parsed as a `Double`.
    case invalidCoordinate(String)

    /// The document declared a GPX version this library doesn't support.
    case unsupportedVersion(String)

    /// A numeric value in the document cannot be represented in valid GPX —
    /// non-finite (NaN/infinity), or a latitude/longitude outside its legal range.
    case invalidValue(element: String, value: Double)

    /// Could not read the data from the underlying URL.
    case ioFailure(String)
}

extension GPXError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .malformedXML(line, message):
            return "Malformed GPX at line \(line): \(message)"
        case let .missingRequiredAttribute(element, attribute):
            return "<\(element)> is missing required attribute '\(attribute)'."
        case let .invalidCoordinate(raw):
            return "Could not parse coordinate value '\(raw)'."
        case let .unsupportedVersion(version):
            return "GPX version '\(version)' is not supported."
        case let .invalidValue(element, value):
            return "Value \(value) for <\(element)> cannot be represented in valid GPX."
        case let .ioFailure(message):
            return "Could not read GPX data: \(message)"
        }
    }
}
