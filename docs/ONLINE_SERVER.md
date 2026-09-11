# Online server

The backend is a modular monolith on one HTTPS origin.

## Deployment

- Run one Node process behind an HTTPS reverse proxy.
- Route `/api/v1/*` and `/ws` to the same process/port.
- Store metadata in SQLite with WAL and foreign keys enabled.
- Store large file bytes in `DATA_DIR`, outside the web root.
- Configure trusted proxy headers only when a trusted reverse proxy sets them.
- Set a high-entropy session secret and rotate it securely.
- Back up the SQLite database and storage volume together.

## Health and releases

`GET /api/v1/health` reports service state without exposing internals. `GET /api/v1/releases/windows/latest` returns version, package URL, size, and SHA-256 for the Windows update/installer flow.

## Scaling

SQLite is appropriate for a single-node deployment. For multiple writers or replicas, move session/rate-limit/outbox coordination to a shared store while retaining the same API contract.
