import Foundation
import Testing
@testable import AppCore

@Suite("Amgi deep links")
struct AmgiDeepLinkTests {
    @Test("Vocabulary payload validates and maps to safe note fields")
    func vocabularyRoundTrip() throws {
        let url = try #require(makeURL(payload: [
            "schemaVersion": 1,
            "surface": " 新宿 ",
            "reading": "しんじゅく",
            "glosses": ["Shinjuku", "<station>"],
            "sourceSentence": "新宿駅",
            "sourceSentenceTranslation": "Shinjuku Station",
            "sourceApp": "FuriLens",
        ]))

        guard case .vocabulary(let draft) = AmgiDeepLinkParser.parse(url) else {
            Issue.record("Expected a vocabulary route")
            return
        }
        #expect(draft.surface == "新宿")
        #expect(draft.reading == "しんじゅく")
        #expect(draft.glosses == ["Shinjuku", "<station>"])
        #expect(draft.addNoteFieldValues["Front"] == "新宿")
        #expect(draft.addNoteFieldValues["Definition"] == "Shinjuku; &lt;station&gt;")
        #expect(draft.addNoteFieldValues["Back"]?.contains("<b>Reading:</b> しんじゅく") == true)
        #expect(draft.addNoteFieldValues["Back"]?.contains("<b>Source:</b> FuriLens") == true)
    }

    @Test("Existing review route remains supported")
    func reviewRoute() throws {
        let url = try #require(URL(string: "amgi://review?deckId=42"))
        #expect(AmgiDeepLinkParser.parse(url) == .review(deckID: 42))
    }

    @Test("Malformed, unsupported, and oversized payloads fail closed")
    func invalidPayloads() throws {
        #expect(AmgiDeepLinkParser.parse(try #require(URL(string: "https://vocabulary/import"))) == nil)
        #expect(AmgiDeepLinkParser.parse(try #require(URL(string: "amgi://vocabulary/import?draft=***"))) == nil)
        #expect(AmgiDeepLinkParser.parse(try #require(makeURL(payload: [
            "schemaVersion": 2,
            "surface": "駅",
            "glosses": [],
            "sourceApp": "FuriLens",
        ]))) == nil)
        #expect(AmgiDeepLinkParser.parse(try #require(makeURL(payload: [
            "schemaVersion": 1,
            "surface": String(repeating: "駅", count: AmgiDeepLinkParser.maximumSurfaceLength + 1),
            "glosses": [],
            "sourceApp": "FuriLens",
        ]))) == nil)
    }

    private func makeURL(payload: [String: Any]) throws -> URL? {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let encoded = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        var components = URLComponents()
        components.scheme = "amgi"
        components.host = "vocabulary"
        components.path = "/import"
        components.queryItems = [URLQueryItem(name: "draft", value: encoded)]
        return components.url
    }
}
