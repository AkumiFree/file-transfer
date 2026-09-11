# iOS USB limitations

iOS does not present an app sandbox as a normal USB mass-storage volume. Public APIs do not permit arbitrary automatic app-to-app file transfer over USB without user-mediated system workflows.

## Supported approach

- Use the iOS app's Documents storage and Files integration.
- Let the user export through the standard Files/document picker.
- Support `UIFileSharingEnabled`/iTunes File Sharing only where appropriate and documented by Apple.
- Use Photos/Image Capture only for media workflows explicitly supported by the platform.
- Use online transfer through the backend for normal cross-platform transfers.

## Not supported

- Private USB protocols
- Jailbreak-dependent behavior
- Silent arbitrary filesystem access
- Pretending that iOS behaves like a USB flash drive

Real-device testing is required before marking USB transfer complete. Current environment result: `REAL DEVICE TEST: NOT TESTED`.
