import Testing
@testable import AnkiKit

@Suite("Vocabulary note type compatibility")
struct VocabularyNotetypeTests {
    @Test("Only one normal Front/Back card is compatible")
    func compatibleBasic() {
        let basic = makeNotetype()
        #expect(basic.supportsSingleCardVocabulary)

        var reversed = basic
        reversed.templates.append(Notetype.Template(
            config: .init(qFormat: "{{Back}}", aFormat: "{{Front}}")
        ))
        #expect(!reversed.supportsSingleCardVocabulary)

        var cloze = basic
        cloze.config.kind = .cloze
        #expect(!cloze.supportsSingleCardVocabulary)

        var wrongTemplate = basic
        wrongTemplate.templates[0].config.aFormat = "{{Front}}"
        #expect(!wrongTemplate.supportsSingleCardVocabulary)
    }

    private func makeNotetype() -> Notetype {
        Notetype(
            fields: [Notetype.Field(name: "Front"), Notetype.Field(name: "Back")],
            templates: [Notetype.Template(config: .init(
                qFormat: "{{Front}}", aFormat: "{{FrontSide}}{{Back}}"
            ))]
        )
    }
}
