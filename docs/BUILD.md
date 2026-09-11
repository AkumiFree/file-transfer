# Build

## Prerequisites

- Node.js 24+
- npm 11+
- Windows: Electron/NSIS or a Windows build runner for installer executables
- iOS: macOS, Xcode, Apple developer identity, and a signing provisioning profile

## Commands

```bash
npm install
npm run build:shared
npm run test:shared
npm run build:server
npm run test:server
npm run build:windows
```

The server build emits JavaScript under `server/dist`. The shared package emits declarations and JavaScript under `shared/dist`.

## Environment

```bash
PORT=3000
DATA_DIR=./data
DB_PATH=./data/file-transfer.db
ACCESS_TOKEN_TTL=15m
REFRESH_TOKEN_TTL=30d
```

`JWT_SECRET` or the configured session secret must be a high-entropy production secret. Never commit `.env`.

## Platform builds

- Windows app: run the Windows workspace build in a Windows or Wine-capable runner.
- Offline installer: run the NSIS build with the packaged application directory; no Internet is required at install time.
- Online installer: build the bootstrapper, then test against a reachable HTTPS release endpoint.
- iOS: archive with Xcode and sign outside this Linux environment. The IPA is not claimed as built here.
