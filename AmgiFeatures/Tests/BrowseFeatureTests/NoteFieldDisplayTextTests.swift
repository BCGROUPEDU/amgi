import Testing
@testable import BrowseFeature
#if canImport(UIKit)
import SwiftUI
import UIKit
#endif

@Suite("Note field HTML display")
struct NoteFieldDisplayTextTests {
    @Test func importedVocabularyKeepsSections() {
        let html = "新宿駅<div>しんじゅくえき</div><div>新宿駅で電車を降ります。</div>"
        #expect(NoteFieldDisplayText.plainText(from: html) == "新宿駅\nしんじゅくえき\n新宿駅で電車を降ります。")
        #expect(NoteFieldDisplayText.singleLine(from: html) == "新宿駅 しんじゅくえき 新宿駅で電車を降ります。")
    }

    @Test func blockAndBreakVariants() {
        #expect(NoteFieldDisplayText.plainText(from: "<DIV>A</DIV><p>B<br/>C<BR />D</p>") == "A\nB\nC\nD")
        #expect(NoteFieldDisplayText.plainText(from: "A<br><br>B") == "A\n\nB")
        #expect(NoteFieldDisplayText.plainText(from: "<ul><li>東京</li><li>駅</li></ul>") == "東京\n駅")
        #expect(NoteFieldDisplayText.plainText(from: "<div>A</div>B") == "A\nB")
    }

    @Test func inlineFormattingDoesNotSplitWords() {
        #expect(NoteFieldDisplayText.plainText(from: "<b>食</b>べる <span>カメラ</span>") == "食べる カメラ")
    }

    @Test func entitiesDecodeOnlyOnceAfterStripping() {
        #expect(NoteFieldDisplayText.plainText(from: "&lt;b&gt;字&lt;/b&gt; &amp;lt; &#x65B0;&#23487; &quot;駅&quot; &#39;") == "<b>字</b> &lt; 新宿 \"駅\" '")
        #expect(NoteFieldDisplayText.plainText(from: "A&nbsp;B &amp; C &apos;D&apos;") == "A B & C 'D'")
    }

    @Test func invalidNumericEntitiesRemainLiteral() {
        #expect(NoteFieldDisplayText.plainText(from: "&#0; &#xD800; &#x110000; &#999999999999999999999;") == "&#0; &#xD800; &#x110000; &#999999999999999999999;")
    }

    @Test func plainTextComparisonsAreNotTags() {
        #expect(NoteFieldDisplayText.plainText(from: "2 < 3 and 4 > 1") == "2 < 3 and 4 > 1")
        #expect(NoteFieldDisplayText.plainText(from: "日本語\nかな") == "日本語\nかな")
        #expect(NoteFieldDisplayText.plainText(from: "") == "")
    }

    @Test func hiddenMarkupAndMediaAreNotRenderedOrLoaded() {
        #expect(NoteFieldDisplayText.plainText(from: "字<!-- hidden --><script>hidden()</script><style>body {}</style><img src='https://invalid.example/private'>駅") == "字駅")
    }

    @Test func quotedAttributesAndTables() {
        #expect(NoteFieldDisplayText.plainText(from: "<span title='a > b'>駅</span>") == "駅")
        #expect(NoteFieldDisplayText.plainText(from: "<table><tr><td>A</td><td>B</td></tr><tr><td>C</td></tr></table>") == "A B\nC")
    }

    @Test func deliberatePlainEditsRoundTripLineBreaksAndLiteralText() {
        let plain = "駅\nえき & <example>\r\n次の行"
        let stored = NoteFieldDisplayText.storedHTML(fromPlainText: plain)
        #expect(stored == "駅<br>えき &amp; &lt;example&gt;<br>次の行")
        #expect(NoteFieldDisplayText.plainText(from: stored) == "駅\nえき & <example>\n次の行")
    }

    #if canImport(UIKit)
    @Test @MainActor func focusAndBlurWithoutEditPreservesOriginalHTML() {
        let original = "駅<div>えき</div><div>例文</div>"
        var stored = original
        let coordinator = RichNoteFieldEditor.Coordinator(htmlText: Binding(get: { stored }, set: { stored = $0 }))
        let field = UITextView()
        field.text = NoteFieldDisplayText.plainText(from: original)
        coordinator.lastPlainText = field.text
        coordinator.lastRenderedValue = original
        coordinator.textViewDidBeginEditing(field)
        coordinator.textViewDidEndEditing(field)
        #expect(stored == original)
    }

    @Test @MainActor func editedFieldStoresBreaksAndDoesNotRewriteOnBlur() {
        var stored = "駅"
        let coordinator = RichNoteFieldEditor.Coordinator(htmlText: Binding(get: { stored }, set: { stored = $0 }))
        coordinator.lastPlainText = "駅"
        let field = UITextView()
        field.text = "駅\nえき & <example>"
        coordinator.textViewDidChange(field)
        #expect(stored == "駅<br>えき &amp; &lt;example&gt;")
        coordinator.textViewDidEndEditing(field)
        #expect(stored == "駅<br>えき &amp; &lt;example&gt;")
    }

    @Test @MainActor func sourceHTMLEditingKeepsMediaMarkup() {
        var stored = ""
        let coordinator = RichNoteFieldEditor.Coordinator(
            htmlText: Binding(get: { stored }, set: { stored = $0 }), preservesSourceHTML: true
        )
        let field = UITextView()
        field.text = "<img src=\"existing.png\"><b>駅</b>"
        coordinator.textViewDidChange(field)
        #expect(stored == field.text)
    }
    #endif
}
