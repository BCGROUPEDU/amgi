//
//  ReviewSession.swift
//  ReviewCore
//
//  Created by Vladimir Gusev on 27.03.2026.
//

import OSLog
public import SwiftUI
import AppCore
#if canImport(UIKit)
import UIKit
#endif
public import AmgiCardWeb
import AnkiClients
public import AnkiKit
import AnkiServices
import Dependencies
import Foundation

public enum ResolvedRenderMode: Equatable, Sendable {
    case native(front: NativeCardContent, back: NativeCardContent)
    case html
}

/// What a review session is allowed to mutate.
public enum ReviewMode: Sendable, Equatable {
    /// Normal SRS review: every answer schedules the card through the engine.
    case review
    /// Practice: replays the due queue with the same UI, but a rating only
    /// advances locally — `answerReviewCard` is never called, no scheduler or
    /// collection state changes, and undo stays disabled. Numeric/typed
    /// answers and media behave exactly as in a real review.
    case practice
}

@Observable @MainActor
public final class ReviewSession {
    public let deckId: DeckID

    /// The session's mutation contract. Fixed at init, except `practiceAgain()`
    /// flips a finished normal session in place — that is the "Practice Again"
    /// entry on the completed screen, and it must not leave the existing item.
    public private(set) var mode: ReviewMode

    @ObservationIgnored @Dependency(\.decksService) var decks
    @ObservationIgnored @Dependency(\.schedulerService) var scheduler
    @ObservationIgnored @Dependency(\.cardRenderingService) var cardRendering
    @ObservationIgnored @Dependency(\.collectionService) var collection
    @ObservationIgnored @Dependency(\.notesService) var notes
    @ObservationIgnored @Dependency(\.notetypesService) var notetypes
    @ObservationIgnored @Dependency(\.notetypesClient) var notetypesClient
    @ObservationIgnored @Dependency(\.cardClient) var cardClient

    public private(set) var frontHTML: String = ""
    public private(set) var backHTML: String = ""
    public private(set) var cardCSS: String = ""
    public private(set) var showAnswer: Bool = false
    public private(set) var sessionStats: SessionStats = .init()
    public private(set) var remainingCounts: DeckCounts = .zero
    public private(set) var deckName: String = ""
    public private(set) var isFinished: Bool = false
    public private(set) var canUndo: Bool = false
    public private(set) var nextIntervals: [Rating: String] = [:]
    public private(set) var replayRequestID: Int = 0       // plumbed; consumer is PR 1b
    public private(set) var stopAudioRequestID: Int = 0    // plumbed; consumer is PR 1b
    public private(set) var isAudioPlaying: Bool = false
    public private(set) var currentNote: NoteRecord?
    public private(set) var cardChromeColor: Color = .clear
    public private(set) var cardChromeIsDark: Bool = false
    public private(set) var resolvedMode: ResolvedRenderMode = .html
    public private(set) var resolvedByAuto: Bool = false
    public private(set) var templateName: String?
    public private(set) var answerTapCount: Int = 0
    public private(set) var tappedRating: Rating = .good
    public private(set) var undoneCount: Int = 0

    public private(set) var isAdvancing: Bool = false
    public var answerError: String?
    public private(set) var startError: String?

    var reviewStartTime: ContinuousClock.Instant = .now
    var cardQueue: [QueuedReviewCard] = []
    var notetypeCache: [NotetypeID: Notetype] = [:]
    var currentQueuedCard: QueuedReviewCard?
    private var lastRating: Rating? = nil
    /// Ordered, de-duplicated cards actually answered in the normal session.
    /// Practice Again replays this after Anki has rescheduled the cards.
    private var completedSessionCards: [CardRecord] = []
    private var preparedNext: (id: CardID, card: PreparedCard)?
    @ObservationIgnored private var prefetchTask: Task<Void, Never>?

    var renderedFrontHTML: String = ""
    var renderedBackHTML: String = ""
    var typedAnswerState: TypedAnswerState?
    public var typedAnswer: String = ""

    // MARK: - Computed

    public var isTypedAnswerCard: Bool {
        typedAnswerState?.expected.isEmpty == false
    }

    public var requiresTypedAnswerInput: Bool {
        isTypedAnswerCard && !showAnswer
    }

    public var currentCardOrdinal: UInt32 {
        UInt32(max(0, currentQueuedCard?.card.ord ?? 0))
    }

    public struct TemplateTarget: Identifiable, Equatable, Sendable {
        public let notetypeId: NotetypeID
        public let ordinal: Int

        public var id: String { "\(notetypeId.rawValue)-\(ordinal)" }
    }

    public var currentTemplateTarget: TemplateTarget? {
        guard let card = currentQueuedCard?.card, let note = currentNote else { return nil }
        return TemplateTarget(notetypeId: note.mid, ordinal: Int(card.ord))
    }

    public var currentCardId: CardID? {
        currentQueuedCard?.card.id
    }

    public var canPracticeAgain: Bool {
        !completedSessionCards.isEmpty
    }

    // MARK: - Session progress

    public var sessionTotal: Int {
        sessionStats.reviewed + remainingCounts.total
    }

    public var cardPosition: Int {
        min(sessionStats.reviewed + 1, max(sessionTotal, 1))
    }

    public var progressFraction: Double {
        sessionTotal > 0 ? Double(sessionStats.reviewed) / Double(sessionTotal) : 0
    }

    var currentFlag: UInt32 {
        UInt32(max(0, currentQueuedCard?.card.flags ?? 0)) & 0b111
    }

    @ObservationIgnored public private(set) lazy var mediaFolder: URL? = {
        @Dependency(\.mediaClient) var mediaClient
        return mediaClient.folderURL()
    }()

    // MARK: - Init

    public init(deckId: DeckID, mode: ReviewMode = .review) {
        self.deckId = deckId
        self.mode = mode
    }

    // MARK: - Public interface

    public func start() {
        guard !isAdvancing else { return }
        isAdvancing = true
        startError = nil
        // Resolve the Sendable service facades here, in the caller's
        // dependency scope, then hand them to the off-actor work.
        let decks = self.decks
        let scheduler = self.scheduler
        let notes = self.notes
        let notetypes = self.notetypes
        let notetypesClient = self.notetypesClient
        let cardRendering = self.cardRendering
        let cardClient = self.cardClient
        let deckId = self.deckId
        Task {
            defer { isAdvancing = false }
            do {
                if mode == .practice {
                    let (cards, name) = try await Task.detached { () async throws -> ([CardRecord], String) in
                        guard let deck = try decks.fetchAll().first(where: { $0.id == deckId }) else {
                            return ([], "")
                        }
                        return (try await cardClient.fetchForPractice(DeckSearch.term(deck.name), 200), deck.name)
                    }.value
                    cardQueue = cards.map(QueuedReviewCard.practice)
                    deckName = name
                    remainingCounts = Self.practiceCounts(cards)
                } else {
                    let (queue, name) = try await Task.detached { () -> (QueuedCardsResult, String) in
                        try decks.setCurrentDeck(deckId)
                        let name = (try? decks.getCurrentDeck().name) ?? ""
                        return (try scheduler.getQueuedCards(200), name)
                    }.value
                    cardQueue = queue.cards
                    deckName = name
                    remainingCounts = DeckCounts(
                        newCount: queue.newCount,
                        learnCount: queue.learningCount,
                        reviewCount: queue.reviewCount
                    )
                    Log.review.info("Started with \(self.cardQueue.count) cards, counts: new=\(queue.newCount) learn=\(queue.learningCount) review=\(queue.reviewCount)")
                }
                await advanceToNextCard(notes: notes, notetypes: notetypes, notetypesClient: notetypesClient, cardRendering: cardRendering)
            } catch {
                // NOT isFinished: that is the "queue ran dry" state and drives
                // the congratulations surface plus a success haptic. A start
                // failure gets its own state and a retry.
                Log.review.error("Start failed: \(error)")
                startError = error.localizedDescription
            }
        }
    }

    /// Replays cards answered in the just-finished normal session. It never
    /// asks Anki for a new due queue: those cards have already been rescheduled.
    public func practiceAgain() {
        guard !completedSessionCards.isEmpty else { return }
        mode = .practice
        resetPracticeRun(cards: completedSessionCards)
    }

    /// Flips to the answer side immediately. For typed-answer cards the diff
    /// is computed off the main actor and substituted when it lands — the
    /// `compareAnswer` FFI call used to run inline here, blocking the main
    /// thread at the exact moment of the tap.
    public func revealAnswer() {
        guard !showAnswer else { return }
        backHTML = strippingTypedAnswerPlaceholders(from: renderedBackHTML)
        showAnswer = true

        guard let state = typedAnswerState else { return }
        let typed = typedAnswer
        let rendered = renderedBackHTML
        let cardRendering = self.cardRendering
        let cardId = currentCardId
        Task {
            let html = await Task.detached {
                typedAnswerBackHTML(
                    state: state,
                    typedAnswer: typed,
                    renderedBackHTML: rendered,
                    cardRendering: cardRendering
                )
            }.value
            // The card can advance while the diff is in flight; don't paste a
            // stale answer over the new card.
            guard cardId == currentCardId, showAnswer else { return }
            backHTML = html
        }
    }

    public func answer(rating: Rating) {
        guard !isAdvancing, let queued = currentQueuedCard else { return }
        isAdvancing = true

        // ContinuousClock, not Date: a backwards wall-clock adjustment
        // (NTP correction, manual change) mid-review made this negative,
        // and UInt32(negative) traps. Clamped as well, since a card left
        // open for ~49.7 days would overflow.
        let elapsed = reviewStartTime.duration(to: .now)
        let elapsedMs = elapsed.components.seconds * 1000
            + elapsed.components.attoseconds / 1_000_000_000_000_000
        let timeSpent = UInt32(min(max(elapsedMs, 0), Int64(UInt32.max)))
        let cardId = queued.card.id
        let states = queued.states
        let scheduler = self.scheduler
        let notes = self.notes
        let notetypes = self.notetypes
        let notetypesClient = self.notetypesClient
        let cardRendering = self.cardRendering

        answerTapCount += 1
        tappedRating = rating

        // Practice is a local replay: the rating records accuracy in the
        // session and pops the queue, but never reaches the scheduler. This
        // is what makes it harmless from the collection's point of view.
        guard mode == .review else {
            Task {
                defer { isAdvancing = false }
                await AppSignpost.measure("PracticeCard") {
                    await answerPracticeLocally(rating: rating, timeSpent: timeSpent)
                }
            }
            return
        }

        // The interval brackets the whole tap-to-next-card wait, not the
        // synchronous prologue above: the scheduler round-trip and the
        // advance are what the user actually waits on.
        Task {
            defer { isAdvancing = false }
            await AppSignpost.measure("AnswerCard") {
                do {
                    let queue = try await Task.detached {
                        try scheduler.answerReviewCard(cardId, rating, timeSpent, states)
                        return try scheduler.getQueuedCards(200)
                    }.value

                    answerError = nil
                    if !completedSessionCards.contains(where: { $0.id == queued.card.id }) {
                        completedSessionCards.append(queued.card)
                    }
                    sessionStats.reviewed += 1
                    if rating != .again { sessionStats.correct += 1 }
                    sessionStats.totalTimeMs += Int(timeSpent)
                    lastRating = rating
                    canUndo = true

                    cardQueue = queue.cards
                    remainingCounts = DeckCounts(
                        newCount: queue.newCount,
                        learnCount: queue.learningCount,
                        reviewCount: queue.reviewCount
                    )
                    await advanceToNextCard(notes: notes, notetypes: notetypes, notetypesClient: notetypesClient, cardRendering: cardRendering)
                } catch {
                    // Do NOT drop the card. Silently removing it from the queue
                    // and advancing meant the review was never recorded, the
                    // card was skipped for the session, remainingCounts drifted
                    // permanently from the backend's, and the user saw an
                    // entirely normal advance.
                    Log.review.error("Answer failed: \(error)")
                    answerError = error.localizedDescription
                }
            }
        }
    }

    public func undo() {
        guard canUndo, !isAdvancing else { return }
        isAdvancing = true

        let collection = self.collection
        let scheduler = self.scheduler
        let notes = self.notes
        let notetypes = self.notetypes
        let notetypesClient = self.notetypesClient
        let cardRendering = self.cardRendering

        Task {
            defer { isAdvancing = false }
            do {
                let queue = try await Task.detached {
                    try collection.undoLast()
                    // Re-fetch queue — Anki places the undone card at the front
                    return try scheduler.getQueuedCards(200)
                }.value

                canUndo = false
                undoneCount += 1
                // Roll back session stats only if the operation we just
                // undid was actually an answer. undoLast() undoes the last
                // *collection* operation, and a note edit is reachable from
                // this screen (refreshAfterEdit) — decrementing regardless
                // drove the counters below their true value, and negative.
                if let last = lastRating {
                    sessionStats.reviewed = max(0, sessionStats.reviewed - 1)
                    if last != .again {
                        sessionStats.correct = max(0, sessionStats.correct - 1)
                    }
                }
                lastRating = nil

                cardQueue = queue.cards
                remainingCounts = DeckCounts(
                    newCount: queue.newCount,
                    learnCount: queue.learningCount,
                    reviewCount: queue.reviewCount
                )
                await advanceToNextCard(notes: notes, notetypes: notetypes, notetypesClient: notetypesClient, cardRendering: cardRendering)
            } catch {
                Log.review.error("Undo failed: \(error)")
            }
        }
    }

    public func updateAudioPlaying(_ playing: Bool) {
        isAudioPlaying = playing
    }

    public func updateCardChrome(color: Color, isDark: Bool) {
        cardChromeColor = color
        cardChromeIsDark = isDark
    }

    public func bumpReplayRequest() {
        replayRequestID += 1
    }

    public func bumpStopAudioRequest() {
        stopAudioRequestID += 1
    }

    /// Re-renders the current card after the note or template was edited.
    /// The whole engine round-trip runs off the main actor — it used to call
    /// `getNote` and `renderCard` inline, blocking the main thread while the
    /// edit sheet was dismissing.
    public func refreshAfterEdit() async {
        guard let queued = currentQueuedCard else { return }
        invalidatePrefetch()   // the edit may have changed a shared notetype

        let notes = self.notes
        let notetypes = self.notetypes
        let notetypesClient = self.notetypesClient
        let cardRendering = self.cardRendering
        let cache = notetypeCache
        let prepared = await Task.detached {
            await prepareCard(
                for: queued,
                notes: notes,
                notetypes: notetypes,
                cardRendering: cardRendering,
                notetypesClient: notetypesClient,
                notetypeCache: cache
            )
        }.value

        guard currentQueuedCard?.card.id == queued.card.id else { return }

        currentNote = prepared.note
        if let notetype = prepared.notetype {
            notetypeCache[notetype.id] = notetype
        }
        renderedFrontHTML = prepared.renderedFrontHTML
        renderedBackHTML = prepared.renderedBackHTML
        cardCSS = prepared.cardCSS
        typedAnswerState = prepared.typedAnswerState
        templateName = prepared.templateName
        frontHTML = prepared.frontHTML
        backHTML = strippingTypedAnswerPlaceholders(from: prepared.renderedBackHTML)
        reresolveCurrentCard()

        if showAnswer, let state = prepared.typedAnswerState {
            // Re-substitute the back placeholder with the diff; the typed text
            // survives the sheet round-trip in `typedAnswer`.
            let typed = typedAnswer
            let rendered = prepared.renderedBackHTML
            let html = await Task.detached {
                typedAnswerBackHTML(
                    state: state,
                    typedAnswer: typed,
                    renderedBackHTML: rendered,
                    cardRendering: cardRendering
                )
            }.value
            guard currentQueuedCard?.card.id == queued.card.id, showAnswer else { return }
            backHTML = html
        }
    }

    /// Re-runs render-mode resolution for the current card against the
    /// latest engine preference / overrides (RenderModeSheet writes).
    /// Cheap: reuses the already-rendered HTML.
    public func reresolveCurrentCard() {
        // The prefetched card was prepared against the *old* preferences.
        invalidatePrefetch()
        guard let queued = currentQueuedCard else { return }
        let prefs = currentRenderEnginePreferences(mid: currentNote?.mid, ord: Int(queued.card.ord))
        let resolution = resolveRenderMode(
            renderedFront: renderedFrontHTML,
            renderedBack: renderedBackHTML,
            css: cardCSS,
            override: prefs.override,
            global: prefs.global
        )
        resolvedMode = resolution.mode
        resolvedByAuto = resolution.byAuto
    }
}

private extension ReviewSession {
    // MARK: - Private: card advancement

    /// Practice-only answer path. Advances the session exactly like a real
    /// review, but the only mutation is the session's own state: the queue
    /// head is dropped locally and `remainingCounts` is decremented by the
    /// answered card's queue kind. No scheduler call, no `getQueuedCards`
    /// refetch, no undo slot (so `undo()` is unreachable via `canUndo`).
    func answerPracticeLocally(rating: Rating, timeSpent: UInt32) async {
        guard let queued = currentQueuedCard else { return }
        answerError = nil
        sessionStats.reviewed += 1
        if rating != .again { sessionStats.correct += 1 }
        sessionStats.totalTimeMs += Int(timeSpent)
        decrementRemainingCounts(for: queued.card.queue)
        cardQueue.removeFirst()

        let notes = self.notes
        let notetypes = self.notetypes
        let notetypesClient = self.notetypesClient
        let cardRendering = self.cardRendering
        await advanceToNextCard(
            notes: notes,
            notetypes: notetypes,
            notetypesClient: notetypesClient,
            cardRendering: cardRendering
        )
    }

    func decrementRemainingCounts(for queue: Int16) {
        switch queue {
        case 0: remainingCounts.newCount = max(0, remainingCounts.newCount - 1)
        case 1, 3: remainingCounts.learnCount = max(0, remainingCounts.learnCount - 1)
        case 2: remainingCounts.reviewCount = max(0, remainingCounts.reviewCount - 1)
        default: remainingCounts.reviewCount = max(0, remainingCounts.reviewCount - 1)
        }
    }

    func resetPracticeRun(cards: [CardRecord]) {
        sessionStats = SessionStats()
        remainingCounts = Self.practiceCounts(cards)
        cardQueue = cards.map(QueuedReviewCard.practice)
        currentQueuedCard = nil
        currentNote = nil
        isFinished = false
        canUndo = false
        showAnswer = false
        answerTapCount = 0
        tappedRating = .good
        undoneCount = 0
        lastRating = nil
        typedAnswer = ""
        typedAnswerState = nil
        invalidatePrefetch()

        let notes = self.notes
        let notetypes = self.notetypes
        let notetypesClient = self.notetypesClient
        let cardRendering = self.cardRendering
        Task {
            await advanceToNextCard(
                notes: notes,
                notetypes: notetypes,
                notetypesClient: notetypesClient,
                cardRendering: cardRendering
            )
        }
    }

    static func practiceCounts(_ cards: [CardRecord]) -> DeckCounts {
        cards.reduce(into: .zero) { counts, card in
            switch card.queue {
            case 0: counts.newCount += 1
            case 1, 3: counts.learnCount += 1
            default: counts.reviewCount += 1
            }
        }
    }

    /// Advances to the next queued card. Pops the queue on the main actor,
    /// then renders the card off the main actor via `Task.detached` and
    /// assigns the resulting state back here. The scheduler/queue mutation
    /// already happened in the caller; this only prepares display state.
    func advanceToNextCard(
        notes: NotesService,
        notetypes: NotetypesService,
        notetypesClient: NotetypesClient,
        cardRendering: CardRenderingService
    ) async {
        guard let next = cardQueue.first else {
            isFinished = true
            currentQueuedCard = nil
            currentNote = nil
            invalidatePrefetch()
            return
        }

        let prepared: PreparedCard
        if let hit = preparedNext, hit.id == next.card.id {
            prepared = hit.card
        } else {
            let cache = notetypeCache
            prepared = await Task.detached {
                await prepareCard(
                    for: next,
                    notes: notes,
                    notetypes: notetypes,
                    cardRendering: cardRendering,
                    notetypesClient: notetypesClient,
                    notetypeCache: cache
                )
            }.value
        }
        preparedNext = nil

        currentQueuedCard = next
        currentNote = prepared.note
        if let notetype = prepared.notetype {
            notetypeCache[notetype.id] = notetype
        }
        resolvedMode = prepared.resolvedMode
        resolvedByAuto = prepared.resolvedByAuto
        templateName = prepared.templateName
        renderedFrontHTML = prepared.renderedFrontHTML
        renderedBackHTML = prepared.renderedBackHTML
        cardCSS = prepared.cardCSS
        typedAnswerState = prepared.typedAnswerState
        typedAnswer = ""
        frontHTML = prepared.frontHTML
        backHTML = prepared.renderedBackHTML  // back substitution happens at reveal
        nextIntervals = next.nextIntervals
        showAnswer = false
        reviewStartTime = .now
        stopAudioRequestID += 1

        // Spend the user's reading time rendering the card after this one.
        prefetchFollowingCard(
            notes: notes,
            notetypes: notetypes,
            notetypesClient: notetypesClient,
            cardRendering: cardRendering
        )
    }

    // MARK: - Prefetch

    /// Renders the card after the current one while the user reads, into a
    /// single-slot cache. Speculative: the queue is re-fetched on every
    /// answer, so a learning card can resurface and change the head — a miss
    /// just costs the work we would have done anyway.
    func prefetchFollowingCard(
        notes: NotesService,
        notetypes: NotetypesService,
        notetypesClient: NotetypesClient,
        cardRendering: CardRenderingService
    ) {
        prefetchTask?.cancel()
        guard cardQueue.count > 1 else {
            preparedNext = nil
            return
        }
        let next = cardQueue[1]
        guard preparedNext?.id != next.card.id else { return }
        preparedNext = nil

        let cache = notetypeCache
        prefetchTask = Task { [weak self] in
            let prepared = await Task.detached {
                await prepareCard(
                    for: next,
                    notes: notes,
                    notetypes: notetypes,
                    cardRendering: cardRendering,
                    notetypesClient: notetypesClient,
                    notetypeCache: cache
                )
            }.value
            guard !Task.isCancelled else { return }
            self?.preparedNext = (id: next.card.id, card: prepared)
        }
    }

    func invalidatePrefetch() {
        prefetchTask?.cancel()
        prefetchTask = nil
        preparedNext = nil
    }

}

#if DEBUG
extension ReviewSession {
    /// Builds a session with canned display state for SwiftUI previews.
    /// Never calls `start()`, so it touches no backend — `ReviewContent`
    /// previews render the card or finished surface deterministically.
    /// Lives in this file so it can set the `private(set)` display state.
    /// Public because `ReviewContent`'s previews live in the app target.
    public static func preview(
        showAnswer: Bool = false,
        isFinished: Bool = false,
        front: String = "<div class=\"card\">猫</div>",
        back: String = "<div class=\"card\">猫<hr>cat — a small domesticated feline</div>",
        reviewed: Int = 7,
        counts: DeckCounts = DeckCounts(newCount: 5, learnCount: 2, reviewCount: 13)
    ) -> ReviewSession {
        let session = ReviewSession(deckId: DeckID(1))
        session.frontHTML = front
        session.backHTML = back
        session.cardCSS = """
        .card { font-family: -apple-system; font-size: 30px; text-align: center; padding: 24px; }
        hr { margin: 20px 0; border: none; border-top: 1px solid #ccc; }
        """
        session.showAnswer = showAnswer
        session.isFinished = isFinished
        session.sessionStats = SessionStats(reviewed: reviewed, correct: 6, totalTimeMs: 42_000)
        session.remainingCounts = counts
        session.deckName = "한국어 · Vocab Typing"
        session.nextIntervals = [.again: "<1m", .hard: "8m", .good: "1d", .easy: "4d"]
        session.canUndo = reviewed > 0
        session.templateName = "Card 1"
        return session
    }
}
#endif
