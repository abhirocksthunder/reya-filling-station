# Current-data insights, administration screens and responsive navigation

## Current rollout state

Patch 1 is live on stable for v1.0.33+34 and the website is published. The owner explicitly waived physical-device testing. Prior staging QA requirements below describe the original workflow and are superseded for this deployment by owner-authorized-deployment.md.

Engineering implemented for a signed Dart patch targeting Shorebird base v1.0.33+34.
APK version and Firebase update policy remain unchanged. No station data was purged
by implementation; the fixes run when the owner invokes the existing purge control.

## Purge and analytics

Purge saves an empty handover list to SharedPreferences and deletes cashHandovers
alongside entries, receipts/scanAttempts, shifts, credit and notifications in cloud.
Cloud deletion uses bounded 200-document batches. Snapshot hydration is suppressed
during purge so partially deleted records do not refill the local state. Existing
users, role configuration and pump opening baselines remain station configuration.
Failed cloud deletion remains explicitly reported instead of claiming completion.

Analytics uses actual date-scoped calculation results for Today, seven days and
thirty days. Monthly points aggregate six real days per bucket. Missing days
contribute zero; no synthetic volumes, payment mixes, hourly sales or fixed growth
percentages remain. Fuel revenue charts use actual rate-segment amounts. Growth
requires a nonzero previous-period fuel total. The period picker remains available
when the selected period shows "Nothing to analyse". Current credit balances can
still yield a credit insight without fuel sales. Tips cite current fuel/payment/credit
totals, without invented customer names, pump/peak-hour claims or promised savings.
Printed receipt business dates take precedence over upload dates to avoid counting
one late-uploaded receipt twice. Ledger day ownership and labels use IST.

## Administration and navigation

Users, Roles and Permissions are separate destinations. Roles creates/edits/deletes
custom role definitions through existing provider methods; deletion confirmation
retains the existing base-role reassignment behavior. Permission assignment stays
in Permissions (role defaults and paginated per-user overrides). Users and its form
link to those destinations rather than showing role/permission editors inline.
Both editors require Owner/Admin privileges, including direct route access.
Role names have a strict 30-character limit; record lists paginate ten at a time.

At widths >=1024px owner and manager/staff shells use scrollable side navigation.
Smaller views retain the existing bottom footer and More sheet. Navigation indices
0–8 and permission identifiers remain intact; owner-only Roles/Permissions use new
local indices 9/10 without granting new manager/staff authority. Existing overview
section tabs stay available. Touch controls retain at least 44px sizing.

## Verification and rollout

125 Flutter tests pass, including new purge/reload, empty-period, actual sales,
late receipt, access guard and 360/430/1024/3840px administration checks. Existing
mobile/desktop navigation tests now assert the requested width-based behavior.
20 release-service tests pass. Generated android/local.properties SDK-path metadata
is excluded from provenance comparison, as in the signed base's manifest; real
Android source, assets, dependencies, SDK pin and Shorebird compatibility checks
remain required. No native/asset bypass flags are allowed.

Stage the signed patch for base 1.0.33+34, then connect the designated Android phone
after installing the migration APK. Preview with `shorebird preview --track staging
--release-version 1.0.33+34 --device-id <serial>` in the Reya project. Do not uninstall
or clear station data merely to test the upgrade. Verify silent download, next cold
launch activation, all requested UI changes and the retained shift/login state.
Promotion to stable requires the existing exact-patch device evidence gate. The
public website and installed stable-track apps are unchanged until the staged
patch passes Android QA. Unit tests are not a substitute for physical-device OTA
or live Firestore purge verification.

## Signed test artifact

Patch 1 is uploaded to staging for v1.0.33+34. Shorebird signed it with the protected private key and accepted native/asset compatibility without bypass flags. Local record: `%USERPROFILE%/.reya-ota/staging-1.0.33+34-1.json`. No Android phone is currently connected; stable promotion is blocked until exact-patch QA evidence is recorded.

## Settings cleanup (12 Oct 2026)

Removed the duplicate Roles & Screen Permissions card from compact and wide Settings layouts, including its local selection state and obsolete role-dialog import. Dedicated Roles and Permissions destinations and scanner controls are retained. This is a Dart-only change for the existing v1.0.33+34 base.

Removed duplicate Roles & Screen Permissions editor from compact and wide Settings. Dedicated Roles and Permissions screens and scanner controls remain. Deployed signed stable Patch 2 for v1.0.33+34 and website revision 20261012165537-7e7bac6d42d2f5c3. 125 Flutter tests, 22 release checks, web build, live revision/code/APK hashes passed. Physical-device testing skipped under standing owner authorization; original migration APK retained.

## Purge and APK retention (12 Oct 2026)

Firebase returned HTTP 429 Quota exceeded for older APK record deletion; 17 older release records and four cloud handovers remain. Local handover tombstones prevent failed cloud deletes or stale caches from restoring purged activity. Purge reads server-only and reports incomplete cloud deletion. Older APK files removed and links redirect to current v1.0.33+34; UI lists current/newer releases only. Tombstones are local to the device that invokes purge; other devices require successful cloud deletion. No live financial records were deleted by this maintenance change.

Published signed stable Patch 3 for base v1.0.33+34 and website revision 20261012171506-81291e1b070e297f. Removed six retired public APK files; older version links redirect to the current APK and retired release entries are hidden. Purge stores local handover tombstones, uses server-only deletion reads and shows incomplete cloud deletion in red. 126 Flutter tests including stale-cache resurrection regression and 22 release checks passed; published revision/code/current APK hashes and older-link redirects verified. Firebase HTTP 429 Quota exceeded blocked deletion of 17 older cloud release records; four cloud handovers remain until the owner retries purge successfully. Physical-device testing skipped under standing owner authorization. No live financial records were deleted by maintenance.
