public import Foundation

/// Validated vocabulary payload accepted from a local companion app.
public struct VocabularyImportDraft: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let surface: String
    public let reading: String?
    public let glosses: [String]
    public let sourceSentence: String?
    public let sourceSentenceTranslation: String?
    public let sourceApp: String

    public init(
        schemaVersion: Int,
        surface: String,
        reading: String?,
        glosses: [String],
        sourceSentence: String?,
        sourceSentenceTranslation: String?,
        sourceApp: String
    ) {
        self.schemaVersion = schemaVersion
        self.surface = surface
        self.reading = reading
        self.glosses = glosses
        self.sourceSentence = sourceSentence
        self.sourceSentenceTranslation = sourceSentenceTranslation
        self.sourceApp = sourceApp
    }

    /// Common field-name projection used by the existing Add Note screen.
    /// Values are escaped because Anki fields contain HTML.
    public var addNoteFieldValues: [String: String] {
        let term = Self.htmlEscaped(surface)
        let readingValue = reading.map(Self.htmlEscaped)
        let definitions = glosses.map(Self.htmlEscaped).joined(separator: "; ")
        let sentence = sourceSentence.map(Self.htmlEscaped)
        let translation = sourceSentenceTranslation.map(Self.htmlEscaped)
        let source = Self.htmlEscaped(sourceApp)

        var details: [String] = []
        if let readingValue { details.append("<div><b>Reading:</b> \(readingValue)</div>") }
        if !definitions.isEmpty { details.append("<div><b>Meaning:</b> \(definitions)</div>") }
        if let sentence { details.append("<div><b>Example sentence:</b> \(sentence)</div>") }
        if let translation { details.append("<div><b>Translation:</b> \(translation)</div>") }
        details.append("<div><b>Source:</b> \(source)</div>")
        let back = details.joined()

        var fields = [
            "Front": term,
            "Text": term,
            "Expression": term,
            "Word": term,
            "Vocabulary": term,
            "Back": back,
            "Meaning": definitions,
            "Definition": definitions,
            "Definitions": definitions,
            "Source": source,
            "Extra": back,
        ]
        if let readingValue { fields["Reading"] = readingValue }
        if let sentence {
            fields["Sentence"] = sentence
            fields["Context"] = sentence
            fields["Example"] = sentence
            fields["Example Sentence"] = sentence
            fields["ExampleSentence"] = sentence
            fields["Example Sentences"] = sentence
        }
        if let translation { fields["Translation"] = translation }
        return fields
    }

    private static func htmlEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

public enum AmgiDeepLink: Equatable, Sendable {
    case review(deckID: Int64)
    case vocabulary(VocabularyImportDraft)
}

/// Single fail-closed parser for Amgi custom-scheme routes.
public enum AmgiDeepLinkParser {
    public static let maximumEncodedPayloadLength = 8_192
    public static let maximumDecodedPayloadLength = 6_144
    public static let maximumSurfaceLength = 128
    public static let maximumReadingLength = 128
    public static let maximumGlossCount = 5
    public static let maximumGlossLength = 512
    public static let maximumSentenceLength = 1_500
    public static let maximumSourceAppLength = 64

    public static func parse(_ url: URL) -> AmgiDeepLink? {
        guard url.scheme?.lowercased() == "amgi" else { return nil }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        if url.host?.lowercased() == "review" {
            guard let value = components?.queryItems?.first(where: { $0.name == "deckId" })?.value,
                  let deckID = Int64(value) else { return nil }
            return .review(deckID: deckID)
        }

        guard url.host?.lowercased() == "vocabulary",
              url.path == "/import",
              let items = components?.queryItems,
              items.filter({ $0.name == "draft" }).count == 1,
              let encoded = items.first(where: { $0.name == "draft" })?.value,
              encoded.count <= maximumEncodedPayloadLength,
              let data = decodeBase64URL(encoded),
              data.count <= maximumDecodedPayloadLength,
              let decoded = try? JSONDecoder().decode(VocabularyImportDraft.self, from: data),
              let validated = validated(decoded) else { return nil }
        return .vocabulary(validated)
    }

    private static func validated(_ draft: VocabularyImportDraft) -> VocabularyImportDraft? {
        guard draft.schemaVersion == VocabularyImportDraft.currentSchemaVersion else { return nil }
        let surface = trimmed(draft.surface)
        let reading = optionalTrimmed(draft.reading)
        let sentence = optionalTrimmed(draft.sourceSentence)
        let translation = optionalTrimmed(draft.sourceSentenceTranslation)
        let sourceApp = trimmed(draft.sourceApp)

        guard !surface.isEmpty,
              surface.count <= maximumSurfaceLength,
              reading?.count ?? 0 <= maximumReadingLength,
              sentence?.count ?? 0 <= maximumSentenceLength,
              translation?.count ?? 0 <= maximumSentenceLength,
              !sourceApp.isEmpty,
              sourceApp.count <= maximumSourceAppLength,
              draft.glosses.count <= maximumGlossCount else { return nil }

        let glosses = draft.glosses.compactMap(optionalTrimmed)
        guard glosses.allSatisfy({ $0.count <= maximumGlossLength }) else { return nil }

        return VocabularyImportDraft(
            schemaVersion: VocabularyImportDraft.currentSchemaVersion,
            surface: surface,
            reading: reading,
            glosses: glosses,
            sourceSentence: sentence,
            sourceSentenceTranslation: translation,
            sourceApp: sourceApp
        )
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func optionalTrimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = trimmed(value)
        return normalized.isEmpty ? nil : normalized
    }
}
