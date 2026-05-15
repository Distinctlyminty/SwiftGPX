import Foundation

/// Reads a GPX 1.1 document from XML.
///
/// Parsing is synchronous and per-call: each invocation creates a fresh internal delegate,
/// so the type is safely `Sendable` and re-entrant. The underlying engine is Foundation's
/// SAX-style `XMLParser` so memory stays bounded for large recorded tracks.
public struct GPXParser: Sendable {
    public init() {}

    /// Parses an in-memory GPX document.
    public func parse(_ data: Data) throws -> GPXDocument {
        let delegate = GPXParserDelegate()
        return try Self.run(parser: XMLParser(data: data), delegate: delegate)
    }

    /// Reads a file at the given URL and parses it.
    public func parse(contentsOf url: URL) throws -> GPXDocument {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw GPXError.ioFailure(error.localizedDescription)
        }
        return try parse(data)
    }

    /// Parses from an open `InputStream`. The stream is opened if not already.
    public func parse(_ stream: InputStream) throws -> GPXDocument {
        let delegate = GPXParserDelegate()
        return try Self.run(parser: XMLParser(stream: stream), delegate: delegate)
    }

    private static func run(parser: XMLParser, delegate: GPXParserDelegate) throws -> GPXDocument {
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = false
        guard parser.parse() else {
            if let error = delegate.error { throw error }
            let parseError = parser.parserError
            throw GPXError.malformedXML(
                line: parser.lineNumber,
                message: parseError?.localizedDescription ?? "unknown parser error"
            )
        }
        if let error = delegate.error { throw error }
        return delegate.document
    }
}
