# FileTransfer

FileTransfer is a cross-platform friend chat and file-transfer product with a shared TypeScript protocol, a streaming backend, a Windows Electron client, and a native SwiftUI iOS project.

## Current status

- Backend, shared protocol, and Windows client source are implemented in the repository.
- The iOS project is source-ready but cannot be built or signed in this Linux environment because Xcode/Swift and Apple signing tools are unavailable.
- Windows installer executables require a Windows/NSIS or Wine build environment; installer sources and build scripts are provided.
- USB transfer between Windows and iOS is intentionally limited to Apple-supported Files/document-sharing workflows. No private APIs or jailbreak behavior are used.

See `docs/` for architecture, API, security, build, installation, and platform limitations.

## Quick start

```bash
npm install
npm run build:shared
npm run build:server
npm run dev --workspace server
```

The default server listens on `http://localhost:3000`. In production, terminate TLS at a reverse proxy and expose one HTTPS origin.
