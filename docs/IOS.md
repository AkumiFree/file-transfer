# iOS

The iOS target is a native SwiftUI application with tabs for Home, Files, Transfers, Chat, Friends, and Settings.

## Architecture

- `FileTransferApp` configures navigation, theme, localization, and services.
- `APIClient` uses the shared endpoint contract and bearer authentication.
- `KeychainStore` stores tokens through Apple's Keychain.
- `TransferService` creates upload sessions, streams chunks, tracks progress, and supports resume.
- `ChatService` loads REST history and connects to `/ws` for realtime events.
- `FilesView` uses `fileImporter`/`fileExporter` and standard document-picker APIs.

## Files behavior

`Save to Files` exports a copy through the system picker. `Save to Folder & Delete` exports first, waits for confirmed completion, and only then deletes the original. Any failure leaves the original intact.

## Build status

The current Linux environment has no Swift, Xcode, or Apple signing tools. The iOS source is present, but an IPA build is `BLOCKED - APPLE BUILD/SIGNING ENVIRONMENT REQUIRED`.
