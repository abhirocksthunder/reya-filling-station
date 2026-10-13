# Owner-authorized Reya deployment without a physical test device

The owner explicitly requested deployment without real-device testing on 12 Oct
2026. This supersedes the earlier device prerequisite for this rollout. It does
not assert Android tests were performed. Automated Flutter/release checks, signed
staging build, app/base identity, key fingerprint, artifact metadata, free-account
and native/asset compatibility gates remain required.

Promotion supports protected local `authorized-no-device-<base>-<patch>.json`
evidence, bound to the exact staged-record SHA256. It records the user's actual
authorization, IST timestamp, automated checks and `device_testing: skipped`.
The normal physical QA evidence path also remains available. API clients cannot
send a `verified: true` flag or arbitrary evidence path to bypass release auth.
Promotion queries Shorebird before moving the same immutable patch to stable and
retains the evidence in the promoted artifact record. No APK version bump or APK
announcement is part of patch delivery.

For current release: signed Patch 1 targets v1.0.33+34 and includes current-data
insights, complete handover purge, separate Roles/Permissions and width-responsive
side/footer navigation. 125 Flutter tests, 22 release checks and the web build pass.
Android cold-launch/download/offline/rollback behavior is not physically verified.
The owner authorized deploying with that limitation. Existing migration APK
download bytes and APK update policy must remain unchanged during web publication.

Recovery: use Shorebird patches rollback for this base/patch if necessary; devices
discover rollback through update checks and apply resulting code on a subsequent
launch. Firebase Hosting retains deployment rollback independently of patch state.

## Confirmed deployment

Deployed signed Shorebird Patch 1 to stable for v1.0.33+34 and published matching website revision 20261012153722-f54e05abc5e17720. User explicitly authorized skipping physical-device testing; no device QA is claimed. 125 Flutter tests, 22 release checks, signed staging/native/asset checks, anonymous live-browser startup, live code/revision hashes and public migration APK hash verification passed. Original migration APK SHA256 86925739cb09250b55076cf66f36fd00fd8d40b3ac9e7aecf0b23237c99399fe and existing forceUpdate=true policy preserved. Web builds now guard against publishing a stale or patch-build APK download.
