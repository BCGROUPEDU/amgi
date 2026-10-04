//
//  ReviewSessionPracticeTests.swift
//  ReviewCoreTests
//
//  Created by Vladimir Gusev on 28.09.2026.
//

import AnkiClients
import AnkiKit
import AnkiServices
import Dependencies
import Foundation
import Testing
@testable import ReviewCore

/// Practice mode (`ReviewSession(mode: .practice)` and `practiceAgain()`) is
/// the "Practice Again"/"Practice" replay off a deck: same review UI, but a
/// rating must never reach the scheduler or the collection. It advances only
/// locally and depletes the session's own `remainingCounts` by the answered
/// card's queue class (0=new, 1/3=learn, 2=review). These tests drive a real
/// session through `start()`/`answer()` and pin those invariants.
@Suite("ReviewSession practice mode")
@MainActor
struct ReviewSessionPracticeTests {

    private struct StubError: Error {}

    /// Records scheduler calls coming from the off-actor task hops.
    private final class CallLog: @unchecked Sendable {
        private let lock = NSLock()
        private var calls: [String] = []

        func record(_ call: String) {
            lock.lock()
            defer { lock.unlock() }
            calls.append(call)
        }

        var all: [String] {
            lock.lock()
            defer { lock.unlock() }
            return calls
        }
    }

    private nonisolated static func queued(_ queue: Int16, id: Int64, nid: Int64 = 1) -> QueuedReviewCard {
        let card = CardRecord(id: CardID(id), nid: NoteID(nid), did: DeckID(1), ord: 0, mod: 0, queue: queue)
        let token = SchedulingStateToken(Data())
        let states = ReviewSchedulingStates(current: token, again: token, hard: token, good: token, easy: token)
        return QueuedReviewCard(card: card, states: states, nextIntervals: [:])
    }

private nonisolated static let deckInfo = DeckInfo(
    id: DeckID(1), name: "Test", counts: .zero, isFiltered: false
)

    /// `start()`/`answer()` spawn main-actor and detached tasks; yield on the
    /// main actor until the session reaches the expected checkpoint so the
    /// assertions run after the work lands.
    private func waitUntil(_ predicate: @MainActor () -> Bool, timeoutSeconds: Double = 2.0) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeoutSeconds))
        while !predicate() && ContinuousClock.now < deadline {
            await Task.yield()
        }
    }

    // MARK: Practice never mutates the collection

    @Test("practice answers never call the scheduler and deplete the local counts by queue class")
    func practiceAnswersStayLocal() async {
        let getQueueLog = CallLog()
        let answerLog = CallLog()

        await withDependencies {
            $0.schedulerService = SchedulerService(
                getQueuedCards: { _ in
                    getQueueLog.record("getQueuedCards")
                    return QueuedCardsResult(
                        cards: [Self.queued(0, id: 1), Self.queued(1, id: 2)],
                        newCount: 1, learningCount: 1, reviewCount: 0
                    )
                },
                answerReviewCard: { _, _, _, _ in
                    answerLog.record("answerReviewCard")
                }
            )
            $0.decksService = DecksService(
                fetchAll: { [Self.deckInfo] },
                setCurrentDeck: { _ in },
                getCurrentDeck: { Self.deckInfo }
            )
            $0.cardClient.fetchForPractice = { _, _ in
                [Self.queued(0, id: 1).card, Self.queued(1, id: 2).card]
            }
            $0.notesService = NotesService(getNote: { _ in throw StubError() })
            $0.cardRenderingService = CardRenderingService(renderCard: { _ in throw StubError() })
        } operation: {
            let session = ReviewSession(deckId: DeckID(1), mode: .practice)
            session.start()
            await waitUntil { session.currentQueuedCard?.card.id == CardID(1) }

            #expect(session.mode == .practice)
            #expect(session.remainingCounts.newCount == 1)
            #expect(session.remainingCounts.learningCount == 1)

            session.answer(rating: .good)
            await waitUntil { session.currentQueuedCard?.card.id == CardID(2) }
            #expect(session.isFinished == false)
            #expect(session.canUndo == false, "practice never arms undo")
            #expect(session.remainingCounts.newCount == 0, "a new card taps the new bucket")

            session.answer(rating: .good)
            await waitUntil { session.isFinished }
            #expect(session.sessionStats.reviewed == 2)
            #expect(session.sessionStats.correct == 2)
            #expect(session.canUndo == false)
            #expect(session.remainingCounts == .zero)
            #expect(session.remainingCounts.learnCount == 0, "a learning card taps the learn bucket")

            #expect(answerLog.all.isEmpty, "practice must never schedule a card")
            #expect(getQueueLog.all.count == 1, "the queue is fetched once at start, never refetched on a practice answer")
        }
    }

    // MARK: Review mode still schedules

    @Test("review mode still answers through the scheduler and refetches the queue")
    func reviewStillSchedules() async {
        let getQueueLog = CallLog()
        let answerLog = CallLog()

        await withDependencies {
            $0.schedulerService = SchedulerService(
                getQueuedCards: { _ in
                    getQueueLog.record("getQueuedCards")
                    if getQueueLog.all.count == 1 {
                        return QueuedCardsResult(
                            cards: [Self.queued(2, id: 1)],
                            newCount: 0, learningCount: 0, reviewCount: 1
                        )
                    }
                    return QueuedCardsResult(cards: [], newCount: 0, learningCount: 0, reviewCount: 0)
                },
                answerReviewCard: { _, _, _, _ in
                    answerLog.record("answerReviewCard")
                }
            )
            $0.decksService = DecksService(
                setCurrentDeck: { _ in },
                getCurrentDeck: { Self.deckInfo }
            )
        } operation: {
            let session = ReviewSession(deckId: DeckID(1))   // mode == .review
            session.start()
            await waitUntil { session.currentQueuedCard != nil }

            session.answer(rating: .good)
            await waitUntil { session.isFinished }

            #expect(session.sessionStats.reviewed == 1)
            #expect(session.sessionStats.correct == 1)
            #expect(session.canUndo == true, "a real review arms undo")
            #expect(session.remainingCounts == .zero)
            #expect(answerLog.all == ["answerReviewCard"], "review answers go through the scheduler")
            #expect(getQueueLog.all.count == 2, "start + the post-answer refetch")
        }
    }

    // MARK: practiceAgain()

    @Test("practiceAgain is unavailable when the completed session had no cards")
    func practiceAgainDoesNotQueryANewDueQueue() async {
        let getQueueLog = CallLog()
        let answerLog = CallLog()

        await withDependencies {
            $0.schedulerService = SchedulerService(
                getQueuedCards: { _ in
                    getQueueLog.record("getQueuedCards")
                    return QueuedCardsResult(cards: [], newCount: 0, learningCount: 0, reviewCount: 0)
                },
                answerReviewCard: { _, _, _, _ in
                    answerLog.record("answerReviewCard")
                }
            )
            $0.decksService = DecksService(
                setCurrentDeck: { _ in },
                getCurrentDeck: { Self.deckInfo }
            )
        } operation: {
            let session = ReviewSession(deckId: DeckID(1))   // starts in .review
            session.start()
            await waitUntil { session.isFinished }
            #expect(session.mode == .review)

            session.practiceAgain()

            #expect(session.mode == .review)
            #expect(session.isFinished)
            #expect(answerLog.all.isEmpty, "an empty rerun must still never schedule")
            #expect(getQueueLog.all.count == 1, "Practice Again must not ask for a new due queue")
        }
    }

    @Test("Practice Again replays completed cards after the due queue reaches zero")
    func practiceAgainReplaysCompletedCards() async {
        let queueLog = CallLog()
        let answerLog = CallLog()

        await withDependencies {
            $0.schedulerService = SchedulerService(
                getQueuedCards: { _ in
                    queueLog.record("getQueuedCards")
                    return queueLog.all.count == 1
                        ? QueuedCardsResult(cards: [Self.queued(2, id: 42)], newCount: 0, learningCount: 0, reviewCount: 1)
                        : QueuedCardsResult(cards: [], newCount: 0, learningCount: 0, reviewCount: 0)
                },
                answerReviewCard: { _, _, _, _ in answerLog.record("answerReviewCard") }
            )
            $0.decksService = DecksService(
                setCurrentDeck: { _ in }, getCurrentDeck: { Self.deckInfo }
            )
        } operation: {
            let session = ReviewSession(deckId: DeckID(1))
            session.start()
            await waitUntil { session.currentQueuedCard?.card.id == CardID(42) }
            session.answer(rating: .good)
            await waitUntil { session.isFinished }
            #expect(answerLog.all.count == 1)

            session.practiceAgain()
            await waitUntil { session.currentQueuedCard?.card.id == CardID(42) }
            #expect(session.mode == .practice)
            session.answer(rating: .good)
            await waitUntil { session.isFinished }

            #expect(answerLog.all.count == 1, "Practice Again must not schedule the replayed card")
            #expect(queueLog.all.count == 2, "only normal start and normal answer may use the due queue")
        }
    }
}
