# API

The backend exposes one origin for REST and WebSocket traffic. Clients enter only the origin, then use the shared endpoint resolver.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/v1/health` | Health, version, database, storage, and WebSocket status |
| POST | `/api/v1/auth/register` | Create an account |
| POST | `/api/v1/auth/login` | Create a session |
| POST | `/api/v1/auth/session/refresh` | Rotate a refresh session |
| POST | `/api/v1/auth/logout` | Revoke the current session |
| GET | `/api/v1/auth/me` | Current account |
| POST | `/api/v1/auth/password/change` | Change password |
| GET | `/api/v1/users/search?q=` | Search users |
| GET | `/api/v1/friends` | Friend list and presence |
| POST | `/api/v1/friend-requests` | Send a friend request |
| GET | `/api/v1/friend-requests?direction=inbox|sent` | List requests |
| POST | `/api/v1/friend-requests/:id/accept` | Accept a request |
| DELETE | `/api/v1/friend-requests/:id` | Reject/cancel a request |
| DELETE | `/api/v1/friends/:userId` | Remove a friend |
| POST | `/api/v1/blocks/:userId` | Block a user |
| DELETE | `/api/v1/blocks/:userId` | Unblock a user |
| GET | `/api/v1/conversations` | Conversation list |
| GET | `/api/v1/conversations/:id/messages?cursor=&limit=` | Paginated history |
| POST | `/api/v1/conversations/:id/messages` | Send a message |
| POST | `/api/v1/conversations/:id/read` | Mark messages read |
| GET | `/api/v1/transfers` | Transfer history |
| POST | `/api/v1/transfers/uploads` | Create an upload session |
| GET | `/api/v1/transfers/uploads/:id` | Upload status and received chunks |
| PUT | `/api/v1/transfers/uploads/:id/chunks/:index` | Stream one chunk |
| POST | `/api/v1/transfers/uploads/:id/release` | Verify and release a file |
| DELETE | `/api/v1/transfers/uploads/:id` | Cancel and clean up |
| POST | `/api/v1/files/:id/downloads` | Create a download session |
| GET | `/api/v1/transfers/downloads/:id/chunks/:index` | Download a chunk |
| GET | `/api/v1/releases/windows/latest` | Signed release metadata |
| WebSocket | `/ws` | Chat, presence, transfer events, and acknowledgements |

## Authentication

Native clients send `Authorization: Bearer <access-token>`. Sessions are opaque, randomly generated, rotated on refresh, and stored server-side as hashes. Passwords are bcrypt hashes. Production deployments must use HTTPS and secure token storage: Windows Credential Manager/DPAPI and iOS Keychain.

## Errors

Errors use:

```json
{
  "error": {
    "code": "validation_error",
    "message": "A user-safe explanation.",
    "details": {}
  }
}
```

Internal exceptions are logged server-side and converted to stable public error responses.

## Transfer headers

Chunk upload uses `application/octet-stream`, `Content-Range`, `X-Chunk-SHA256`, and `Idempotency-Key`. Download supports `Range`, `If-Match`, `Content-Range`, and `ETag`.
