# ADR-003: Record-backed insights and responsive administration destinations

Status: Accepted; code verified, Android staging QA pending.

Keep existing StationStateProvider calculations, role policies and persistence.
Remove invented analytics fallbacks rather than create a second source of business
data. Period totals and growth derive from actual calendar records; absent evidence
is explicitly empty. Printed receipt dates own historical records; uploads cannot
create duplicate-day analytics. Purge deletes and persists handovers as operational
data and suppresses intermediate snapshot hydration.

Separate Users, Roles and Permissions presentation while preserving existing
provider role/permission methods and Owner/Admin privilege boundaries. Reuse the
existing permissions matrix and individual override editor in the Permissions
destination. Use a 1024px breakpoint for side navigation; keep footer navigation
for smaller viewports. No native plugins, bundled assets, role IDs or APK version
changes are required. Deliver as a signed staged patch to base v1.0.33+34; physical
Android QA remains mandatory before stable promotion.

## Failed cloud purge recovery

Handover purge now retains a device-local SharedPreferences ID tombstone set. Local restoration and cloud snapshots filter these IDs so quota failures and stale caches do not reintroduce locally purged handovers. Cloud queries require Source.server; failed cloud deletion is explicitly incomplete, and other devices still need successful server deletion. APK history only exposes current/newer builds while physical cloud cleanup is pending quota recovery.
