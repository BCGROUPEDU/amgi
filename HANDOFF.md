# Agent handoff

## FuriLens vocabulary receiver (2026-10-18)

- Branch: `codex/m800-furilens-vocabulary-handoff`, based on `4e9ade4ba0089225abe820b7ea5eca7ded30f464`.
- `AppCore` now parses `amgi://` routes centrally. The existing `review?deckId=` route remains supported; `vocabulary/import` accepts only a bounded, schema-v1, base64url JSON `VocabularyImportDraft`.
- Every field is trimmed and length-limited. Invalid, duplicate, unsupported-schema, oversized, or wrong-scheme payloads fail closed without logging their contents.
- A valid vocabulary route opens the existing `AddNoteView` with common Anki field aliases and the `furilens` tag. It does not write on receipt; users may edit/cancel and must explicitly confirm Add before `NotesService` writes through the existing Rust-owned database.
- No App Group, server transmission, external dependency, signing, entitlement, App ID, or second database was added.
- Deterministic parser/validation/routing tests were added. Local build/test is blocked before source compilation because this Mac has Swift 6.1/Xcode 16.4 while the repository requires Swift tools 6.2. Re-run the mandated XcodeBuildMCP suite with a Swift 6.2-capable Xcode before acceptance.
