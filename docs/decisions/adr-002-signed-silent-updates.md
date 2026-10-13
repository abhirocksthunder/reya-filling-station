# ADR-047: Signed Shorebird updates for Reya Filling Station

Status: Accepted; integration implemented, production migration pending account/device prerequisites.

Reya distributes Android APKs through Firebase Hosting. Ordinary builds cannot
receive Dart patches. Use one optional Shorebird base release, preserving
`com.reya.reya_filling_station` and the current signing certificate. Keep Flutter
3.41.9/Dart 3.11.5, and disable icon tree shaking for Android bases and patches.

The native Shorebird updater owns silent background downloads and next cold-launch
activation. Flutter Provider exposes metadata after the first frame; it never
calls update, restarts the process, or affects financial/authentication state.
Web and ordinary Flutter builds remain supported. APK comparisons stay in
AppVersionService; patches do not change APK metadata or publish notifications.

Owner release endpoints reuse the existing build lock and bounded status pattern.
They require an authenticated owner even when legacy local auth is disabled.
The account must match the locally designated owner, be free, and have no paid
overage. Missing CLI/config/keys/auth abort before version mutation. No vanilla
Flutter fallback exists. Raw CLI output is withheld from API logs to protect
credentials. Signed base identity is checked before exposing the local artifact.

Patch jobs permit Dart source changes only against retained base provenance.
Native, dependency, asset or configuration changes require a new base. Shorebird
compatibility checks cannot be bypassed. Staging records bind app/base/patch ID,
artifact metadata, key fingerprint, SDK, build arguments and source hashes.
Promotion moves the same patch using `patches set-track --track=stable` (the current
replacement for deprecated `patches promote`). A local owner-observed USB-device
QA record must match the staged record hash and all scenarios. This is an
attestation, not automated proof; clients cannot submit QA flags to the API.

Private RSA keys and evidence live in an ACL-protected directory outside Git;
public PEM is committed. A local key copy exists; an encrypted off-device backup
remains a rollout prerequisite. Local filesystem access is a trusted owner boundary.
No private telemetry is written to Firestore. Its existing unrestricted rules
require a separate authentication/isolation project.

Website releases use content/time-based `web_revision`, independent of APK build
and patch numbers. Firebase remains website/APK hosting; Shorebird remains the
signed patch authority. Production rollout and Android signature rejection,
upgrade retention, interrupted downloads, activation and rollback remain pending
until the user logs in and connects the designated test phone.


The owner authorized deployment without a physical-device test on 12 Oct 2026. The exact-patch local authorization path records skipped device tests and retains all non-device gates. See owner-authorized-deployment.md.
