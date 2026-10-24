# Agent handoff

## Build8 installed / real-device synthetic receiver checks (2026-10-24)

- User approved installer-only upload to their own iCloud. Destination SHA256
  matches73a0d4e…395a1. SideStore selected exact0.2.0(8)/4460bd9 package and
  Keep App Extensions (Use Main Profile), existing account. Apple tools confirm
  installed **0.2.0(8), com.amgiapp.AmgiApp.26QAK2CBK9**, receipt in counterpart
  FuriLens`build/Amgi-post-update-20261024.json`. No uninstall, source identity/
  signing-setting edit, account change or certificate revocation. Original three
  decks remain visible; collection writes are limited to the QA deck/note below.
- Added isolated FuriLens QA 2026-10-24 deck through app UI. Incoming synthetic
  新宿駅 schema-v1 request opens editable Add Note; all supplied reading/gloss/
  context/translation/example fields present. QA/Basic selected explicitly.
  Edited Front then Cancel/Discard→deck still0/0/0/no cards. New request UUID
  ending6402, explicit Add double-click→one new card and one Browse note row.
  Inspected saved fields without editing/studying. Same UUID replay+Add reports
  **This vocabulary request was already saved.** Cancel→QA remains1/0/0.
  Only one synthetic QA note/card written; no production deck edits or sync.
- Callback opens FuriLens, triggering Mirroring's camera-unavailable notice.
  Quit Mirroring and asked user for actual phone Learn→word→export confirmation.
  Real sender pending-request receipt, OCR, translation and widget behavior are
  not accepted by these synthetic receiver checks. No app deletion to test
  missing receiver. Prior137 cloud and234 source checks remain separate.
- Observed remaining UI issue: Browse displays rich Front <div> tags and editor
  visually concatenates HTML block sections. Saved content is retained; study
  rendering unobserved. Import defaults to first deck; select destination.
  Delivery-only turn, no new code/build/automated suite. A bounded display fix
  needs a separately tested candidate, not an unverified on-device hot patch.

## Receiver package verified / installation awaiting secure login (2026-10-24)

- Exact-source run40049854557 on4460bd98e9b2772b0867c3c58b23950fb01e568c
  completed SUCCESS. Downloaded logs prove **137/137 relevant Swift Testing
  tests PASS**: AnkiKit33/9 suites, AppCore34/4, BrowseFeature70/10. Complete
  three relevant suites, not every repository package. Release ARCHIVE SUCCEEDED.
- Actual unsigned IPA0.2.0(8):30,795,063 bytes, SHA256
  `73a0d4e5a5e67923128877a86c9e5bb973787b37cf7a37bbe0e13ac7b27395a1`,
  matching the run's build summary/source. Safe relative106 ZIP entries,
  com.amgiapp.AmgiApp/amgi scheme/iOS18 minimum, no signature/profile.
  Delivery/evidence directory in FuriLens ignored build/Amgi-vocabulary-4460bd9/.
- Apple tools still report installed0.2.0(7), same SideStore-suffixed identity
  com.amgiapp.AmgiApp.26QAK2CBK9. CUA is blocked at iPhone Mirroring's legitimate
  Mac login prompt; user must enter it locally then keep iPhone physically
  locked for connection. No credentials entered, IPA installed, app removed,
  account/signing identity changed or collection/note written.
- Next: matching existing SideStore account/team/data-preserving upgrade with
  confirmed external backup, verify installed build8, then test editable fields,
  Cancel zero, explicit Add exactly one, duplicate/replay in isolated Basic deck.
  Cross-app physical acceptance is pending, not implied by137 passing tests.

## Replacement verification provenance (2026-10-24)

Repair4460bd98e9b2772b0867c3c58b23950fb01e568c is pushed. One replacement
run **40049854557** uses this exact source and is IN PROGRESS:
https://github.com/BCGROUPEDU/amgi/actions/runs/40049854557 . Old39907143931
FAILED before tests/archive; never use it as IPA or test acceptance evidence.
Actual sender/receiver source checks234 PASS reran; the exact tag-snapshot
pattern typechecks with Swift6 strict concurrency. Full app/suites still need
the compatible cloud result; data/signing/installation remain untouched.

## Receiver compiler repair (2026-10-24)

- Exact run39907143931 on b9eea85 completed FAILURE in simulator
  build-for-testing: AddNoteModel.swift232 captured mutable tagList in
  concurrently executing backendOffload. No tests, archive or IPA were produced.
- Minimal repair snapshots the completed tags into immutable tagsToSave before
  the hop. Payload, duplicate/replay rules, saved fields, note service and data
  semantics are unchanged. Cheap bounded reviewer reproduced the old diagnostic
  and verified the snapshot with Swift6 language/strict concurrency on the host;
  no other newly added mutable captures in this save path were found.
- Full compatible CI rerun is still required; isolated typechecking is not an
  Amgi app pass. Local artifacts remain old0.2.0(7), not this candidate0.2.0(8).
- Paired iPhone inventory confirms existing Amgi0.2.0(7) and FuriLens1.0(3).
  No receiver installation, certificate/profile/identity change or note write.
  FuriLens current signed build stops on missing widget provisioning profile;
  preserve identity/data/backup gates and do not bypass Apple provisioning.

## Exact verification run (2026-10-23)

Feature source **b9eea85edfc2b2ce346afc0fa8587412be2c1e08** is pushed on
`codex/vocabulary-export-editor`. One established workflow dispatched:
https://github.com/BCGROUPEDU/amgi/actions/runs/39907143931 . It is currently
**IN PROGRESS**, not a full-suite/archive/IPA pass. The branch-scoped test step
includes AppCoreTests, BrowseFeatureTests and AnkiKitTests; earlier96/96 M11 is
old-source evidence only. The independent sender/receiver source checks234 PASS.
No new device installation, signing change or note write. Inspect exact run,
repair only real failures, then verify version0.2.0(8)/artifact SHA and preserve
the existing SideStore identity/backup before upgrading. FuriLens counterpart
382796df8295,1.0(5),481 tests/unsigned iphoneos Release PASS; phone acceptance
remains pending while user is away.

## Vocabulary editor / Lock Screen companion integration (2026-10-23, pending verification)

- User requests the full FuriLens vocabulary workflow. Isolated worktree/branch
  `codex/vocabulary-export-editor` from d78f72b preserves the original checkout,
  all data and signing. Candidate version0.2.0(8), same application/widget IDs,
  SDK/dependencies/entitlements. No native Rust/database/scheduling changes.
- Schema-v1 optional bounded examples/provenance, requestUUID and front-reading
  switch preserve legacy payloads. Every incoming text is validated and HTML
  escaped. Fixed content-free completion URLs only after explicit save/cancel;
  no note creation on URL receipt. Sender and receiver source harness234 PASS.
- Root queues at most8 requests behind onboarding/review/import, rejects
  repeated active request IDs and clears drafts on profile switch. Editor uses
  existing deck picker and single-card normal Front/Back type metadata; no new
  database/templates/decks. Native tag/dupe queries warn on same vocabulary,
  protect saved-request replay, and stop writes on query failures. Add Anyway
  is explicit; fields disable during writes and completed saves cannot repeat.
- Word fingerprint follows the original FuriLens word if someone edits rich
  Front afterward; this is a conservative warning, not semantic deduplication.
  Existing arbitrary legacy cards without the fingerprint remain limited by
  Anki's first-field matching. Custom/localized field names and reversed/Cloze
  types deliberately require a compatible Basic type rather than lossy mapping.
- Deterministic receiver/parser, duplicate/replay/confirmation/overlap/save-state
  and normal-vs-Cloze/reversed type tests added. Complete iOS suites/build are
  pending the established Xcode26.3 workflow; localXcode16.4/Swift6.1.2 and missing
  native framework cannot validate Swift6.2 packages. CI branch gate now covers
  this new branch only in addition to M11, plus AnkiKitTests; no public release.
- Full successful AddNoteModel write cannot be mocked from the feature package
  because NewNoteTemplate has an intentional cross-package constructor boundary.
  No access widening/unsafe initializer was introduced. Physical Cancel zero/
  Add exactly one note/card, editability and callback observation remain required.
- No phone install performed. Backup and matching existing SideStore identity/
  entitlement gates still apply; never uninstall or guess the installed source.
  See `Documentation/VOCABULARY_EXPORT.md`.

## M11 receiver artifact verified (2026-10-22 — current)

- Replacement run https://github.com/BCGROUPEDU/amgi/actions/runs/39691708291 completed **SUCCESS**, verified source **5ebd3f6f3f962d2679ee49ddcae307431b28778b**. Simulator build-for-testing and unsigned iphoneos Release archive passed. Later documentation commits do not change that artifact's source.
- Actual simulator execution: **96/96 Swift Testing tests passed**, AppCoreTests 32 tests / 4 suites and BrowseFeatureTests 64 tests / 10 suites, including Amgi deep links and Add Note save state. Tested on iPhone 17 Pro Max / iOS 26.5. The XCTest wrapper's zero count is not the Swift Testing count. Evidence: run artifact M11-handoff-simulator-tests; local log `/private/tmp/amgi-m11-evidence.y4VDdA/amgi/amgi/m11-handoff-tests.log`. This executes the complete two relevant suites, not every package suite in the repository.
- Downloaded and statically checked the IPA and build summary. IPA **30,759,569 bytes**, SHA-256 **64467e49ee2aa25141eb511009061fec517ff359f2b958e5061283db18a66eef**, matching the exact-source summary. Safe relative ZIP paths; app `com.amgiapp.AmgiApp`, 0.2.0 (7), iOS 18.0 minimum, `amgi` URL scheme; widget `com.amgiapp.AmgiApp.widget`. No signature, embedded profile or entitlement file: this is intentionally unsigned, not an iPhone-install receipt.
- Stable local delivery copy: `/Users/jonny/Documents/Apps/native-ios/FuriLens/build/M11-Amgi-5ebd3f6/AmgiApp-unsigned.ipa`, alongside summary/test log, ignored by Git. No executable was run or installed. Source bundle ID must not be hand-edited to the installed SideStore-suffixed ID. Compare the original signing/account/application identifier and relevant entitlements before an upgrade.
- User confirms the external backup is saved. Device tools and Xcode still show Jonnys iPhone disconnected/unavailable; requested USB connection/unlock. Existing installed Amgi remains last-confirmed 0.2.0 (7), source unknown. No reinstall, signing/account/certificate change, collection mutation or deck deletion. Next: verify matching existing SideStore upgrade identity, install over the existing app without uninstalling, then exercise edit/Cancel/one-note/rapid-tap behavior in an isolated Basic test deck. Physical acceptance remains **PENDING**.

## M11 direct practice import repair (2026-10-22, latest)

- User explicitly confirms the backup is saved and authorizes the remaining fix. This satisfies the human backup confirmation gate; artifact, matching signing/app identity and installation evidence are still required. Do not uninstall, erase data, switch Apple Accounts or revoke certificates.
- Run https://github.com/BCGROUPEDU/amgi/actions/runs/39539940321 on `3adc09fc1f9b4a19f2e688a382e99ad875204b6b` failed at DeckDetailPresentations.swift:34: `.practice` requires an explicit import of its defining ReviewCore module. No simulator tests, Release archive or IPA were produced. Earlier isolated pass results are not a cloud success.
- Bounded review enumerated every ReviewView/ReviewMode call site: the explicit `.practice` argument is the only missing defining-module import; default-mode calls need no change. Added plain `import ReviewCore` at that internal use and declared DecksFeature's direct dependency on the existing ReviewCore sink. Lead decision: this only makes an already-transitive, already-used API dependency explicit, follows the feature-to-sink rule, adds no external package/version and does not expand the C++ chain. No review, scheduling, reading, handoff-schema or storage behavior changes. Cheap read-only worker independently reviewed the boundary.
- Verification: a three-module Swift fixture with InternalImportsByDefault and MemberImportVisibility reproduces the exact old missing-import error and passes with the direct import. Exact isolated parser tests reran **3/3 PASS**; the unchanged-source synthetic sender/receiver harness reran **218 PASS**; `git diff --check` passed. Full SDK-26 simulator tests/archive require the next exact-source cloud run, whose provenance/result must be recorded before delivery.
- Repair commit **5ebd3f6f3f962d2679ee49ddcae307431b28778b** is pushed on the existing M11 branch. Exactly one replacement run was dispatched: https://github.com/BCGROUPEDU/amgi/actions/runs/39691708291 . Its head SHA was independently verified against that commit; native framework compilation is in progress. No simulator-suite, archive, IPA or installation success is claimed. Apple device tools currently report the paired iPhone unavailable; connect/unlock it before delivery. No signing, account, collection, stash or application-data changes occurred.

## M11 import-visibility repair (2026-10-21, latest)

- Replacement run https://github.com/BCGROUPEDU/amgi/actions/runs/39538043504 verified source `5c09750421d51ae1c0749b8c16542fdc07a85b71`. Rust/protobuf/project generation passed and the test-macro errors cleared. Simulator compilation then failed at ReviewFeature/ReviewView.swift:58: its package initializer uses public ReviewCore.ReviewMode through an internal import. Tests, archive and IPA steps were skipped; no IPA exists from this run.
- Minimal repair: `package import ReviewCore` in ReviewView.swift. Existing API visibility and behavior remain unchanged; no review/session/scheduler/data changes. A bounded worker reviewed this exact boundary and its existing caller. An isolated Swift compiler fixture with InternalImportsByDefault reproduced the original error and typechecked successfully with the fixed import. Exact isolated parser tests reran **3/3 PASS**; the earlier current-source compatibility harness remains **218 PASS**. Full app verification awaits one replacement run.
- Apple device tools confirmed the refreshed existing Amgi 0.2.0 (7) launches. Source commit remains unknown; no new receiver upgrade is claimed. Backup confirmation is still outstanding and Mirroring is locked; do not repeatedly ask for login or install without the backup/identity gates. A read-only SideStore program-cache listing failed to respond and was stopped; no files/data were copied, no alternate access method attempted, and installed entitlements remain unverified.

## M11 test-compilation repair (2026-10-21, latest)

- User authorized fixing the verified test compilation blocker and completing the existing delivery/acceptance flow. Both cloud diagnostics refer to the same missing inner `try` in `#require(makeURL(...))`; made every throwing helper invocation explicit with `try` at all three occurrences in AmgiDeepLinkTests. Assertions and production parser/receiver/schema are unchanged. Bounded read-only worker reviewed the helper/macro hazard.
- Actual local execution: the unchanged parser and exact repaired Swift Testing test file were linked into a disposable engine-free SwiftPM harness at `/private/tmp/amgi-m11-parser-tests.XhR8AE`; **3/3 tests passed** on Swift 6.1.2 in Swift 6 language mode. Recompiled the existing synthetic sender/receiver compatibility harness against current source: **218 checks passed**, including 191 sender-accepted corpus payloads and nine correctly sender-size-rejected payloads. `git diff --check` passed. These are not full Swift 6.2 package or iPhone acceptance claims.
- The existing generated app test plan includes AppCoreTests and BrowseFeatureTests. Added one M11-branch-only simulator execution step for both complete suites, reusing build-for-testing outputs and retaining test evidence. No SDK, dependency, signing, app ID, test assertion or shipping behavior changes; tag/other-branch behavior unchanged. Replacement cloud run and final results pending.
- User reports the restart/refresh completed and apps were updated. Apple inventory still reports FuriLens 1.0 (3), Amgi 0.2.0 (7), SideStore 0.7.0. Source identity of installed Amgi remains unknown; this is not the new receiver installation. A current externally saved Amgi backup has been requested and is not yet confirmed. Do not install until artifact/identity/backup gates are satisfied.

## M11 device tunnel diagnostics (2026-10-21, latest)

- SideStore launches, but the user confirms its refresh still fails with the unreachable tunnel-peer/device-endpoint error. Its 7-day label came from iloader signing and is not refresh proof. Amgi remains expired; no Amgi upgrade or collection acceptance has occurred.
- Directly observed: iOS SideStore Local Network permission enabled; LocalDevVPN 1.3.0 connected with the user-applied tunnel `10.7.0.2/30` and device `10.7.0.1/32`. SideStore Connection Config shows Use Local VPN on, automatic tunnel/device IP and reachability N/A, default RemotePair port 49152. Tested only a manual device-IP override matching the VPN; it reported Active: No. Removed and saved that override afterward, restoring blank override fields and automatic mode. No port guessing, app removal, pairing reset, certificate revocation or Amgi data changes.
- iPhone Mirroring permits clicks and typing, but scrolling repeatedly closed/relocked it. Xcode screenshots are black while Mirroring is active; Mirroring itself subsequently showed the diagnostics. Do not repeat authentication/scroll loops. Next bounded user step: restart the iPhone, unlock after boot, reconnect Wi-Fi/LocalDevVPN and inspect Connection Config again. Restart is proposed, not yet verified.
- Cloud run `39532542321` on exact repair `ab2ecffacb5870c52f709b5555137ccc5b5ec361` has now **failed**, superseding earlier in-progress notes. The EPUBKit deployment mismatch is cleared; simulator build-for-testing reached two throwing-call errors in Swift Testing `#require` expansions from AppCoreTests/AmgiDeepLinkTests.swift. No IPA was produced and package tests were not executed. No replacement dispatch since that failure. Fix the evidenced test-compilation defect before one further build; do not bypass tests or lower toolchain requirements.

## M11 cloud compatibility repair / SideStore recovery (2026-10-21)

- Run `39247901107` failed at the simulator compatibility build: resolved AEXML 4.7.3 requires iOS 17, while vendored EPUBKit declared iOS 16. No IPA was produced. Raised only EPUBKit's iOS minimum to 17; the containing app remains iOS 18. No dependency version, app identity, signing, receiver, collection or deck changes.
- The user authorized this repair and restoring SideStore. Reuse the original Apple Account/signing path; never uninstall Amgi. SideStore restoration and launch are now confirmed below; on-device refresh remains pending. Apple Account, 2FA, device trust and any certificate replacement/revocation prompts are explicit user gates. Before an Amgi upgrade, confirm a backup outside its app container and verify the upgrade identity.
- Validation: `git diff --check` passed; Swift `dump-package` loaded the repaired manifest and reports iOS 17 with unchanged dependency requirements and other platform minima. This is metadata validation, not a full app build or executed package suite. Replacement cloud-run provenance will be recorded below.
- Repair pushed as `ab2ecffacb5870c52f709b5555137ccc5b5ec361`. Exactly one replacement workflow was accepted: https://github.com/BCGROUPEDU/amgi/actions/runs/39532542321 . Verified its head SHA matches the repair; currently in progress (Xcode 26.3 selected, checkout underway). No artifact or installation success yet. Do not redispatch while active.
- Live Apple inventory still registers SideStore `com.SideStore.SideStore.26QAK2CBK9` version `0.7.0-20260911.328+6032424a`; launch is denied for invalid signature/entitlements or untrusted profile. Thus deletion is not established; no uninstall was attempted. Amgi remains registered as `com.amgiapp.AmgiApp.26QAK2CBK9`, 0.2.0 (7); FuriLens remains 1.0 (3). iloader 2.3.10 is open, detects Jonnys iPhone and awaits the user's original Apple Account login/2FA. Resume with that gate, then verify supported SideStore re-sign/install without changing Amgi identity or data.
- Recovery result: after the user-approved switch from the failing SideStore anisette endpoint to built-in Jkcoxson (Mac), the user completed Apple Account login. iloader reported **SideStore Installed!** with download, signing/install and pairing placement complete. Apple `devicectl` inventory confirms the same SideStore bundle identifier/version and Amgi 0.2.0 (7); `device process launch` now succeeds for SideStore (previously signature-denied). No app was uninstalled and no certificate-revocation prompt was accepted. User must still complete the on-phone VPN/sign-in/My Apps refresh step; refresh and Amgi cross-app acceptance are not verified. The replacement Amgi run is currently at simulator compatibility compilation, not yet a successful IPA.

## M11 receiver/build investigation (2026-10-19)

- Cloud recovery: authenticated GitHub Actions page showed a fork-scale pause with the maintainer re-enable control, despite enabled API settings. After verifying default main has only the existing manual/version-tag IPA workflow (no schedules), re-enabled through GitHub's own control; UI confirmed **Actions Enabled**. One manual M11 run was accepted: **39247901107**, source **b696236aa4b6df5ac7bfa713472bf258526bdefc**, branch `codex/m1100-vocabulary-acceptance`, URL https://github.com/BCGROUPEDU/amgi/actions/runs/39247901107 . Source differs from receiver 628fcb5 only in documentation. Build is in progress, not yet an artifact/build/test/install success. No tag/release, key upload, permission-scope change, OS upgrade, or duplicate dispatch occurred. User confirms existing iPhone Amgi was installed through **SideStore**; preserve that same signing/account path and installed identity, never uninstall to update.
- Resume check: still only macOS 15.5 / Xcode 16.4 / Swift 6.1.2. One valid Apple Development identity exists; the sole local provisioning profile is for FuriLens (`26QAK2CBK9.BCdesign.FuriLens`), not Amgi. No Amgi upgrade identity/profile has been established. Installed Amgi metadata still reports 0.2.0 build 7 under `com.amgiapp.AmgiApp.26QAK2CBK9`. Stop at the supported local requirement: sufficient disk space (2.8 GiB currently), macOS Sequoia 15.6+ and Xcode 26.3 (Swift 6.2.3/iOS 26.2 SDK), followed by the documented native framework build and original matching upgrade-signing path. No OS/Xcode/identity changes, repeated Actions dispatch, uninstall or data mutation were attempted.
- Branch `codex/m1100-vocabulary-acceptance` starts at exact receiver `628fcb532c20605dcc5539368fc3894b12c3be62`. No application, signing, dependency, schema, collection, or deck change was made. Installed Amgi remains 0.2.0 (7), source commit unknown; do not treat it as the verified receiver.
- Local Xcode 16.4 / Swift 6.1.2 cannot load the four tools-6.2 manifests. This is not just a header issue: package feature flags, import/concurrency rules, C++ interop, iOS 26 glassEffect, and app/SDK settings need the newer environment. The required root AnkiRustLib.xcframework and native build tools are also absent. Downgrading the receiver in isolation would not make the app build.
- Existing parser/routing and editable Add Note/save guards were reviewed; no new receiver defect was established. Full application tests and device save/cancel/exactly-one-note remain unverified. Follow `Documentation/M11_COMPATIBLE_BUILD.md` for the supported route, including installed bundle-ID/signing preservation gates.
- The FuriLens sender and this exact pure receiver still pass 218 isolated compatibility checks in Swift 6 mode on this host; that does not prove Swift 6.2 package or device acceptance. The existing cloud workflow builds, but does not execute the relevant package test suites. No new dispatch was attempted after M10's HTTP 422 Actions-disabled refusals.

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
