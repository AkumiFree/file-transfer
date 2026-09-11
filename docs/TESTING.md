# Testing

## Automated tests

```bash
npm run test:shared
npm run test:server
```

Shared tests cover endpoint derivation, unsafe URL rejection, chunk math, filename sanitation, and localization. Server tests cover API contracts, authorization, chunk resume/hash behavior, friend/chat flows, and safe errors.

## Manual matrix

| Test | Status |
|---|---|
| Windows → Server → iPhone | NOT TESTED: physical iPhone unavailable |
| iPhone → Server → Windows | NOT TESTED: physical iPhone unavailable |
| Windows → Friend | NOT TESTED: Windows runner unavailable |
| iPhone → Friend | NOT TESTED: physical iPhone unavailable |
| Friend → Chat | NOT TESTED: cross-device runner unavailable |
| Chat → File transfer | NOT TESTED: cross-device runner unavailable |
| Large file transfer | NOT TESTED: platform runner unavailable |
| Interrupted transfer / resume | NOT TESTED: platform runner unavailable |
| Checksum verification | NOT TESTED: platform runner unavailable |
| Save to Files | NOT TESTED: physical iPhone unavailable |
| Save to Folder & Delete | NOT TESTED: physical iPhone unavailable |
| Offline installer, Internet disabled | NOT TESTED: Windows/NSIS unavailable |
| Online installer, Internet enabled | NOT TESTED: Windows/NSIS unavailable |
| Shortcut creation / automatic launch | NOT TESTED: Windows unavailable |
| Update check | NOT TESTED: Windows runner unavailable |
| Server health check | NOT TESTED until server build completes |
| Login/logout/friend/message | NOT TESTED until server build completes |

## Release evidence policy

No item is marked complete unless its implementation and verification evidence exist. Physical-device and signing results are recorded as `NOT TESTED` or `BLOCKED`, never inferred.
