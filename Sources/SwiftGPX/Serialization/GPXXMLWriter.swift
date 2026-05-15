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

func escapeText(_ value: String) -> String {
    var result = ""
    result.reserveCapacity(value.count)
    for character in value {
        switch character {
        case "&": result.append("&amp;")
        case "<": result.append("&lt;")
        case ">": result.append("&gt;")
        default: result.append(character)
        }
    }
    return result
}

func escapeAttribute(_ value: String) -> String {
    var result = ""
    result.reserveCapacity(value.count)
    for character in value {
        switch character {
        case "&": result.append("&amp;")
        case "<": result.append("&lt;")
        case ">": result.append("&gt;")
        case "\"": result.append("&quot;")
        case "'": result.append("&apos;")
        default: result.append(character)
        }
    }
    return result
}
