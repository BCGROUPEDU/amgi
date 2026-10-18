# Agent handoff

## M9 bounded handoff QA (2026-10-18)

- Branch: `codex/m900-handoff-qa`, based on clean handoff commit `4fcc4c7c55521113ea12dbc5b011b90443ae93fd`. Keep this branch isolated for review; no main merge.
- `AddNoteModel.save()` rejects overlapping calls before changing save state. Cancel and interactive sheet dismissal are disabled while an Add write is in flight. The existing notes service and Rust write path remain in use.
- `BrowseFeatureTests/AddNoteSaveTests.swift` gates a mocked existing `newNote` service call, checks that a second save cannot begin another note or unlock the first, and checks that a failed save allows retry. It throws before any database/template is required.
- Original FuriLens sender and Amgi receiver sources compiled together in an isolated `/private/tmp/amgi-m9.1cPFQQ` harness using local Swift 6.1.2 in Swift 6 language mode: 218 checks passed, including 191 sender-accepted deterministic corpus payloads; nine larger corpus payloads were correctly rejected by the sender. This validates the pure payload path, not the Swift 6.2 package or on-device flow.
- Isolated model harness executed both the pre-fix and guarded model with dependency adapters: original reproduced two creation attempts and premature save-state release; fixed retained one attempt and active state, then reset after failure and allowed retry. Both touched zero database records. The changed Swift files pass syntax parsing and git diff --check. The new package regression test has not executed in a compatible full package environment.
- Local full build remains blocked: macOS 15.5, Xcode 16.4/Swift 6.1.2, and no `AnkiRustLib.xcframework`. No toolchain, dependency, signing, collection, or stash changes were made. The existing cloud workflow selects Xcode 26.3; it currently builds but does not execute the package tests.
- Remaining QA risk: note-type selection falls back to the first existing type. A Cloze type receives plain `Text` without a cloze marker, and custom unmatched fields are omitted. No general authoring or dictionary behavior was changed. A Swift 6.2-capable app build, focused package test execution, and device Add/cancel/rapid-tap checks remain necessary before acceptance; device exactly-once persistence has not been demonstrated.

## FuriLens vocabulary receiver (2026-10-18)

- Branch: `codex/m800-furilens-vocabulary-handoff`, based on `4e9ade4ba0089225abe820b7ea5eca7ded30f464`.
- `AppCore` now parses `amgi://` routes centrally. The existing `review?deckId=` route remains supported; `vocabulary/import` accepts only a bounded, schema-v1, base64url JSON `VocabularyImportDraft`.
- Every field is trimmed and length-limited. Invalid, duplicate, unsupported-schema, oversized, or wrong-scheme payloads fail closed without logging their contents.
- A valid vocabulary route opens the existing `AddNoteView` with common Anki field aliases and the `furilens` tag. It does not write on receipt; users may edit/cancel and must explicitly confirm Add before `NotesService` writes through the existing Rust-owned database.
- No App Group, server transmission, external dependency, signing, entitlement, App ID, or second database was added.
- Deterministic parser/validation/routing tests were added, and `swiftc -parse` passes for the changed Swift files. Full local build/test is blocked before source compilation because this Mac has Swift 6.1/Xcode 16.4 while the repository requires Swift tools 6.2. Re-run the mandated XcodeBuildMCP suite with a Swift 6.2-capable Xcode before acceptance.
