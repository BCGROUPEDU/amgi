public import Foundation
import CryptoKit

public struct VocabularyImportExample: Codable, Equatable, Sendable {
    public let japanese: String
    public let english: String?
    public let source: String

    public init(japanese: String, english: String?, source: String) {
        self.japanese = japanese
        self.english = english
        self.source = source
    }
}

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
    public let examples: [VocabularyImportExample]?
    public let requestID: String?
    public let frontShowsReading: Bool?

    public init(
        schemaVersion: Int,
        surface: String,
        reading: String?,
        glosses: [String],
        sourceSentence: String?,
        sourceSentenceTranslation: String?,
        sourceApp: String,
        examples: [VocabularyImportExample]? = nil,
        requestID: String? = nil,
        frontShowsReading: Bool? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.surface = surface
        self.reading = reading
        self.glosses = glosses
        self.sourceSentence = sourceSentence
        self.sourceSentenceTranslation = sourceSentenceTranslation
        self.sourceApp = sourceApp
        self.examples = examples
        self.requestID = requestID
        self.frontShowsReading = frontShowsReading
    }

    /// The return destination is fixed; the inbound payload supplies only a UUID.
    public func resultURL(status: VocabularyImportStatus) -> URL? {
        guard let requestID else { return nil }
        var components = URLComponents()
        components.scheme = "furilens"
        components.host = "vocabulary"
        components.path = "/result"
        components.queryItems = [
            URLQueryItem(name: "requestID", value: requestID),
            URLQueryItem(name: "status", value: status.rawValue),
        ]
        return components.url
    }

    /// Opaque Anki tags let the next import recognize the same word or request
    /// without storing vocabulary text in a tag or log entry.
    public var vocabularyTag: String {
        let normalized = surface.precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return "furilens-vocab-" + digest.map { String(format: "%02x", $0) }.joined()
    }

    public var requestTag: String? {
        requestID.map { "furilens-request-" + $0.replacingOccurrences(of: "-", with: "") }
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
        var frontParts = [term]
        if frontShowsReading == true, let readingValue {
            frontParts.append("<div>\(readingValue)</div>")
        }
        for example in examples ?? [] {
            frontParts.append("<div>\(Self.htmlEscaped(example.japanese))</div>")
        }
        let front = frontParts.joined()

        var details: [String] = []
        if let readingValue { details.append("<div><b>Reading:</b> \(readingValue)</div>") }
        if !definitions.isEmpty { details.append("<div><b>Meaning:</b> \(definitions)</div>") }
        if let sentence { details.append("<div><b>Context:</b> \(sentence)</div>") }
        if let translation { details.append("<div><b>Translation:</b> \(translation)</div>") }
        for example in examples ?? [] {
            var line = "<div><b>Example:</b> \(Self.htmlEscaped(example.japanese))"
            if let english = example.english {
                line += "<br>\(Self.htmlEscaped(english))"
            }
            line += " <small>(\(Self.htmlEscaped(example.source)))</small></div>"
            details.append(line)
        }
        details.append("<div><b>Source:</b> \(source)</div>")
        let back = details.joined()

        var fields = [
            "Front": front,
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

public enum VocabularyImportStatus: String, Sendable {
    case saved, cancelled
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
    public static let maximumExampleCount = 2
    public static let maximumExampleTextLength = 500
    public static let maximumExampleSourceLength = 128

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
        let requestID: String?
        if let raw = draft.requestID {
            guard let uuid = UUID(uuidString: raw),
                  uuid.uuidString.lowercased() == raw.lowercased() else { return nil }
            requestID = raw.lowercased()
        } else {
            requestID = nil
        }

        guard !surface.isEmpty,
              surface.count <= maximumSurfaceLength,
              reading?.count ?? 0 <= maximumReadingLength,
              sentence?.count ?? 0 <= maximumSentenceLength,
              translation?.count ?? 0 <= maximumSentenceLength,
              !sourceApp.isEmpty,
              sourceApp.count <= maximumSourceAppLength,
              draft.glosses.count <= maximumGlossCount,
              draft.examples?.count ?? 0 <= maximumExampleCount else { return nil }

        let glosses = draft.glosses.compactMap(optionalTrimmed)
        guard glosses.allSatisfy({ $0.count <= maximumGlossLength }) else { return nil }
        var examples: [VocabularyImportExample] = []
        for example in draft.examples ?? [] {
            let japanese = trimmed(example.japanese)
            let english = optionalTrimmed(example.english)
            let source = trimmed(example.source)
            guard !japanese.isEmpty, japanese.count <= maximumExampleTextLength,
                  english?.count ?? 0 <= maximumExampleTextLength,
                  !source.isEmpty, source.count <= maximumExampleSourceLength else { return nil }
            examples.append(VocabularyImportExample(japanese: japanese, english: english, source: source))
        }

        return VocabularyImportDraft(
            schemaVersion: VocabularyImportDraft.currentSchemaVersion,
            surface: surface,
            reading: reading,
            glosses: glosses,
            sourceSentence: sentence,
            sourceSentenceTranslation: translation,
            sourceApp: sourceApp,
            examples: draft.examples == nil ? nil : examples,
            requestID: requestID,
            frontShowsReading: draft.frontShowsReading
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
