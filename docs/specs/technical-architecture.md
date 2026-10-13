# Reya Filling Station — Technical Architecture Specification

## 1. System Overview & Context
Reya Filling Station is an offline-first forecourt petrol station management and financial reconciliation system built for rural Indian fuel retail environments (specifically Chatrai, Andhra Pradesh). The authoritative cloud database is Google Cloud Firestore in Firebase project `reya-filling-station-chatrai`.

The system serves three primary user personas:
- **Station Owner (Super-Admin)**: Remote oversight, dynamic pump/nozzle setup, fuel price versioning, customer credit Khata tracking, receipt-scan review inbox, and daily financial approval.
- **Forecourt Manager**: Operational shift supervision, receipt verification, transaction review, and variance investigation.
- **Shift Staff (Attendants)**: High-glare tactile mobile UI (Telugu `తెలుగు` & English `EN`), camera capture of IndianOil dispenser printouts, calibration test deduction, cash handover recording, and shift closing submission.

---

## 2. High-Contrast Rural UI/UX Principles
1. **56–64px Touch Targets**: Forecourt primary buttons (`Scan totaliser`, `Save entry`, `Submit shift for review`) exceed standard 48px to support physical gloves, grease, and rapid thumb interaction.
2. **High Glare & Sunlight Contrast**: Dark Forest Teal (`#0C4A4D`) paired with high-contrast Orange (`#E65100`), crisp white cards, and high-legibility bold metrics.
3. **No Cryptic Accounting Jargon**: Replaced double-entry accounting terms with forecourt physical mental models:
   - "Cash with me"
   - "Cash given to owner"
   - "Food expense / curries"
   - "ph.p" / "UPI"
   - "swiping" (POS card transactions)
   - "N.C" / "Bus Bill" (Credit ledger sales)
4. **Bilingual Forecourt Terminology**: Real-time language switcher (`తెలుగు | EN`) preserved across app launches.

---

## 3. Fixed-Precision Arithmetic & Authoritative Equations
To prevent IEEE 754 floating-point drift, all quantities are strictly stored as integers:
- **Currency**: Integer paise (1 Rupee = 100 paise). `₹34,096.08` -> `3409608` paise.
- **Volume**: Integer millilitres (1 Litre = 1000 mL). `168,676.720 L` -> `168676720` mL.
- **Rate**: Integer paise per litre. `₹117.52/L` -> `11752` paise/L.

### Golden Equations:
$$\text{Gross Dispensed (mL)} = \text{Closing CumVolume} - \text{Opening CumVolume}$$
$$\text{Billable Volume (mL)} = \text{Gross Dispensed} - \text{Approved Test Volume (e.g. 5,000 mL)}$$
$$\text{Fuel Sales Value (paise)} = \left\lfloor \frac{(\text{Billable Volume} \times \text{Rate}) + 500}{1000} \right\rfloor \quad (\text{Half-Up Rounding})$$
$$\text{Sales Variance} = \text{Total Accounted Payments} - \text{Calculated Fuel Sales}$$
$$\text{Expected Closing Cash} = \text{Opening Float} + \text{Cash Sales} - \text{Cash Expenses} - \text{Cash Debits} - \text{Owner Handover}$$
$$\text{Cash Variance} = \text{Counted Closing Cash} - \text{Expected Closing Cash}$$

---

## 4. IndianOil Receipt OCR Pipeline
IndianOil forecourt dispensers print a standard hierarchical slip:
```
FP. ID : 1
Pump SNo : 202501001272
Date : 09/10/2026
Time : 21:50:29

Nozzle No1
CumVolume: 169923.720

Nozzle No2
CumVolume: 274487.190
```
- **Hierarchical Regex Parser**: Identifies dispenser serial (`Pump SNo`), printed timestamp (`Date: dd/MM/yyyy`, `Time: HH:mm:ss`), locates `Nozzle No{X}`, and extracts `CumVolume` immediately underneath. Intermediate counters (`Shif1Sale`, `ShDayVol`, `CumSale`) are discarded.
- **Monotonic Continuity**: Enforces `Closing >= Opening`. Lower readings are rejected as possible unauthorized meter rollovers or mechanical tampering.
- **SHA-256 Logical Fingerprint**: `sha256(PumpSNo | Date | Time | Volumes)` prevents replay or double-submission of identical slips.
- **Business Date Plausibility**: Validates printed receipt date against Asian/Kolkata station business date, flagging stale slips (e.g. 9 Oct printout submitted on 10 Oct shift).

---

## 5. Uncertainty-Aware Geofence Engine
Forecourt scanning requires verified presence within the owner-configured radius (100m to 200m, default 150m):
- Target fix age $\le 30\text{s}$, GPS accuracy $\le 25\text{m}$.
- Uncertainty formula:
  $$\text{Effective Boundary} = \text{Haversine Distance} + \text{Accuracy Radius} \le \text{Station Radius}$$
- Scanning is inhibited when outside perimeter or when GPS accuracy is degraded.

---

## 6. Firestore Security & Zero-Trust Access Boundary
- **Station Scoping**: All operational documents live under `/stations/{stationId}/...`.
- **Role Enforcement at Commit Time**: Rules verify `active == true` and membership role (`owner`, `manager`, `shiftStaff`) via `get(/databases/.../members/$(request.auth.uid))`.
- **Immutable Financial Truth**: Clients cannot directly write to `/acceptedReadings` or `/latestReadings`; only the trusted backend can advance authoritative reading pointers.
- **Confidential Financials**: Payroll and private owner ledger documents are strictly restricted to the `owner` role.


## Web first-paint loading (12 Oct 2026)

`web/index.html` owns the pre-engine loading UI because Flutter widgets cannot render
before the engine and Firebase initialization complete. A local 320px, 16-frame GIF
depicts an attendant refueling a compact car and rupee coins flowing to dashboard bars. Inline CSS and
HTML provide readable status even before the image downloads. The overlay remains
until `flutter-first-frame`, not a guessed timeout. A 20-second timer offers Reload
without dismissing the loader. CSS reduced-motion replaces animation with a PNG.
The layout is constrained and scrollable from 360px mobile to 4K desktop.

`performWebOcr` retains its existing callback contract but lazily loads pinned
Tesseract/HEIC scripts through a shared promise. Download failure calls `onError`
and clears the promise for a later retry. Startup no longer blocks on either CDN.
Provider/authentication behavior and live Firestore streaming are unchanged. The
loader represents initialization, not a percentage of cloud data downloaded.


## Persistent permission-aware staff footer (12 Oct 2026)

The shared APK/web StaffShell previously assigned `bottomNavigationBar: null` when
the effective permitted-tab count was one. `StationSettings.getScreensForUser`
can produce one tab through the Users Only preset, per-user overrides, or its
empty/invalid-ID fallback. Normal defaults remain four staff and five manager tabs.
There is no version-27 source snapshot in available Git history, so the release
where a particular user's effective permissions changed cannot be established.

The shell now always renders its footer. One destination uses a Material/InkWell
tile with a selected semantic label and 64px height because Flutter's standard
BottomNavigationBar requires at least two destinations. Multiple destinations
retain the existing permission-driven BottomNavigationBar and More behavior.
This is presentation-only; role and per-user authorization resolution is unchanged.

Navigation regression tests exercise manager/staff defaults and Scan navigation,
single permitted Users and My Shift destinations, denial of omitted Scan, and
360/430/3840px constraints. These exposed adjacent mobile issues: My Shift actions
now wrap with 44px buttons, People & Roles dropdowns have bounded widths, and
shared pagination switches to compact layout below 650px with 44px touch targets.


## Versioned website/APK deployment: v1.0.30+31

The release pipeline builds the existing ARM/ARM64 Android package with its
existing signing identity and the Flutter web release. It verifies package
versionCode 31/versionName 1.0.30, embeds the identical binary in Hosting's
`static/reya-filling-station.bin`, and preserves the versioned APK rewrite.
Hosting deploys first; SHA-256 verification of the public APK precedes the
Firestore announcement. Update-mask PATCH requests modify only latestVersion,
latestBuildNumber, updateUrl and releaseNotes on settings/general; forceUpdate,
roles, custom roles, users, financial data and station configuration are preserved.
The apkReleases document records version, build, URL, bytes and publication time.


## Focused Owner Overview sections (v1.0.31+32)

StationOverviewScreen now owns presentation-only section and pagination state.
Its header and section track remain outside the active content scroll view.
Summary retains deterministic day totals and compact task shortcuts; Operations
contains review requests, cash handover workflow, paged pumps/shifts and latest
receipt; Team contains paged user approvals and app/location cards; AI Insights
builds OwnerAiAnalyticsPanel only on selection; Reports reuses DailyReportScreen.
Section changes reset overview list pages and reveal the selected tab on phones.
Shrinking live lists clamp to the last valid page. Numeric totals always use the
complete provider snapshot, not just the visible records.

AI remains gated by hasOwnerPrivileges; Team and Reports are gated by existing
canAccessScreen IDs. A role change safely returns inaccessible sections to Summary.
No provider, Firestore schema, runtime, or authorization model was introduced.
CashHandoverWorkflowCard pages incoming, forwarding and history lists using the
existing PaginationControl. Reports currency rows and AI donut legends adapt to
narrow screens. Visual QA uses a separately compiled offline sample-data entrypoint
and output directory; it is removed before the production build and never deployed.


## Owner footer as the single primary navigation (v1.0.32+33)

OwnerShell renders its existing BottomNavigationBar on every viewport instead of
switching between a sidebar and footer. Removed the category-pill builder, drawer,
hamburger/scaffold drawer key, sidebar helpers and the Full Drawer sheet action.
All nine original screen indices remain unchanged; five footer destinations and
the five More-sheet controls preserve direct and notification-driven routing.
Overview's own section tabs remain separate from primary application navigation.
Content and footer use bounded desktop widths. More is constrained to 80% of the
viewport height and scrolls so no destination disappears on short screens.
The More heading wraps naturally and the Users role actions use Wrap with 44px
buttons. Tests cover 360/430/3840px, no drawer/hamburger/duplicate Overview row,
preserved overview section tabs and footer navigation to Reports/Users/Settings.


## Record-backed insights and responsive administration

See [current-data implementation](current-data-insights-and-admin-navigation.md) and ADR-003. The old footer-only desktop policy is superseded by a 1024px side-menu breakpoint; owner destination indices 0–8 are preserved and role/permission presentation stays separate.
