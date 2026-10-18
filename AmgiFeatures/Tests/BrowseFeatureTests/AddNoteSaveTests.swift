import AnkiServices
import Dependencies
import Foundation
import Testing
@testable import BrowseFeature

@Suite("Add Note save state")
@MainActor
struct AddNoteSaveTests {
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
