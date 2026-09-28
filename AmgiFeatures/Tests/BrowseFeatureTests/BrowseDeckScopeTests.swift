//
//  BrowseDeckScopeTests.swift
//  BrowseFeatureTests
//
//  Created by Vladimir Gusev on 28.09.2026.
//

import AnkiClients
import AnkiKit
import AnkiServices
import Dependencies
import Foundation
import Testing
@testable import BrowseFeature

/// The Decks→Browse (and Review→Browse) edge opens Browse pre-scoped to a
/// deck: the very first query must be `deck:"<name>"` so the user sees only
/// that deck's notes, with the filter bar still able to widen to the whole
/// collection. Nothing about this scope mutates the collection.
@Suite("BrowseModel deck scope")
@MainActor
struct BrowseDeckScopeTests {

    @Test("initialDeck pre-selects the parent and active filter, escaping the deck name")
    func initialDeckScopesTheQuery() {
        let deck = DeckInfo(id: DeckID(7), name: "日::Vocabulary \"core\"", counts: .zero)

        let model = BrowseModel(initialDeck: deck)

        #expect(model.parentDeck == deck)
        #expect(model.activeDeck == deck)
        #expect(model.searchQuery == #"deck:"日::Vocabulary \"core\"""#, "quotes and separators must come out of DeckSearch.term already escaped")
    }

    @Test("the deck scope is read-only — clearing the active deck widens to the whole collection")
    func clearingTheDeckFilterWidens() {
        let deck = DeckInfo(id: DeckID(7), name: "Vocabulary", counts: .zero)
        let model = BrowseModel()
        model.activeDeck = deck
        #expect(model.searchQuery == #"deck:"Vocabulary""#)

        model.activeDeck = nil
        #expect(model.searchQuery.isEmpty)
    }

    @Test("leading whitespace is trimmed before the deck term is appended")
    func textCombinesAfterTheDeckTerm() {
        let deck = DeckInfo(id: DeckID(7), name: "Vocabulary", counts: .zero)
        let model = BrowseModel(initialDeck: deck)
        model.searchText = " kanji "

        #expect(model.searchQuery == #"deck:"Vocabulary" kanji"#)
    }
}