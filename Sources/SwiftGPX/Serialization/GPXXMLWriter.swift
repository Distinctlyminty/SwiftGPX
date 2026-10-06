import Foundation

/// Minimal pretty-printing XML writer used by ``GPXSerializer``.
///
/// Scoped to GPX's needs — element open/close, text-only leaf elements, attribute writing.
/// Not a general-purpose XML library.
struct GPXXMLWriter {
    private(set) var output: String = ""
    private var indentLevel: Int = 0
    private let prettyPrint: Bool

    init(prettyPrint: Bool) {
        self.prettyPrint = prettyPrint
    }

    mutating func write(_ string: String) {
        output.append(string)
    }

    mutating func newline() {
        if prettyPrint { output.append("\n") }
    }

    private mutating func indent() {
        guard prettyPrint else { return }
        for _ in 0..<indentLevel { output.append("  ") }
    }

    mutating func openElement(_ name: String, attributes: [(String, String)] = []) {
        indent()
        output.append("<")
        output.append(name)
        for (key, value) in attributes {
            output.append(" ")
            output.append(key)
            output.append("=\"")
            output.append(escapeAttribute(value))
            output.append("\"")
        }
        output.append(">")
        newline()
        indentLevel += 1
    }

    mutating func closeElement(_ name: String) {
        indentLevel -= 1
        indent()
        output.append("</")
        output.append(name)
        output.append(">")
        newline()
    }

    mutating func textElement(_ name: String, value: String) {
        indent()
        output.append("<")
        output.append(name)
        output.append(">")
        output.append(escapeText(value))
        output.append("</")
        output.append(name)
        output.append(">")
        newline()
    }
}

// MARK: - XML escaping

// Both escapers walk unicode scalars rather than `Character`s: "\r\n" is a single
// grapheme cluster, so a per-`Character` switch would never see the carriage return.
// Scalars that XML 1.0 cannot carry at all (most C0 controls, U+FFFE/U+FFFF) are dropped —
// emitting them, even as character references, makes the whole document unparseable.

func escapeText(_ value: String) -> String {
    var result = String.UnicodeScalarView()
    for scalar in value.unicodeScalars where isLegalXMLScalar(scalar) {
        switch scalar {
        case "&": result.append(contentsOf: "&amp;".unicodeScalars)
        case "<": result.append(contentsOf: "&lt;".unicodeScalars)
        case ">": result.append(contentsOf: "&gt;".unicodeScalars)
        // A literal CR is normalized to LF by XML parsers; a reference survives.
        case "\r": result.append(contentsOf: "&#13;".unicodeScalars)
        default: result.append(scalar)
        }
    }
    return String(result)
}

func escapeAttribute(_ value: String) -> String {
    var result = String.UnicodeScalarView()
    for scalar in value.unicodeScalars where isLegalXMLScalar(scalar) {
        switch scalar {
        case "&": result.append(contentsOf: "&amp;".unicodeScalars)
        case "<": result.append(contentsOf: "&lt;".unicodeScalars)
        case ">": result.append(contentsOf: "&gt;".unicodeScalars)
        case "\"": result.append(contentsOf: "&quot;".unicodeScalars)
        case "'": result.append(contentsOf: "&apos;".unicodeScalars)
        // Attribute-value normalization turns literal whitespace controls into spaces.
        case "\t": result.append(contentsOf: "&#9;".unicodeScalars)
        case "\n": result.append(contentsOf: "&#10;".unicodeScalars)
        case "\r": result.append(contentsOf: "&#13;".unicodeScalars)
        default: result.append(scalar)
        }
    }
    return String(result)
}

/// The XML 1.0 `Char` production.
private func isLegalXMLScalar(_ scalar: Unicode.Scalar) -> Bool {
    switch scalar.value {
    case 0x9, 0xA, 0xD, 0x20...0xD7FF, 0xE000...0xFFFD, 0x10000...0x10FFFF: return true
    default: return false
    }
}

// MARK: - XML names

/// Whether `name` can be used as a namespace prefix or unprefixed element name. This is the
/// ASCII-plus-letters core of the XML `NCName` production — deliberately a little stricter
/// than the spec so anything it accepts is safe to write.
func isValidXMLName(_ name: String) -> Bool {
    guard let first = name.unicodeScalars.first, isXMLNameStart(first) else { return false }
    return name.unicodeScalars.dropFirst().allSatisfy(isXMLNameContinuation)
}

/// Rewrites `name` into a valid unprefixed element name, replacing each character an XML
/// name can't contain with `_`.
func sanitizedXMLName(_ name: String) -> String {
    var result = String.UnicodeScalarView()
    for scalar in name.unicodeScalars {
        result.append(isXMLNameContinuation(scalar) ? scalar : "_")
    }
    if let first = result.first, isXMLNameStart(first) { return String(result) }
    return "_" + String(result)
}

private func isXMLNameStart(_ scalar: Unicode.Scalar) -> Bool {
    scalar == "_" || scalar.properties.isAlphabetic
}

private func isXMLNameContinuation(_ scalar: Unicode.Scalar) -> Bool {
    isXMLNameStart(scalar) || scalar == "-" || scalar == "." || ("0"..."9").contains(scalar)
}
