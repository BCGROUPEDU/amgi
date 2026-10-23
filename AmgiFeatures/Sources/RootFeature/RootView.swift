//
//  RootView.swift
//  RootFeature
//
//  Created by Vladimir Gusev on 29.08.2026.
//

public import SwiftUI
import AppCore
import AppShared
import BrowseFeature
import Theme
import AnkiKit
import Dependencies
import Foundation
import ReaderFeature
import ReviewFeature
import Sharing
import SyncFeature

/// The app's whole view composition. The host target supplies only `@main`.
///
/// Owns the routing between onboarding, the tab bar, and the startup-error
/// screen; the cross-cutting flows above the tabs (sync, deck import, the
/// review cover); and the root chrome (`.themedRoot()`, the app font, the
/// profile re-id, the deep link, the scene-phase widget refresh).
public struct RootView: View {
    public init() {}

    @Shared(.onboardingCompleted) private var onboardingCompleted
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Shared(.appStorage(AppearancePreferences.Keys.appFont))
    private var appFontRaw: String = AppFont.system.rawValue

    @Dependency(\.collectionStore) private var store
    @Bindable private var accountStore = AccountStore.shared

    @State private var pendingReviewDeckId: DeckID?
    @State private var queuedReviewDeckId: DeckID?
    @State private var pendingVocabulary: PendingVocabulary?
    @State private var queuedVocabulary: [PendingVocabulary] = []
    @State private var completedVocabulary: (draft: VocabularyImportDraft, status: VocabularyImportStatus)?
    @State private var handoffAlert: String?
    @State private var showImport = false
    @State private var refreshID = UUID()

    @Shared(.appStorage(ReaderPreferences.Keys.showTab))
    private var showReaderTab: Bool = true

    public var body: some View {
        routed
            // Rebuild the entire view tree when the active profile changes —
            // every screen holds state derived from the previously open
            // collection. `.id(_:)` sets identity for `routed` and its
            // subtree only; it does not touch state held on `RootView`
            // itself, so `pendingReviewDeckId` needs the explicit clear
            // below.
            .id(accountStore.selectedID)
            .onChange(of: accountStore.selectedID) {
                let cancelled = ([pendingVocabulary].compactMap { $0 } + queuedVocabulary).map(\.vocabulary)
                pendingVocabulary = nil
                queuedVocabulary = []
                completedVocabulary = nil
                for draft in cancelled {
                    if let result = draft.resultURL(status: .cancelled) { openURL(result) }
                }
                pendingReviewDeckId = nil
                queuedReviewDeckId = nil
                presentPendingRoute()
            }
            .onChange(of: onboardingCompleted) { presentPendingRoute() }
            .onChange(of: showImport) { if !showImport { presentPendingRoute() } }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await writeWidgetSnapshot() }
                    presentPendingRoute()
                }
            }
            .onOpenURL { url in
                guard let route = AmgiDeepLinkParser.parse(url) else { return }
                switch route {
                case .review(let deckID):
                    queuedReviewDeckId = DeckID(deckID)
                case .vocabulary(let vocabulary):
                    if let requestID = vocabulary.requestID {
                        let isQueued = queuedVocabulary.contains { $0.vocabulary.requestID == requestID }
                        if pendingVocabulary?.vocabulary.requestID == requestID || isQueued {
                            return
                        }
                    }
                    if AmgiRoot.startupError != nil {
                        handoffAlert = "The collection couldn't be opened, so this word can't be added yet."
                        if let result = vocabulary.resultURL(status: .cancelled) { openURL(result) }
                        return
                    }
                    guard queuedVocabulary.count < 8 else {
                        handoffAlert = "Too many vocabulary requests are waiting. Open this word again after finishing one."
                        if let result = vocabulary.resultURL(status: .cancelled) { openURL(result) }
                        return
                    }
                    queuedVocabulary.append(PendingVocabulary(vocabulary: vocabulary))
                }
                presentPendingRoute()
            }
            .themedRoot()
            .alert("Vocabulary import unavailable", isPresented: Binding(
                get: { handoffAlert != nil },
                set: { if !$0 { handoffAlert = nil } }
            )) {
                Button("OK", role: .cancel) { handoffAlert = nil }
            } message: {
                Text(handoffAlert ?? "")
            }
            .environment(\.appFont, AppFont(rawValue: appFontRaw) ?? .system)
    }

    @ViewBuilder
    private var routed: some View {
        if let startupError = AmgiRoot.startupError {
            StartupErrorView(message: startupError)
        } else if onboardingCompleted {
            main
        } else {
            OnboardingView()
        }
    }

    private var main: some View {
        MainTabView(
            refreshID: refreshID,
            showReaderTab: showReaderTab,
            onImport: { showImport = true },
            onSelectStudyDeck: {
                queuedReviewDeckId = $0
                presentPendingRoute()
            }
        )
        .alert(
            "Couldn't switch profile",
            isPresented: $accountStore.hasSwitchFailure
        ) {
            Button("OK", role: .cancel) { accountStore.switchFailure = nil }
        } message: {
            Text(accountStore.switchFailure ?? "")
        }
        // still drives the tabs not yet on CollectionStore
        .syncFlow { refreshID = UUID() }
        .deckImport(isPresented: $showImport) {
            store.invalidateAll()
            refreshID = UUID()
        }
        .fullScreenCover(item: $pendingReviewDeckId, onDismiss: presentPendingRoute) { deckId in
            ReviewView(deckId: deckId) {
                pendingReviewDeckId = nil
                store.invalidateAll()
                refreshID = UUID()
            }
        }
        .sheet(item: $pendingVocabulary, onDismiss: vocabularyDidDismiss) { pending in
            AddNoteView(
                initialDraft: pending.addNoteDraft,
                isVocabularyImport: true,
                vocabularyTag: pending.vocabulary.vocabularyTag,
                requestTag: pending.vocabulary.requestTag,
                onCancel: {
                    completedVocabulary = (pending.vocabulary, .cancelled)
                },
                onSave: {
                    completedVocabulary = (pending.vocabulary, .saved)
                    store.invalidateAll()
                    refreshID = UUID()
                }
            )
        }
        .environment(\.lookupPopup, ReaderLookupPopup())
        .environment(\.dictionarySettings, ReaderDictionarySettings())
    }

    private func presentPendingRoute() {
        guard onboardingCompleted, AmgiRoot.startupError == nil, !showImport,
              scenePhase == .active,
              pendingReviewDeckId == nil, pendingVocabulary == nil,
              completedVocabulary == nil else { return }
        if let review = queuedReviewDeckId {
            queuedReviewDeckId = nil
            pendingReviewDeckId = review
        } else if !queuedVocabulary.isEmpty {
            pendingVocabulary = queuedVocabulary.removeFirst()
        }
    }

    private func vocabularyDidDismiss() {
        if let completedVocabulary {
            self.completedVocabulary = nil
            if let result = completedVocabulary.draft.resultURL(status: completedVocabulary.status) {
                openURL(result)
            }
        }
        presentPendingRoute()
    }
}

private struct PendingVocabulary: Identifiable {
    let id = UUID()
    let vocabulary: VocabularyImportDraft

    var addNoteDraft: AddNoteDraft {
        AddNoteDraft(
            fieldValues: vocabulary.addNoteFieldValues,
            tags: ["furilens"]
        )
    }
}
