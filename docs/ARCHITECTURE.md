# M0 Specification

## Product

FileTransfer combines account-based online transfer, friend-to-friend transfer, direct friend chat, local file management, and transfer history in one branded experience.

## Platforms

- Windows desktop client
- iOS native client
- HTTPS backend and WebSocket endpoint on one public origin
- Offline and online Windows installers

## Non-negotiable constraints

- One user-entered Server URL; all API and WebSocket endpoints are derived centrally.
- No application-level small file-size limit. Uploads and downloads stream in chunks and never load a whole file into RAM.
- Large files are stored outside the database in a protected data directory or object storage.
- Authorization is checked for every account, friend, message, and transfer operation.
- HTTPS is required for production. Tokens are stored in Windows Credential Manager/DPAPI or iOS Keychain.
- iOS USB behavior uses only public Apple-supported mechanisms. Arbitrary automatic USB app-to-app transfer is not claimed.
- Installer downloads and updates are never executed without SHA-256 verification.

## Languages

The client catalog supports English, Vietnamese, Simplified Chinese, Traditional Chinese, and Japanese.

## Acceptance evidence

Build and test commands are recorded in `docs/TESTING.md`. Physical iPhone, Windows installer, and Apple signing results are marked according to the actual environment rather than inferred.
