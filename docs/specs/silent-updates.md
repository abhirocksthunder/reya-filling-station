# Reya silent-update implementation and rollout

## Current state

Production is still v1.0.32+33. Shorebird CLI 1.6.128 is installed; its SDK list
includes Flutter 3.41.9. The CLI's own bundled default Flutter is newer; release
commands explicitly pin 3.41.9. Existing Flutter remains 3.41.9/Dart 3.11.5.
115 Flutter tests and 19 API release tests pass; the website build succeeds with
an independent revision. These are integration checks, not Android OTA validation.
Browser login timed out. The user chose to finish code checks and log in/connect a phone later.
No Shorebird app ID was invented; no migration APK or patch has been published.

## Setup and release

1. Finish the browser `shorebird login` with the designated user-owned account.
   `shorebird account whoami --json` must report `plan=free`, `plan_level=free`,
   no positive overage, and match `%USERPROFILE%/.reya-ota/owner-account.json`.
   The code never changes subscriptions or buys overage.
2. From `D:/reya-filling-station`, run `shorebird init --display-name "Reya Filling Station"`.
   Review the real `shorebird.yaml`, its pubspec asset declaration and `auto_update`
   default. Keep background updating enabled and production on stable.
3. `scripts/setup_reya_patch_keys.ps1` generates RSA2048 outside Git, sets owner/System
   directory ACLs and saves a local backup; public PEM is `config/ota-public.pem`.
   Arrange encrypted off-device backup before rollout. Do not print PEM private
   contents, export auth tokens, or put keys into source/build logs.
4. Connect and authorize the designated Android USB test device. Set Android
   `JAVA_HOME` to the existing Studio JBR if required. Keep current debug signing
   certificate for this migration; signing-key rotation would break upgrades.
5. Authenticated owner `POST /reya-filling-station/build/apk` with `{"bump":"patch"}`
   creates the next base (expected v1.0.33+34; recheck deployed version first).
   Default build-only requests also use patch bump for the first migration.
   Poll `/build/apk/status`. CLI/config/account/key/SDK failures occur before bump.
   Later build failures retain the bumped source for investigation and retry.
6. The service calls `shorebird release android --artifact=apk --flutter-version=3.41.9
   --public-key-path=<public PEM> --json -- --no-tree-shake-icons`.
   It checks package ID/version and certificate before copying download artifacts.
   Evidence in `.reya-ota/base-X.Y.Z+N.json` retains hashes and compatibility inputs.
   Configure `REYA_SHOREBIRD_BIN`, `REYA_PATCH_PUBLIC_KEY`, `REYA_PATCH_PRIVATE_KEY`,
   `REYA_OTA_STATE_DIR` or `REYA_ANDROID_BUILD_TOOLS` only when paths differ.

## Patches and verification

`POST /reya-filling-station/build/patch` with
`{"action":"stage","release_version":"1.0.33+34"}` signs and publishes to staging.
Poll `/build/patch/status`; a successful stage awaits device verification.
Base/patch jobs cannot overlap. There is no endpoint accepting CLI arguments,
private key data or a `verified:true` shortcut. Native/asset bypass flags are denied.

Preview using `shorebird preview --track staging --release-version 1.0.33+34
--app-id <real app ID>` on the designated phone. Test actual upgrade from +33
without uninstalling/clearing data. Confirm retained login/settings/shifts;
first launch silently downloads and next cold launch applies the patch. Verify
offline/interrupted/no-update behavior, owner/manager/staff navigation, 360–430px
through 4K layouts, unchanged APK banners/records/auth/permissions/active shift.
Perform invalid-signature rejection in a test environment and rehearse staged
rollback, then restore and retest the exact patch intended for promotion.

`python scripts/reya_verify_staged_patch.py 1.0.33+34 <patch> --device <adb serial>`
requires an authorized connected phone and records personally observed checks,
applied patch number, IST time and the exact staged-record hash. Missing checks
save no verification. This deliberate human QA attestation cannot be claimed as
an automated test. The API trusts only local protected evidence.

`POST /build/patch` with `{"action":"promote","release_version":"1.0.33+34",
"patch_number":<verified number>}` moves the same immutable patch to stable,
after querying Shorebird to ensure staging metadata did not change. No rebuild,
APK announcement, version bump or additional user approval occurs.

Rollback: `shorebird patches rollback --release-version <base> --patch-number <N>`.
Retain evidence and inspect console state. Installed devices discover rollback
through their update check and activate the resulting code on a subsequent launch;
do not promise immediate running-process replacement. A rolled-back or altered
staged record requires renewed QA before promotion.

## Website and optional migration announcement

`python scripts/build_web_release.py` in Reya builds web and generates
`build/web/version.json` with independent `web_revision` plus base metadata.
It updates bootstrap cache keys without editing pubspec. Publish the existing
Firebase project with `firebase deploy --only hosting` after checking output.
The existing APK rewrite points at `build/web/static/reya-filling-station.bin`;
prepare that file from the identity-verified migration APK for the migration
hosting deployment. Subsequent web deployments must retain the hosted APK binary.

After Android upgrade testing and hosting the verified APK, run Reya's
`node scripts/publish_reya_migration.cjs --publish 1.0.33 34`. It requires a signed
base manifest, matching local hash, matching live website base version, and exact
public-download hash before setting release metadata. It sets `forceUpdate:false`
and preserves unrelated settings. Existing users can continue station work until
they choose the migration APK. Patches never invoke this publisher. The website
and APK are not deployed by merely running the builder.

## Remaining rollout gates

Account login/init; designated phone; encrypted off-device key backup; signed
migration APK; Android upgrade/signature/download/cold-launch/rollback QA;
Firebase public-download verification and optional announcement; one staged
UI demonstration promoted only after QA. All remain pending, never marked complete
by unit tests. SDK quota exhaustion must leave the working app usable.


## Migration APK build checkpoint — 12 Oct 2026 12:19 pm IST

Generated Shorebird-enabled migration APK v1.0.33+34 using the user-owned free account, pinned Flutter 3.41.9/Dart 3.11.5, original application ID/certificate, embedded patch public key and full bundled icons. Local APK hash: 86925739cb09250b55076cf66f36fd00fd8d40b3ac9e7aecf0b23237c99399fe. 115 Flutter tests and 21 release API tests pass. Excluded generated Android SDK paths from source-provenance comparisons while retaining native-source checks. APK is ready for device installation/testing; no phone connected, no Firebase deployment or production update announcement.

Prerequisite: install official Android SDK command-line tools including apkanalyzer. Shorebird validates an AAB even when generating an APK; missing tools are now rejected before version mutation. The actual APK verification checks the embedded RSA public key by DER key identity and checks full icon font sizes, in addition to certificate/application/version checks.


## One-time mandatory migration override — 12 Oct 2026 1:58 pm IST

Published website and signed Shorebird migration APK v1.0.33+34 to Firebase Hosting. Verified the public APK SHA256 86925739cb09250b55076cf66f36fd00fd8d40b3ac9e7aecf0b23237c99399fe matches the identity-verified base. At the user's request because station APK use has not begun, published latestVersion=1.0.33, latestBuildNumber=34 and forceUpdate=true, preserving unrelated settings. Migration publisher now supports explicit --force while remaining optional by default. Previous v1.0.32+33 installations receive the mandatory update policy; Android installation still requires user confirmation. Physical-device OTA download/activation QA remains pending; no OTA patch was promoted.

Command: `node scripts/publish_reya_migration.cjs --publish 1.0.33 34 --force`. The explicit owner instruction overrides the original optional rollout for this publication. Omitting `--force` retains the optional default. Signature/version/public-download checks remain mandatory, and routine signed patches still require staged-device QA before stable promotion.
