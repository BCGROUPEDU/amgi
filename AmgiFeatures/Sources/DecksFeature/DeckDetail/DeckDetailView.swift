//
//  DeckDetailView.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import SwiftUI
import AppShared
import Theme
import UI
import AnkiKit
import AnkiClients
import Dependencies
import BrowseFeature
import Foundation

struct DeckDetailView: View {
    let deck: DeckInfo

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.collectionStore) private var store
    @State private var model: DeckDetailModel
    @State private var destination: DeckDetailDestination?
    @State private var newSubdeckName = ""
    @State private var limitDelta = ""
    @State private var pendingSubdeck: DeckInfo?

    init(deck: DeckInfo) {
        self.deck = deck
        _model = State(initialValue: DeckDetailModel(deck: deck))
    }

    private var shortTitle: String {
        Self.leafName(from: deck.name)
    }

    static func leafName(from fullName: String) -> String {
        String(fullName.split(separator: "::", omittingEmptySubsequences: true).last ?? Substring(fullName))
    }

    private var currentAlert: DeckDetailAlert? {
        if case .alert(let a) = destination { return a }
        return nil
    }

    private var alertTitle: String {
        guard let alert = currentAlert else { return "" }
        switch alert {
        case .empty: return "Empty \"\(shortTitle)\"?"
        case .delete: return "Delete \"\(shortTitle)\"?"
        case .error(let title, _): return title
        }
    }

    private var viewState: DeckDetailViewState {
        guard model.hasLoaded else { return .loading }
        let isEmpty = model.isEmpty
        let subtitle: String = {
            if let snap = model.statsSnapshot, !snap.subtitle.isEmpty { return snap.subtitle }
            return isEmpty
                ? "No cards yet · Add some to start studying"
                : "Tap Study to start a session"
        }()
        let insights = model.statsSnapshot?.insights ?? .empty
        return .loaded(DeckDetailViewData(
            title: shortTitle,
            subtitle: subtitle,
            tone: DeckTonePalette.tone(for: deck.name),
            deckName: shortTitle,
            tileCounts: DeckDetailTileData(
                newCount: model.counts.newCount,
                learnCount: model.counts.learnCount,
                reviewCount: model.counts.reviewCount
            ),
            isFiltered: deck.isFiltered,
            isEmpty: isEmpty,
            subdecks: model.childDecks.map(Self.subdeckRow(from:)),
            insights: insights,
            isActionInFlight: model.actionInFlight
        ))
    }

    var body: some View {
        contentWithToolbar
            .modifier(SheetCoverModifier(
                destination: $destination,
                deck: deck,
                onReviewDismiss: {
                    destination = nil
                    store.invalidateAll()
                },
                sheetContent: { sheet in AnyView(sheetContent(for: sheet)) }
            ))
            .modifier(AlertModifier(
                destination: $destination,
                currentAlert: currentAlert,
                alertTitle: alertTitle,
                alertActions: { AnyView(alertActions(for: $0)) },
                alertMessage: { AnyView(alertMessage(for: $0)) }
            ))
            .overlay(alignment: .bottom) {
                FeedbackToast(feedback: model.feedback) { model.feedback = nil }
            }
            .animation(AmgiMotion.momentum, value: model.feedback)
            .task(id: store.generation) {
                await model.loadCounts()
                await model.loadChildren()
                model.loadStats()
            }
    }

    private var contentWithToolbar: some View {
        DeckDetailScreen(
            state: viewState,
            heatmapSlot: { EmptyView() }, // R03 will inject its chart here.
            onAction: handle
        )
        .navigationTitle(shortTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .navigationDestination(item: $pendingSubdeck) { sub in
            DeckDetailView(deck: sub)
        }
    }

    // MARK: - Action dispatch

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Section {
                    Button {
                        destination = .sheet(.addNote)
                    } label: {
                        Label("Add Note…", systemImage: "square.and.pencil")
                    }
                    if !deck.isFiltered {
                        Button {
                            newSubdeckName = ""
                            destination = .sheet(.createSubdeck)
                        } label: {
                            Label("Create Subdeck…", systemImage: "folder.badge.plus")
                        }
                    }
                }
                if !deck.isFiltered {
                    Section {
                        Button {
                            destination = .sheet(.showDeckOptions)
                        } label: {
                            Label("Deck Options…", systemImage: "slider.horizontal.3")
                        }
                        Button {
                            limitDelta = Self.defaultNewDelta
                            destination = .sheet(.extendLimit(.new))
                        } label: {
                            Label("Increase New Limit…", systemImage: "plus.rectangle.on.rectangle")
                        }
                        Button {
                            limitDelta = Self.defaultReviewDelta
                            destination = .sheet(.extendLimit(.review))
                        } label: {
                            Label("Increase Review Limit…", systemImage: "plus.rectangle.on.rectangle")
                        }
                    }
                }
                Section {
                    Button {
                        Task { await runExport() }
                    } label: {
                        Label("Export Deck…", systemImage: "square.and.arrow.up")
                    }
                    .disabled(model.exportInProgress)
                }
                Section {
                    Button(role: .destructive) {
                        destination = .alert(.delete)
                    } label: {
                        Label("Delete Deck…", systemImage: "trash")
                    }
                }
            } label: {
                Label("More", systemImage: "ellipsis")
            }
        }
    }
}

private extension DeckDetailView {
    func handle(_ action: DeckDetailScreen<EmptyView>.Action) {
        switch action {
        case .studyNow:
            destination = .review
        case .browseCards:
            destination = .browse
        case .practice:
            destination = .practice
        case .rebuild:
            Task { await runRebuild() }
        case .emptyDeck:
            destination = .alert(.empty)
        case .subdeckSelected(let row):
            pendingSubdeck = DeckInfo(
                id: DeckID(row.id),
                name: row.fullName,
                counts: DeckCounts(
                    newCount: row.newCount,
                    learnCount: row.learnCount,
                    reviewCount: row.reviewCount
                ),
                isFiltered: row.isFiltered
            )
        }
    }

    @ViewBuilder
    func sheetContent(for sheet: DeckDetailSheet) -> some View {
        switch sheet {
        case .addNote:
            AddNoteView(preselectedDeckId: deck.id) {}
        case .showDeckOptions:
            NavigationStack {
                DeckConfigView(deckId: deck.id, deckName: deck.name) {
                    destination = nil
                    store.apply(CollectionChanges(deck: true, studyQueues: true))
                }
            }
        case .exportFile(let url):
            ShareSheet(items: [url]) {
                destination = nil
                try? FileManager.default.removeItem(at: url)
            }
        case .createSubdeck:
            TextPromptSheet(
                title: "Create Subdeck",
                placeholder: "Subdeck name",
                footer: "Created inside \(shortTitle).",
                confirmLabel: "Create",
                capitalization: .words,
                isValid: { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
                onConfirm: { name in await model.createSubdeck(rawName: name) },
                text: $newSubdeckName
            )
        case .extendLimit(let kind):
            TextPromptSheet(
                title: "Increase Today's \(kind.noun) Limit",
                placeholder: "Extra cards",
                footer: "Extra \(kind.noun.lowercased()) cards to show today, on top of this deck's daily limit. Resets tomorrow.",
                confirmLabel: "Increase",
                keyboard: .numberPad,
                isValid: { Self.parseDelta($0) != nil },
                onConfirm: { text in await runExtendLimit(kind, delta: text) },
                text: $limitDelta
            )
        }
    }

    @ViewBuilder
    func alertActions(for alert: DeckDetailAlert) -> some View {
        switch alert {
        case .empty:
            Button("Empty", role: .destructive) {
                Task { await runEmpty() }
            }
            Button("Cancel", role: .cancel) {}
        case .delete:
            Button("Delete", role: .destructive) {
                Task { await runDelete() }
            }
            Button("Cancel", role: .cancel) {}
        case .error:
            Button("OK", role: .cancel) {}
        }
    }

    @ViewBuilder
    func alertMessage(for alert: DeckDetailAlert) -> some View {
        switch alert {
        case .empty:
            Text("Cards will be returned to their home decks.")
        case .delete:
            Text("This uses Anki's normal deck deletion. Child decks are included when applicable. This action cannot be undone.")
        case .error(_, let message):
            Text(message)
        }
    }

    // MARK: Action bridges (model results → destination state)

    func runRebuild() async {
        if let err = await model.rebuild() {
            destination = .alert(.error(title: "Couldn't rebuild \"\(shortTitle)\"", message: err))
        }
    }

    func runEmpty() async {
        if let err = await model.empty() {
            destination = .alert(.error(title: "Couldn't empty \"\(shortTitle)\"", message: err))
        }
    }

    func runDelete() async {
        if let err = await model.deleteDeck() {
            destination = .alert(.error(title: "Couldn't delete \"\(shortTitle)\"", message: err))
        } else {
            destination = nil
            dismiss()
        }
    }

    func runExport() async {
        switch await model.exportDeck() {
        case .success(let url):
            destination = .sheet(.exportFile(url))
        case .failure(let msg):
            destination = .alert(.error(title: "Couldn't export \"\(shortTitle)\"", message: msg))
        }
    }

    static let defaultNewDelta = "10"
    static let defaultReviewDelta = "50"

    static func parseDelta(_ text: String) -> Int32? {
        guard let value = Int32(text.trimmingCharacters(in: .whitespaces)), value > 0 else { return nil }
        return value
    }

    func runExtendLimit(_ kind: DeckLimitKind, delta: String) async -> String? {
        guard let amount = Self.parseDelta(delta) else { return nil }
        return await model.extendLimit(kind, by: amount)
    }

    // MARK: - Mapping

    static func subdeckRow(from node: DeckTreeNode) -> DeckSubdeckRowData {
        DeckSubdeckRowData(
            id: node.id.rawValue,
            name: node.name,
            fullName: node.fullName,
            newCount: node.counts.newCount,
            learnCount: node.counts.learnCount,
            reviewCount: node.counts.reviewCount,
            isFiltered: node.isFiltered
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    withDependencies {
        $0.deckClient = .previewValue
        $0.statsClient = .previewValue
    } operation: {
        NavigationStack {
            DeckDetailView(deck: .sample)
        }
    }
}
#endif
