# FileTransfer delivery plan

## M0 Specification
- [x] Product scope, platform constraints, security requirements, and acceptance criteria captured in docs.

## M1 Repository
- [ ] Monorepo structure, package scripts, editor configuration, and baseline build.

## M2 Shared protocol
- [ ] Endpoint resolver, protocol types, localization catalog, and shared tests.

## M3 Backend foundation
- [ ] HTTP server, SQLite persistence, configuration, health endpoint, and streaming storage primitives.

## M4 Authentication
- [ ] Registration, login, refresh, logout, session persistence contract, and authorization middleware.

## M5 Friend system
- [ ] Search, requests, accept/reject, remove, block, and presence.

## M6 Chat
- [ ] REST history, real-time WebSocket messaging, read state, pagination, and retry metadata.

## M7 File transfer backend
- [ ] Resumable chunk upload/download, checksum, authorization, cleanup, and transfer metadata.

## M8 Windows application
- [ ] Electron shell, navigation, theme, server settings, account, friends, chat, files, and transfers.

## M9 iOS application
- [ ] SwiftUI navigation, account, friends, chat, files, transfers, and settings source.

## M10 Online Windows transfer
- [ ] Server-mediated transfer flow from Windows client.

## M11 Online iOS transfer
- [ ] Server-mediated transfer flow from iOS client.

## M12 Friend-to-friend transfer
- [ ] Friend authorization and transfer notifications.

## M13 iOS Files integration
- [ ] Save to Files and Save to Folder & Delete with success-gated deletion.

## M14 Offline USB investigation
- [ ] Apple-supported mechanism research and limitation documentation.

## M15 Offline USB/file-sharing implementation
- [ ] Supported iOS Files/document-sharing workflow and Windows guidance.

## M16 Windows Offline Installer
- [ ] Branded self-contained installer source and build path.

## M17 Windows Online Installer
- [ ] Verified HTTPS bootstrapper source and build path.

## M18 Auto-update
- [ ] Release endpoint, checksum verification, and update prompt.

## M19 Security hardening
- [ ] Rate limits, validation, path safety, authorization, secure storage guidance, and audit checks.

## M20 Automated tests
- [ ] Unit and integration coverage for protocol, auth, friends, chat, and transfers.

## M21 UI/UX polish
- [ ] Branding, responsive layouts, empty/error/loading states, accessibility, and localization.

## M22 Packaging
- [ ] Windows app package, iOS archive target, server package, and artifact manifests.

## M23 Final integration testing
- [ ] Cross-platform, large-file, interruption/resume, installer, update, and real-device test matrix.

## M24 Documentation
- [ ] Architecture, API, protocol, security, build, installation, iOS, limitations, installer, server, and testing docs.

## M25 Final release
- [ ] Release checklist, known limitations, artifact sizes, and reproducible build instructions.

## Verification policy

Each milestone must be built and tested before the next begins. Physical-device and platform-tool results are recorded as `NOT TESTED` or `BLOCKED` when the required environment is unavailable.
