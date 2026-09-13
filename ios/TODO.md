# iOS build and packaging

## Verified

- `ios/Package.swift` defines the `FileTransferCore` library and `FileTransferCoreTests` test target.
- `ios/FileTransfer.xcodeproj` contains the `FileTransfer` SwiftUI application target, the `FileTransferTests` unit-test target, and the shared `FileTransfer` scheme.
- `ios/ExportOptions.plist` is present with App Store/automatic-signing export settings; its presence is not signing evidence.
- Swift package build is `PASS` on Linux with Swift 6.3.3.
- Swift package tests are `PASS`: 12 tests, 0 failures. These are host-level package tests, not Xcode/iOS runtime tests.
- `.github/workflows/ios-build.yml` defines Xcode project validation, simulator build/test, optional signing import, archive/export, and artifact-upload steps. No workflow run result is available in this workspace.

## Required target and compatibility boundary

- Required deployment target: iOS 18.0.
- Target device: iPhone XS.
- Runtime compatibility matrix: iOS 18.7.9 and iOS 18.7.10.
- Current checked-in package and Xcode settings declare iOS 16.0. This is `FAIL` against the required iOS 18.0 target and must be aligned before Xcode verification.
- The checked-in workflow currently selects iPhone 16, so it is not evidence for the required iPhone XS target.

## Remaining verification

- Align the Swift package and Xcode deployment target to iOS 18.0.
- Run Xcode project/scheme validation on macOS/Xcode.
- Run simulator build and unit tests on an iPhone XS destination; record Xcode output. The current workflow's iPhone 16 destination does not satisfy this gate.
- Run an Xcode archive and record its command, exit status, and archive path without claiming an IPA unless export succeeds.
- Provide Apple signing identity/profile inputs and verify signing.
- Export and validate an IPA only after a valid archive and signing inputs exist.
- Test Files import/export and online transfers on a physical iPhone XS.
- Record runtime compatibility results for iOS 18.7.9 and iOS 18.7.10.
- Record the resulting Xcode, signing, archive, IPA, simulator, and device-test status in `docs/IOS.md`, `docs/TESTING.md`, `docs/PROGRESS.md`, `docs/RELEASE.md`, and `todo.md`.

## Current status summary

| Area | Status |
|---|---|
| Swift package build | `PASS` |
| Swift package tests | `PASS` |
| Xcode project structure | `PASS` |
| Deployment target iOS 18.0 alignment | `FAIL` (currently iOS 16.0) |
| Simulator build/test on iPhone XS | `BLOCKED` |
| Archive | `BLOCKED` |
| IPA | `BLOCKED` |
| Signing | `BLOCKED` |
| Physical iPhone XS | `NOT TESTED` |
| iOS 18.7.9 runtime | `NOT TESTED` |
| iOS 18.7.10 runtime | `NOT TESTED` |
