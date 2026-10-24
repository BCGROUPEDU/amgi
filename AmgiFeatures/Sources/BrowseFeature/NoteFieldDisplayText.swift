import Foundation

/// Read-only text projection of Anki's stored HTML fragments. This is not an
/// HTML renderer or sanitizer: it never loads media, scripts, or a web view.
enum NoteFieldDisplayText {
    static func plainText(from html: String) -> String {
        let visible = html
            .replacingOccurrences(of: #"<!--[\s\S]*?-->"#, with: "", options: .regularExpression)
            .replacingOccurrences(
                of: #"<(script|style)\b[^>]*>[\s\S]*?</\1\s*>"#,
                with: "", options: [.regularExpression, .caseInsensitive]
            )
        guard let tags = try? NSRegularExpression(
            pattern: #"<\s*/?\s*([A-Za-z][A-Za-z0-9:-]*)\b(?:"[^"]*"|'[^']*'|[^'">])*>"#
        ) else { return html }
        let source = visible as NSString
        var text = ""
        var position = 0
        let blocks: Set<String> = [
            "div", "p", "li", "ul", "ol", "blockquote", "pre", "section",
            "article", "h1", "h2", "h3", "h4", "h5", "h6", "tr", "hr"
        ]
        for match in tags.matches(in: visible, range: NSRange(location: 0, length: source.length)) {
            text += source.substring(with: NSRange(location: position, length: match.range.location - position))
            let name = source.substring(with: match.range(at: 1)).lowercased()
            if name == "br" {
                text.append("\n")
            } else if blocks.contains(name), !text.isEmpty, !text.hasSuffix("\n") {
                while text.last == " " || text.last == "\t" { text.removeLast() }
                text.append("\n")
            } else if ["td", "th"].contains(name), !text.isEmpty,
                      !text.hasSuffix(" "), !text.hasSuffix("\n") {
                text.append(" ")
            }
            position = match.range.location + match.range.length
        }
        text += source.substring(from: position)
        return decodeEntities(text).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func singleLine(from html: String) -> String {
        plainText(from: html).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Called only after a deliberate plain-text edit, never to rewrite existing
    /// notes on load/focus. Anki renders field values as HTML, not raw newlines.
    static func storedHTML(fromPlainText text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    /// Decode once, after tag removal, so escaped literal tags remain text and
    /// double-escaped entities are not recursively interpreted as markup.
    private static func decodeEntities(_ text: String) -> String {
        guard let entities = try? NSRegularExpression(
            pattern: #"&(?:amp|lt|gt|quot|apos|nbsp|#[0-9]+|#[xX][0-9A-Fa-f]+);"#
        ) else { return text }
        let named = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " "]
        let source = text as NSString
        var output = ""
        var position = 0
        for match in entities.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            output += source.substring(with: NSRange(location: position, length: match.range.location - position))
            let entity = source.substring(with: match.range)
            let key = String(entity.dropFirst().dropLast())
            var replacement = named[key]
            if key.hasPrefix("#") {
                let hex = key.lowercased().hasPrefix("#x")
                let digits = key.dropFirst(hex ? 2 : 1)
                if let number = UInt32(digits, radix: hex ? 16 : 10), number != 0,
                   let scalar = UnicodeScalar(number) {
                    replacement = String(scalar)
                }
            }
            output += replacement ?? entity
            position = match.range.location + match.range.length
        }
        output += source.substring(from: position)
        return output
    }
}
