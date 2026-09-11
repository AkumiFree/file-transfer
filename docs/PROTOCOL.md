# Protocol

## Endpoint derivation

Input:

```text
https://example.com
```

Derived:

```text
API:         https://example.com/api/v1
Health:      https://example.com/api/v1/health
Auth:        https://example.com/api/v1/auth
Friends:     https://example.com/api/v1/friends
Chat:        https://example.com/api/v1/chat
Transfers:   https://example.com/api/v1/transfers
WebSocket:   wss://example.com/ws
```

A path-prefix input such as `https://example.com/base` preserves `/base` in the derived WebSocket path.

## Transfer metadata

```json
{
  "transferId": "uuid",
  "fileId": "uuid",
  "filename": "report.pdf",
  "size": 123456789,
  "sha256": "hex",
  "chunkSize": 1048576,
  "totalChunks": 118,
  "sender": "user-id",
  "receiver": "user-id",
  "status": "created",
  "createdAt": "2026-01-01T00:00:00.000Z"
}
```

## Chunk upload

1. Create an upload session with filename, byte size, MIME type, total SHA-256, chunk size, recipient, and idempotency key.
2. Send chunks independently with `PUT /uploads/{id}/chunks/{index}`.
3. Include `Content-Range: bytes start-end/total`, `X-Chunk-SHA256`, and `Idempotency-Key`.
4. Resume by reading session status and sending only missing chunks.
5. Call `POST /release`; the server verifies all chunks and recomputes the full-file SHA-256 before making the file available.

The server never loads a complete file into RAM. It streams request bodies and file data to protected storage.

## WebSocket events

Events use:

```json
{
  "eventId": "uuid",
  "type": "message.created",
  "serverTime": "2026-01-01T00:00:00.000Z",
  "data": {}
}
```

Supported event types include `friend.requested`, `friend.accepted`, `message.created`, `message.ack`, `read.updated`, `presence.changed`, `transfer.progress`, `transfer.released`, and `error`.

REST history and transfer metadata remain the source of truth when a socket reconnects.
