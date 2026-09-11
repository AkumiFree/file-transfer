# Installation

## Server

1. Install Node.js 24+.
2. Run `npm install`.
3. Set `PORT`, `DATA_DIR`, `DB_PATH`, and a high-entropy session secret.
4. Run `npm run build:server`.
5. Run `node server/dist/src/index.js`.
6. Put an HTTPS reverse proxy in front of the service and route `/api/v1` and `/ws` to the same origin.

## Windows desktop

Run the Windows workspace build in the supported build environment, then distribute the generated application directory or signed installer. The app asks for one Server URL and derives all endpoints.

## iOS

Open `ios/FileTransfer.xcodeproj` on macOS, select a development team, archive, and sign with Apple's standard signing workflow. The source includes Files picker integration and Keychain token storage.

## Offline installer

`FileTransfer-Offline-Setup.exe` contains the application package and does not download components during installation.

## Online installer

`FileTransfer-Online-Setup.exe` reads the configured release API, downloads the package over HTTPS, verifies SHA-256, installs, creates shortcuts, and optionally launches.
