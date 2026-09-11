# Windows installer

## Offline

`installer/offline/` contains a branded NSIS project. It supports installation location, Start Menu and Desktop shortcuts, launch-after-install, and a fully self-contained package. Test with network access disabled.

## Online

`installer/online/` contains a small bootstrapper project. It connects to the configured release API, downloads the package over HTTPS, verifies SHA-256 before installation, creates shortcuts, and optionally launches.

## Verification checklist

- Custom logo and application name are visible.
- Version and progress are displayed.
- Offline installer succeeds with Internet disabled.
- Online installer rejects checksum mismatches.
- Shortcut options are honored.
- Launch-after-install works.
- No unverified executable is launched.

Windows executable verification is blocked in the current Linux environment unless a Windows/NSIS or Wine runner is provided.
