# M11 compatible receiver build and delivery

Receiver code baseline: `628fcb532c20605dcc5539368fc3894b12c3be62`.
M11 branch: `codex/m1100-vocabulary-acceptance`. Documentation and build-platform
changes do not establish a new installed receiver. Last confirmed phone version is 0.2.0 (7),
with unknown source identity.

## Why a Swift 6.1 header downgrade is not a solution

All four package manifests require tools 6.2 and opt into import/concurrency
features. Root `Package.swift` expects `AnkiRustLib.xcframework`, which is absent
locally. AmgiUI uses SDK-26 `glassEffect`; ReaderFeature propagates C++ interop;
`AmgiApp/project.yml` includes Xcode-26 settings. This host only has Xcode 16.4
and Swift 6.1.2. The pure URL parser compiles in isolation, but that is not an
application compatibility result. No requirements were lowered.

## Supported build path

### Fork restriction recovered (2026-10-19)

The authenticated Actions page exposed a fork-scale pause and its maintainer
re-enable button. After verifying the only default-branch workflow is the
existing manual/version-tag IPA build (no schedules), the user-authorized
re-enable action succeeded with **Actions Enabled**. The generic permissions
API alone did not show this separate pause.

The original manual run built source `b696236aa4b6df5ac7bfa713472bf258526bdefc`
on `codex/m1100-vocabulary-acceptance` (only documentation differs from receiver
`628fcb5`): https://github.com/BCGROUPEDU/amgi/actions/runs/39247901107 .
It failed at the simulator compatibility build: AEXML 4.7.3 requires iOS 17,
but vendored EPUBKit declared iOS 16. No IPA was produced. On 2026-10-21 the
user authorized the bounded fix: raise only EPUBKit's iOS minimum to 17 (the
app remains iOS 18), then dispatch one replacement run on the repaired SHA.
No dependency version, application ID, signing or receiver behavior is changed.
Record replacement-run provenance in HANDOFF.md.

Replacement run: https://github.com/BCGROUPEDU/amgi/actions/runs/39532542321 ,
verified source `ab2ecffacb5870c52f709b5555137ccc5b5ec361`. It is in progress;
no artifact or installation has been verified. Apple inventory still registers
SideStore, but launching it is denied for signature/profile-trust reasons;
do not assume uninstall is necessary. Subsequently, the user completed login
using the approved built-in Jkcoxson (Mac) anisette server. iloader confirmed
stable SideStore installation and pairing placement; Apple device tools now
successfully launch its unchanged bundle identifier. On-device VPN/sign-in
and SideStore refresh remain unverified. Amgi itself has not been upgraded.

Do not dispatch another run just because compilation takes time. A queued or
running job is not a successful build, tested package, artifact or installation.
User confirmed **SideStore** installed the current Amgi, and subsequently
reported SideStore was uninstalled. Restore it using the official iloader
route and original Apple Account; do not remove Amgi. Account/2FA, device
trust and certificate replacement/revocation require the user's involvement.
Confirm a current Amgi backup saved outside its app container before upgrading.
After successful
artifact verification, reuse its existing signing/account and app identity;
never uninstall or invent a replacement bundle identifier. No signing keys or
collection data are uploaded to the public build.

Use the existing `.github/workflows/build-ipa.yml` environment: macos-26,
Xcode 26.3, recursive checkout, Rust 1.95 with Apple targets plus nightly
rust-src, protobuf/swift-protobuf and xcodegen. It builds the real Rust
XCFramework, generates protobufs/project, builds the simulator app and creates
an unsigned Release IPA. Do not substitute a second card database.

Historically, M10 dispatch was refused twice with HTTP 422 "Actions has been disabled for
this repository", even though the permissions API reported enabled and the
workflow active. M11 did not retry with unchanged configuration. After the
verified maintainer re-enable action above, this command started the recorded
run (do not run it again while that run is active):

```sh
gh workflow run build-ipa.yml --ref codex/m1100-vocabulary-acceptance
gh run list --workflow build-ipa.yml --branch codex/m1100-vocabulary-acceptance --limit 1
```

Inspect that run's head SHA and logs, not an unrelated successful branch. This
repository is a public fork; never upload signing keys, collections, decks,
private device captures or vocabulary in artifacts. An unsigned IPA is **not**
a signed iPhone installer, nor proof that package tests passed.

Alternatively use a Mac with a supported Xcode 26+ SDK/toolchain and enough
disk space. In a fresh checkout of this branch, initialize its exact recorded
submodules and follow `Documentation/BUILDING.md` and `agents/build-and-verify.md`:
build the native XCFramework, generate protobufs, generate the Xcode project,
then use XcodeBuildMCP build/test tools against an available iOS simulator.
The authoritative `anki-upstream` revision is the Git gitlink (currently
`e64c6b1...`), not the outdated "26.05" prose in BUILDING.md. Do not update it.

Run AppCore's `AmgiDeepLinkTests` and BrowseFeature's `AddNoteSaveTests` as well
as relevant complete package suites. The existing cloud smoke job does not run
them; a build-for-testing step alone is not executed tests. Follow the repo's
MCP build/test verification rules and record actual results.

## Installation and acceptance gates

Before signing/installing, compare the produced bundle identifier, application
identifier, team and keychain/app-group entitlements with the existing installed
Amgi package. The phone currently reports
`com.amgiapp.AmgiApp.26QAK2CBK9`, while source project.yml says
`com.amgiapp.AmgiApp`. Do not change either identifier, re-sign to a guessed
identity, uninstall the app, or erase its container to make installation pass.
Use the existing supported signing setup; resolve any mismatch explicitly
before claiming a data-preserving upgrade is possible.

Record the actual built Git SHA and build metadata in the delivery log. On a
supported signed build, install as an upgrade only. Use an isolated Basic test
deck: open the schema-v1 import, inspect/edit fields, Cancel and verify zero
notes, reopen and Add once, verify one note, then test rapid taps and invalid
payload rejection. Receipt never authorizes a database write. Do not mark any
of these physical checks passed based on parser tests or successful launch.
