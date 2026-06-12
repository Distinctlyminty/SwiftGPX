import Testing
import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
@testable import SwiftGPX

/// Serializes, shape-checks, re-parses, and asserts equality — the round-trip contract in
/// one call. Returns the decoded document for any additional assertions.
@discardableResult
func assertRoundTrips(
    _ document: GPXDocument,
    sourceLocation: SourceLocation = #_sourceLocation
) throws -> GPXDocument {
    let data = try GPXSerializer().data(from: document)
    expectSchemaShapedGPX(data, sourceLocation: sourceLocation)
    let decoded = try GPXParser().parse(data)
    #expect(decoded == document, sourceLocation: sourceLocation)
    return decoded
}

/// Re-parses serializer output with a bare `XMLParser` and asserts GPX-schema shape:
/// well-formed XML, a single `<gpx>` root carrying the required attributes, every
/// namespace prefix in use declared on the root, no non-finite numeric text, and all
/// latitude/longitude attributes within range. Foundation-only so it runs on Linux.
func expectSchemaShapedGPX(_ data: Data, sourceLocation: SourceLocation = #_sourceLocation) {
    let inspector = XMLShapeInspector()
    let parser = XMLParser(data: data)
    parser.delegate = inspector
    let wellFormed = parser.parse()
    #expect(
        wellFormed,
        "output is not well-formed XML: \(parser.parserError?.localizedDescription ?? "unknown")",
        sourceLocation: sourceLocation
    )
    guard wellFormed else { return }

    #expect(inspector.rootName == "gpx", "root element is <\(inspector.rootName ?? "nil")>", sourceLocation: sourceLocation)
    #expect(inspector.rootAttributes["version"] == "1.1", sourceLocation: sourceLocation)
    #expect(inspector.rootAttributes["creator"] != nil, sourceLocation: sourceLocation)
    #expect(
        inspector.rootAttributes["xmlns"] == "http://www.topografix.com/GPX/1/1",
        sourceLocation: sourceLocation
    )

    let undeclared = inspector.usedPrefixes.subtracting(inspector.declaredPrefixes).subtracting(["xml"])
    #expect(undeclared.isEmpty, "undeclared namespace prefixes: \(undeclared.sorted())", sourceLocation: sourceLocation)

    #expect(inspector.nonFiniteTexts.isEmpty, "non-finite values in output: \(inspector.nonFiniteTexts)", sourceLocation: sourceLocation)
    #expect(inspector.coordinateViolations.isEmpty, "coordinates out of range: \(inspector.coordinateViolations)", sourceLocation: sourceLocation)
}

private final class XMLShapeInspector: NSObject, XMLParserDelegate {
    var rootName: String?
    var rootAttributes: [String: String] = [:]
    var declaredPrefixes: Set<String> = []
    var usedPrefixes: Set<String> = []
    var nonFiniteTexts: [String] = []
    var coordinateViolations: [String] = []

    private static let latitudeAttributes: Set<String> = ["lat", "minlat", "maxlat"]
    private static let longitudeAttributes: Set<String> = ["lon", "minlon", "maxlon"]
    private static let nonFiniteSpellings: Set<String> = ["nan", "-nan", "inf", "-inf", "+inf", "infinity", "-infinity"]

    func parser(
        _ parser: XMLParser, didStartElement elementName: String,
        namespaceURI: String?, qualifiedName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if rootName == nil {
            rootName = elementName
            rootAttributes = attributeDict
            for key in attributeDict.keys where key.hasPrefix("xmlns:") {
                declaredPrefixes.insert(String(key.dropFirst("xmlns:".count)))
            }
        }
        recordPrefix(of: elementName)
        for (key, value) in attributeDict {
            if !key.hasPrefix("xmlns") { recordPrefix(of: key) }
            if Self.latitudeAttributes.contains(key), let lat = Double(value), !(-90.0...90.0).contains(lat) {
                coordinateViolations.append("\(key)=\(value)")
            }
            if Self.longitudeAttributes.contains(key), let lon = Double(value), !(-180.0...180.0).contains(lon) {
                coordinateViolations.append("\(key)=\(value)")
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let text = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if Self.nonFiniteSpellings.contains(text) {
            nonFiniteTexts.append(text)
        }
    }

    private func recordPrefix(of name: String) {
        if let colon = name.firstIndex(of: ":") {
            usedPrefixes.insert(String(name[..<colon]))
        }
    }
}
