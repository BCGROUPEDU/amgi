//
//  AddNoteModel.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 22.06.2026.
//

import OSLog
import AppCore
import AppShared
import AnkiBackend
import AnkiKit
import AnkiClients
import AnkiServices
import Dependencies
import Foundation
import SwiftUI

/// Data state + load/save logic for the Add Note form. Mirrors the other
/// screen models: the View owns navigation, the toolbar, and dismissal,
/// while the model owns deck/notetype loading, field assembly, and the note
/// write so the form stays testable and the View stays thin.
@Observable
@MainActor
final class AddNoteModel {
    var decks: [DeckInfo] = []
    var notetypeNames: [(id: NotetypeID, name: String)] = []
    var selectedDeckId: DeckID = DeckID(1)
    var selectedNotetypeId: NotetypeID = NotetypeID(0)
    var fieldNames: [String] = []
    var fieldValues: [String] = []
    var tags: String = ""
    var isSaving = false
    var hasSaved = false
    var showDuplicateWarning = false
    var errorMessage: String?

    @ObservationIgnored @Dependency(\.deckClient) private var deckClient
    @ObservationIgnored @Dependency(\.notetypesService) private var notetypesService
    @ObservationIgnored @Dependency(\.notesService) private var notesService
    @ObservationIgnored @Dependency(\.collectionStore) private var store

    @ObservationIgnored private let preselectedDeckId: DeckID?
    @ObservationIgnored private let initialDraft: AddNoteDraft?
    @ObservationIgnored private let isVocabularyImport: Bool
    @ObservationIgnored private let vocabularyTag: String?
    @ObservationIgnored private let requestTag: String?

    @ObservationIgnored private var baselineFieldValues: [String] = []
    @ObservationIgnored private var baselineTags: String = ""
    @ObservationIgnored private var warnedDuplicateQuery: String?

    var hasUnsavedChanges: Bool {
        fieldValues != baselineFieldValues || tags != baselineTags
    }

    init(
        preselectedDeckId: DeckID? = nil,
        initialDraft: AddNoteDraft? = nil,
        isVocabularyImport: Bool = false,
        vocabularyTag: String? = nil,
        requestTag: String? = nil
    ) {
        self.preselectedDeckId = preselectedDeckId
        self.initialDraft = initialDraft
        self.isVocabularyImport = isVocabularyImport
        self.vocabularyTag = vocabularyTag
        self.requestTag = requestTag
    }

    var canSave: Bool {
        !isSaving && !hasSaved && !decks.isEmpty && selectedNotetypeId.rawValue != 0
            && !fieldValues.allSatisfy(\.isEmpty)
            && (!isVocabularyImport || hasCompatibleFields)
    }

    private var hasCompatibleFields: Bool {
        fieldNames.first == "Front" && fieldNames.contains("Back")
    }

    /// Positional projection into `fieldValues`, read through `@Bindable` as
    /// `$model[fieldAt: index]`. A subscript rather than a
    /// `Binding(get:set:)`-returning method so the field editors get a stable
    /// binding instead of a freshly-allocated closure pair on every body pass.
    subscript(fieldAt index: Int) -> String {
        get { index < fieldValues.count ? fieldValues[index] : "" }
        set { if index < fieldValues.count { fieldValues[index] = newValue } }
    }

    func loadData() async {
        decks = (try? await deckClient.fetchAll()) ?? []
        if let preselectedDeckId, decks.contains(where: { $0.id == preselectedDeckId }) {
            selectedDeckId = preselectedDeckId
        } else if let first = decks.first {
            selectedDeckId = first.id
        } else if isVocabularyImport {
            errorMessage = "No deck is available in this collection."
        }

        do {
            let service = notetypesService
            notetypeNames = try await backendOffload { try service.getNotetypeNames() }
            if isVocabularyImport {
                // An incoming note needs two real editable fields. A Cloze or
                // one-field notetype would silently discard the back.
                var compatible: [(id: NotetypeID, name: String)] = []
                for entry in notetypeNames {
                    let info = try await backendOffload { try service.getNotetype(entry.id) }
                    if info.supportsSingleCardVocabulary {
                        compatible.append(entry)
                    }
                }
                notetypeNames = compatible
                if compatible.isEmpty {
                    errorMessage = "No compatible Front/Back note type is available in this collection."
                }
            }
            let chosen = initialDraft?.notetypeID
                .flatMap { id in notetypeNames.first(where: { $0.id.rawValue == id }) }
                ?? (isVocabularyImport
                    ? notetypeNames.first(where: { $0.name.localizedCaseInsensitiveContains("basic") })
                    : nil)
                ?? notetypeNames.first
            if let chosen {
                selectedNotetypeId = chosen.id
                await loadFields()
            }
        } catch {
            Log.browse.error("Error loading notetypes")
            errorMessage = "Couldn't load note types. Try opening the editor again."
        }

        if let initialDraft, !initialDraft.tags.isEmpty {
            tags = initialDraft.tags.joined(separator: " ")
        }
        baselineTags = tags
    }

    func loadFields() async {
        guard selectedNotetypeId.rawValue != 0 else { return }
        let id = selectedNotetypeId
        fieldNames = []
        fieldValues = []
        do {
            let service = notetypesService
            let notetype = try await backendOffload { try service.getNotetype(id) }
            guard selectedNotetypeId == id else { return }
            fieldNames = notetype.fieldNames
            // Pre-fill from the incoming draft by mapping
            // `fieldValues[name] → fieldValues[positionalIndex]` against the
            // notetype's actual field-name list. Names not present on this
            // notetype are silently dropped.
            fieldValues = fieldNames.map { name in
                initialDraft?.fieldValues[name] ?? ""
            }
            baselineFieldValues = fieldValues
        } catch {
            guard selectedNotetypeId == id else { return }
            Log.browse.error("Error loading fields")
            fieldNames = []
            fieldValues = []
            errorMessage = "Couldn't load note fields. Choose another note type or retry."
        }
    }

    /// Persist the note. Returns whether the write succeeded; on failure
    /// `errorMessage` carries the reason. Navigation/dismissal stays with
    /// the View.
    func save(allowDuplicate: Bool = false) async -> Bool {
        guard !isSaving, !hasSaved, (!isVocabularyImport || canSave) else { return false }
        isSaving = true
        errorMessage = nil
        showDuplicateWarning = false
        defer { isSaving = false }
        do {
            let notes = notesService
            let notetypeID = selectedNotetypeId
            let deckID = selectedDeckId
            let fields = fieldValues
            var tagList = tags.split(separator: " ").map(String.init)
            for protected in [vocabularyTag, requestTag].compactMap({ $0 }) where !tagList.contains(protected) {
                tagList.append(protected)
            }
            if isVocabularyImport {
                // Anki's dupe operator checks the notetype's first field using
                // the engine's own normalization. Errors stop the write.
                let firstField = fields[0]
                    .replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#39;", with: "'")
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !firstField.isEmpty else {
                    errorMessage = "Enter a Front value before adding this note."
                    return false
                }
                let escaped = firstField.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                let query = "\"dupe:\(notetypeID.rawValue),\(escaped)\""
                if let requestTag {
                    let replay = try await backendOffload { try notes.searchNoteIds("tag:\(requestTag)") }
                    if !replay.isEmpty {
                        errorMessage = "This vocabulary request was already saved."
                        return false
                    }
                }
                if allowDuplicate {
                    guard warnedDuplicateQuery == query else {
                        errorMessage = "The Front value changed. Check for duplicates again."
                        return false
                    }
                } else {
                    warnedDuplicateQuery = nil
                    var hasDuplicate = false
                    if let vocabularyTag {
                        let tagged = try await backendOffload { try notes.searchNoteIds("tag:\(vocabularyTag)") }
                        hasDuplicate = !tagged.isEmpty
                    }
                    let firstFieldMatches = try await backendOffload { try notes.searchNoteIds(query) }
                    if hasDuplicate || !firstFieldMatches.isEmpty {
                        warnedDuplicateQuery = query
                        showDuplicateWarning = true
                        return false
                    }
                }
            }
            try await backendOffload {
                var template = try notes.newNote(notetypeID)
                template.fields = fields
                template.tags = tagList
                try notes.addNote(template, deckID)
            }
            // addNote doesn't surface OpChanges yet — invalidate the shared
            // tree cache conservatively so every host (DeckDetail, reader
            // lookup, Browse) sees fresh counts.
            store.apply(CollectionChanges(card: true, note: true, studyQueues: true))
            hasSaved = true
            return true
        } catch {
            errorMessage = "Couldn't check or add this note: \(error.localizedDescription)"
            return false
        }
    }
}
