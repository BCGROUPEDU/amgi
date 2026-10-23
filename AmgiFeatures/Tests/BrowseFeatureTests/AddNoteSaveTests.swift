import AnkiServices
import AnkiKit
import Dependencies
import Foundation
import Testing
@testable import BrowseFeature

@Suite("Add Note save state")
@MainActor
struct AddNoteSaveTests {
    @Test("Incoming vocabulary warns on native duplicate before any write")
    func vocabularyDuplicateWarning() async {
        let gate = NoteCreationGate()
        await withDependencies {
            $0.notesService.searchNoteIds = { query in
                #expect(query.contains("dupe:42,"))
                return [NoteID(12)]
            }
            $0.notesService.newNote = { _ in
                gate.recordAttempt()
                throw SaveTestError.expected
            }
        } operation: {
            let model = preparedVocabularyModel()
            let result = await model.save()
            #expect(!result)
            #expect(model.showDuplicateWarning)
            #expect(gate.count == 0)
        }
    }

    @Test("Incoming vocabulary stops when duplicate check fails")
    func vocabularyDuplicateFailure() async {
        let gate = NoteCreationGate()
        await withDependencies {
            $0.notesService.searchNoteIds = { _ in throw SaveTestError.expected }
            $0.notesService.newNote = { _ in
                gate.recordAttempt()
                throw SaveTestError.expected
            }
        } operation: {
            let model = preparedVocabularyModel()
            let result = await model.save()
            #expect(!result)
            #expect(!model.showDuplicateWarning)
            #expect(model.errorMessage != nil)
            #expect(gate.count == 0)
        }
    }

    @Test("Tagged word warns even when its full Front differs")
    func vocabularyTagDuplicate() async {
        await withDependencies {
            $0.notesService.searchNoteIds = { query in
                query == "tag:furilens-vocab-test" ? [NoteID(12)] : []
            }
        } operation: {
            let model = preparedVocabularyModel(vocabularyTag: "furilens-vocab-test")
            let result = await model.save()
            #expect(!result)
            #expect(model.showDuplicateWarning)
        }
    }

    @Test("Saved request tag prevents replay without a second write")
    func vocabularyRequestReplay() async {
        await withDependencies {
            $0.notesService.searchNoteIds = { query in
                query == "tag:furilens-request-test" ? [NoteID(12)] : []
            }
        } operation: {
            let model = preparedVocabularyModel(requestTag: "furilens-request-test")
            let result = await model.save()
            #expect(!result)
            #expect(!model.showDuplicateWarning)
            #expect(model.errorMessage == "This vocabulary request was already saved.")
        }
    }

    @Test("A completed save cannot start another note write")
    func completedSaveGuard() async {
        let gate = NoteCreationGate()
        await withDependencies {
            $0.notesService.newNote = { _ in
                gate.recordAttempt()
                throw SaveTestError.expected
            }
        } operation: {
            let model = preparedVocabularyModel()
            model.hasSaved = true
            let result = await model.save()
            #expect(!result)
            #expect(gate.count == 0)
        }
    }

    @Test("Add Anyway reaches one write, but a changed Front needs a fresh check")
    func duplicateApprovalIsBoundToFront() async {
        let attempts = AttemptCounter()
        await withDependencies {
            $0.notesService.searchNoteIds = { _ in [NoteID(12)] }
            $0.notesService.newNote = { _ in
                attempts.record()
                throw SaveTestError.expected
            }
        } operation: {
            let model = preparedVocabularyModel()
            let warningResult = await model.save()
            #expect(!warningResult)
            #expect(model.showDuplicateWarning)
            #expect(attempts.count == 0)

            let approvedResult = await model.save(allowDuplicate: true)
            #expect(!approvedResult)
            #expect(attempts.count == 1)

            model.fieldValues[0] = "新宿駅"
            let changedResult = await model.save(allowDuplicate: true)
            #expect(!changedResult)
            #expect(attempts.count == 1)
            #expect(model.errorMessage == "The Front value changed. Check for duplicates again.")
        }
    }

    private func preparedVocabularyModel(
        vocabularyTag: String? = nil,
        requestTag: String? = nil
    ) -> AddNoteModel {
        let model = AddNoteModel(
            isVocabularyImport: true,
            vocabularyTag: vocabularyTag,
            requestTag: requestTag
        )
        model.decks = [DeckInfo(id: DeckID(1), name: "Default")]
        model.selectedDeckId = DeckID(1)
        model.selectedNotetypeId = NotetypeID(42)
        model.fieldNames = ["Front", "Back"]
        model.fieldValues = ["駅", "station"]
        return model
    }

    @Test("an overlapping save does not begin another note or release the active save")
    func overlappingSaveIsRejected() async {
        let gate = NoteCreationGate()
        await withDependencies {
            $0.notesService.newNote = { _ in
                gate.recordAttempt()
                throw SaveTestError.expected
            }
        } operation: {
            let model = AddNoteModel()
            let firstSave = Task { await model.save() }
            await gate.waitUntilStarted()
            #expect(model.isSaving)

            let overlappingResult = await model.save()
            #expect(!overlappingResult)
            #expect(gate.count == 1)
            #expect(model.isSaving, "the rejected save must not unlock the in-flight write")
            #expect(model.errorMessage == nil)

            gate.release()
            let firstResult = await firstSave.value
            #expect(!firstResult)
            #expect(!model.isSaving)
            #expect(model.errorMessage != nil)

            let retryResult = await model.save()
            #expect(!retryResult)
            #expect(gate.count == 2, "a completed failure must allow a deliberate retry")
            #expect(!model.isSaving)
        }
    }
}

private enum SaveTestError: Error {
    case expected
}

private final class AttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    var count: Int { lock.withLock { value } }
    func record() { lock.withLock { value += 1 } }
}

/// Hold the synchronous service call off the main actor until the test has
/// attempted a second save. Throw before any template or database is needed.
private final class NoteCreationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var attempts = 0
    private let releaseSemaphore = DispatchSemaphore(value: 0)
    private let started = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))

    var count: Int { lock.withLock { attempts } }

    func recordAttempt() {
        let isFirst = lock.withLock {
            attempts += 1
            return attempts == 1
        }
        guard isFirst else { return }
        started.continuation.yield(())
        if releaseSemaphore.wait(timeout: .now() + 10) == .timedOut {
            Issue.record("timed out waiting for the overlapping-save check")
        }
    }

    func waitUntilStarted() async {
        var iterator = started.stream.makeAsyncIterator()
        _ = await iterator.next()
    }

    func release() { releaseSemaphore.signal() }
}
