# Vocabulary import candidate

Candidate:0.2.0(8), feature branch `codex/vocabulary-export-editor`.
Base:d78f72b. No data, bundle ID, team, entitlements or dependencies changed.

FuriLens sends a schema-v1 JSON draft with optional up-to-two examples
(`japanese`, optional `english`, `source`), request UUID and front-reading
choice. Old payloads still work. Limits:128 surface/reading characters,
5 glosses of512, context/translation1500, example Japanese/English500 and
provenance128;6144 decoded bytes/8192 encoded characters. Invalid drafts
never create notes. No content is added to logs or an external handoff server.

The editor exposes deck choice and compatible one-card Basic Front/Back types.
Front holds the word, optional reading and Japanese examples. Back holds
reading, meaning, source context and matching translation, examples/English/
provenance and source. Only the user's explicit Add saves. Duplicate warnings
allow Keep Editing or Add Anyway; repeat saved request IDs fail closed.
Cancel returns without a new note in that editor.

Saved/cancelled callbacks use only the fixed
`furilens://vocabulary/result?requestID=<UUID>&status=<saved|cancelled>`.
There is no arbitrary callback URL or content in that route. Custom schemes
provide convenience feedback, not authenticated cross-app identity.

## Verification / installation

Actual independent sender/receiver source compatibility234 PASS. New Swift
Testing suites need the existing Xcode26.3 CI path (local Swift6.1.2 is too old).
CI on this feature branch runs AppCoreTests, BrowseFeatureTests and AnkiKitTests
before archiving an unsigned IPA. No tag/public release/TestFlight submission.

Verified2026-10-24: run40049854557 at4460bd9 completed successfully. Downloaded
logs show137/137 tests across those three suites (AppCore34, BrowseFeature70,
AnkiKit33), and unsigned Release archive succeeded. Candidate0.2.0(8) IPA
SHA256:`73a0d4e5a5e67923128877a86c9e5bb973787b37cf7a37bbe0e13ac7b27395a1`.
The phone still has0.2.0(7); secure Mirroring login/SideStore upgrade and physical
edit/Cancel/Add acceptance remain pending. This is not device acceptance.

An unsigned IPA is not an installation receipt. Preserve the user's external
backup, existing SideStore account/team/application identifier and entitlements.
Never uninstall or change IDs to match an inferred signing suffix. On a labeled
updated receiver use an isolated existing Basic test deck: edit fields, cancel
(zero new notes), add (exactly one note/card), repeat same request, and export the
same word with a different example. Verify returned status and actual note data.
