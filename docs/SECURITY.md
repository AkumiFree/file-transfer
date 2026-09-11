# Security

## Transport and identity

- Production uses HTTPS only.
- Access tokens are short-lived; refresh sessions are opaque, rotated, revocable, and stored as hashes.
- Windows clients use Credential Manager/DPAPI; iOS clients use Keychain.
- Passwords use bcrypt with a strong work factor.

## Authorization

Every friend request, conversation, message, file, transfer, and download operation checks the authenticated user against the resource owner or recipient. IDs are never trusted as authorization.

## File safety

- Client filenames are metadata only and are sanitized for display.
- Server storage keys are generated UUID paths and never contain user input.
- Paths are resolved and checked against the configured storage root; symlinks and traversal are rejected.
- File contents are outside the database and outside the web root.
- Downloads use `Content-Disposition: attachment`, `X-Content-Type-Options: nosniff`, and private no-store caching.

## Input and abuse controls

- JSON bodies, query parameters, IDs, filenames, MIME types, sizes, chunk indices, and message lengths are validated.
- Login, registration, password change, friend requests, messages, uploads, and WebSocket frames are rate-limited.
- Duplicate idempotency keys prevent retry duplication.
- Errors shown to users do not include stack traces or filesystem paths.

## Updates and installers

Online installers and auto-updates download over HTTPS, verify SHA-256 before execution/installation, and fail closed on mismatch. Release metadata must be served by the configured trusted origin.
