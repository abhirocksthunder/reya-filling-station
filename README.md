# Reya Filling Station (రేయా ఫిల్లింగ్ స్టేషన్)

[![Flutter](https://img.shields.io/badge/Flutter-3.41.9-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11.5-0175C2?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-reya--filling--station--chatrai-FFCA28?logo=firebase)](https://console.firebase.google.com)
[![Project Guardian](https://img.shields.io/badge/Project_Guardian-PASS-success)](https://github.com)

A rural-first petrol filling station management, meter reading capture, and financial reconciliation application architected for forecourt operations in Chatrai, Andhra Pradesh. Built with Flutter cross-platform (Android APK & Responsive Web), backed by Google Cloud Firestore (`reya-filling-station-chatrai`).

---

## 🌟 Key Capabilities

1. **Rural-First Forecourt Usability & Zero-Trust Authentication**:
   - High-contrast color palette (`#0C4A4D` Deep Forest Teal & `#E65100` Action Orange) readable in blinding direct sunlight.
   - Large 56px–64px tactile touch targets for one-handed thumb interaction and forecourt gloves.
   - Instant dual-language toggle (**Telugu `తెలుగు`** & **English `EN`**).
   - Replaced accounting abstractions with physical notebook concepts: *"Cash with me"*, *"Cash given to owner"*, *"ph.p"*, *"swiping"*, *"N.C"*, and *"curries/food"*.
   - **Zero-Trust Login Gate**: Enforced authentic sign-in via `LoginScreen` for both mobile and web. Unauthenticated sessions are strictly blocked.
   - **Role-Based Isolation**: Staff only see their own assigned shift, pump, and money entries. Authoritative station owners (**Kalyan** & **Ranjit**) access the full operations portal.
   - **Dedicated User Management**: Full-page `UserFormScreen` allowing owners to add and edit users, roles, emails, phone numbers, villages, and addresses. Shift assignment is automatically hidden for Owner roles.
   - **10-Item Pagination Mandate**: `PaginationControl` widget with 44px+ touch targets and range display integrated across People Management, Credit Khata, Receipts Inbox, and Money Ledger.

2. **Hardened IndianOil Forecourt OCR Pipeline, HEIC/HEIF Gallery Support & Strict Validation Gate**:
   - Automatically parses IndianOil dispenser printout slips (`FP. ID`, `Pump SNo`, `Date: dd/MM/yyyy`, `Time: HH:mm:ss`), including two-column split header blocks (`:3` / `:202501001346`).
   - **Native HEIC / HEIF Gallery Photo Decoding & Multi-Orientation Recovery (v1.0.25+26)**:
     - On Android (`ocr_engine_mobile.dart`), passes the native local file path (`photo.path`) instead of base64 data URIs to Google ML Kit, automatically detects `.heic` / `.heif` gallery photos (by extension or ISO `ftyp` magic bytes `heic`, `heix`, `mif1`, `msf1`), decodes them via `dart:ui` `instantiateImageCodec` to lossless temporary `.png` files, and runs automatic `0° / 90° / 270° / 180°` orientation recovery so sideways EXIF/HEIF gallery photos are read accurately.
     - On Web (`web/index.html`), integrates `heic2any` to automatically convert `.heic` / `.heif` gallery uploads to `image/jpeg` in the browser before running Tesseract.js adaptive Otsu recognition.
   - **Multi-Pass Parser & Strict Below-Line CumVolume Extraction (v1.0.26+27)**: Normalizes line tokens, fixes optical ambiguities (`O`/`o` -> `0`, `l`/`I` -> `1`, faint decimal points), preserves Nozzle 1 section lines even when the `Nozzle No1` header is blurred, strictly extracts Nozzle 2 `CumVolume` on or **below** the `CumVolume:` line (never looking upward with `↑` into `ShMTHSale`), and enforces a `25,000 L` maximum daily delta plausibility guard against baseline readings so lakh-scale misreads are rejected.
   - **Strict Intermediate Counter & Sales Exclusion**: Explicitly ignores intermediate counters (`Shif1Sale`, `Shif1Vol`, `Shif2Sale`, `Shif2Vol`, `Shif3Sale`, `Shif3Vol`, `ShDaySale`, `ShDayVol`, `ShMTHSale`, `ShMTHVol`) and forecourt sales rupees (`CumSale`), isolating only cumulative dispensing totalisers (`10,000` to `9,999,999.999 L`).
   - **In-Browser Tesseract.js OCR Engine**: Enables real client-side OCR directly in Flutter Web using Tesseract.js (v5) with `heic2any` conversion and non-destructive contrast enhancement.
   - **In-App OCR Debugger & Diagnostics Panel**: Interactive inspector showing active engine telemetry, execution latency, field-by-field matching against expected pump parameters, unparsed raw OCR text with one-tap clipboard copy, and step-by-step mobile troubleshooting guidance.
   - **Strict Forecourt Gates & Scan Totaliser Again Alert**: Enforces monotonic counter continuity (`Closing >= Opening`), requires both Nozzle 1 and Nozzle 2 readings on 2-nozzle pumps, immediately alerts attendants with a 1-tap **Scan Totaliser Again** dialog if either nozzle reading is missing or exceeds the daily volume threshold (`> 25,000 L`), and flags pump mismatches with explicit `Wrong pump` dialogs.
   - **Decimal Amount Entry, Indian Comma + Decimal Formatting Everywhere, Explicit IST Time Pills & Clear Money Entries UX (v1.0.27+28)**:
     - Formats all currency amounts across the entire application with Indian commas and 2 decimal places (`₹12,000.00`, `₹1,25,432.50`) via `CurrencyFormatter.formatPaise`, and formats amount text boxes live with commas and up to 2 decimal places via `IndianCurrencyInputFormatter` (`MoneyEntriesScreen`, Edit Entry modal, and `CreditKhataScreen`).
     - **Explicit Untruncated IST Time Pills on Money Entries**: Refactored `MoneyEntriesScreen` and `MoneyLedgerScreen` mobile entry cards into a 2-row responsive layout (`[Avatar + Category + Staff Badge + Reference + Amount]` on Row 1, `[Calendar Date + Highlighted IST Time Pill (08:40 AM) + Edit/Delete Actions]` on Row 2) and guaranteed non-empty `timeString` normalization in `StationStateProvider.addTransactionEntry` so entry times are always prominently visible and never truncated on mobile screens.
     - Automatically clears the amount input when switching between `Received` / `Paid out` tabs or category pills, syncs `Paid out -> To owner` entries directly as the **Cash Handover to Owner** value across `MyShiftScreen`, `CloseShiftScreen`, `ShiftReviewScreen`, and `StationOverviewScreen`, deduplicates credit balance totals on `StationOverviewScreen`, and provides an interactive explanation on the `Needs owner category` badge in `CloseShiftScreen`.

3. **Exact Integer Paise, Millilitres & Live Multi-Pump Calculations (v1.0.15+16)**:
   - Zero floating-point drift across platforms. Stored as integer paise (`₹98,146.88` = `9814688` paise) and integer millilitres (`168,676.720 L` = `168676720` mL).
   - **Mid-Day Fuel Price Change Tracking & Multi-Tier Volume Partitioning**:
     - Automatically partitions dispensed fuel volumes whenever fuel prices change mid-day or across intermediate receipt scans (`ReconciliationService.calculateMultiSegmentNozzle`).
     - Volume sold before a price change scan reading is calculated at the previous rate ($V_1 \times R_1$), and volume sold from the price change reading onwards is calculated at the new rate ($V_2 \times R_2$).
     - The mandatory 5.00 L daily test volume deduction is accurately apportioned to the initial opening segment where physical morning testing occurs.
     - Both attendants on `ScanReceiptScreen` and station owners on `+ Add IndianOil Pump Receipt` can confirm or adjust the nozzle fuel rate (`₹ / L`), updating the active dispenser nozzle rate in local state and Cloud Firestore upon approval.
     - Displays `⚡ Price Changed` indicators and expandable tier breakdown cards across `StationOverviewScreen` and `DailyReportScreen` detailing exact volumes, rates, and amounts per tier.
   - **Continuous Real-Time Multi-Pump Meter Engine**: Automatically recalculates gross litres, mandatory daily 5.00 L test deduction, net billable litres, and total revenue to receive immediately when a receipt is captured or approved (`Closing - Opening - 5L Test × Fuel Rate`).
   - **Live Forecourt Multi-Pump Breakdown**: Displays individual pump tables for all nozzles (opening, closing, gross, -5L test, net, rate, amount to receive) and Station Grand Totals (MS, HSD, Total Dispensed, Total Revenue to Receive) directly on the Owner Station Overview screen.
   - **Strict Date-Isolated Daily & Shift Review Reports**: `DailyReportScreen` and `ShiftReviewScreen` (`state.getVisibleShiftsForDate`) strictly isolate financial entries, dispenser readings, and shift review statuses (`Needs review`, `In progress`, `Approved`) for the selected date without bleeding today's shifts onto previous dates.
   - **Half-up rounding per nozzle line**.

4. **Zero-Trust Security & Station Scoping**:
   - Granular Firestore security rules with commit-time membership validation (`owner`, `manager`, `shiftStaff`).
   - Clients cannot forge accepted readings; immutable reading history and latest pointers are strictly backend-managed.
   - 150m uncertainty-aware geofence boundary calculation (`Distance + Accuracy <= 150m`).
   - Real-time Firestore synchronization for members, entries, and scan attempts.

5. **Complete Dual-Experience Shell (`RFS`), Strict Hierarchical Cash Handover Workflow (`CashHandoverWorkflowCard`), Built-in `Admin` Role with Full Owner Privileges & Create Custom Roles Screen (`RoleManagementDialog`), Owner/Admin Minimalistic AI Sales Intelligence (`OwnerAiAnalyticsPanel`) with Weekly/Monthly Graphs & Pie Charts, Self Login User Indicator (`(Self)`), Dynamic Roles & Screen Permissions Governance, Scoped Manager User Management with Owner Approval, Shift-Only Live Location Tracking Behind Feature Flag, Realistic Multi-User Use-Case Seeding, Versioned Release APK Distribution (~54 MB ARM Release) & Mobile-First Owner Portal (v1.0.29+30)**:
   - **Strict Hierarchical Cash Handover Workflow & Clean Receiver Dropdowns (`CashHandoverRecord` & `CashHandoverWorkflowCard`) (`v1.0.29+30`)**:
     - **Role Hierarchy Enforcement**: No user can ever hand over cash to themselves or to `Shift Staff`. **Shift Staff (`shiftStaff`)** can hand over cash upwards to **Manager, Admin, or Owner**. **Managers (`manager`)** can **ONLY** hand over cash upwards to **Owner or Admin** (`receiver.hasOwnerPrivileges`) — never to Shift Staff or another Manager. **Owners / Admins** can only hand over cash to another Owner or Admin.
     - **Clean Person-Name-Only Dropdowns**: Removed role prefixes (`Manager (...)`, `Owner (...)`) and nameless `'Owner'` placeholders from all `Handover to` dropdowns (`CloseShiftScreen`, `MoneyEntriesScreen`, and `CashHandoverWorkflowCard`), displaying only eligible receiver names (`getEligibleHandoverReceiverNames`).
     - **End-to-End 3-Step Handover Workflow**: Visual 3-step hierarchy pipeline (`1. Shift Staff → 2. Manager → 3. Owner / Admin`), incoming verification queue (`Accept Cash` / `Reject`), **1-Tap Manager-to-Owner Forwarding** (*"Cash Collected from Staff"* banner with `Handover ₹... to <Owner>` action via `forwardHandoverToOwner`), and live Firestore-synced activity trail (`/stations/chatrai/cashHandovers`).
   - **Release APK Size Optimization (`--release --target-platform android-arm,android-arm64`) (`v1.0.29+30`)**:
     - Packaged official distribution binaries from `flutter build apk --release --target-platform android-arm,android-arm64` (`app-release.apk`, **~54 MB**) instead of `app-debug.apk` (**186.41 MB** with unstripped JIT VM and `x86_64` emulator libraries), reducing APK size by over **70%**.
   - **Built-in `Admin` Role (`UserRole.admin`) & Create Custom Roles Screen (`RoleManagementDialog`) (`v1.0.29+30`)**:
     - Added built-in **`Admin`** role (`UserRole.admin`, `hasOwnerPrivileges == true`) with the **exact same full privileges as `Owner`**: routes directly to `OwnerShell`, accesses all 13 station screens by default, views the AI Sales Intelligence dashboard, approves manager user requests, and configures station settings.
     - Added **`RoleManagementDialog` (`+ Create / Manage Roles`)** accessible from **People & Roles**, **Station Settings**, and **Add / Edit Person (`UserFormScreen`)**. Owners and Admins can create custom roles (e.g., `Co-Admin`, `Station Auditor`, `Accountant`, `Supervisor` with strict 30-char role name limit), select their base privilege tier (`Same as Owner / Admin`, `Manager Privileges`, or `Shift Staff Privileges`), toggle allowed screens across all 13 station screens, and assign custom roles (`customRoleId`, `customRoleName`) to any user.
   - **Owner / Admin Minimalistic AI Sales Intelligence, Weekly/Monthly Graphs, Pie Charts & Growth Tips (`v1.0.28+29`)**:
     - Exclusively rendered for `Owner` and `Admin` (`currentUser.hasOwnerPrivileges`) on `StationOverviewScreen` (`OwnerAiAnalyticsPanel`), keeping Staff and Manager shells untouched.
     - **Period Switcher (`Today` | `Weekly (7D)` | `Monthly (30D)`)**: Instant switching between Today's shift/pump breakdown, 7-day daily sales & volume trends, and 30-day (4-week) revenue trends with natural-language AI executive summary and period growth badge (`+8.4%` / `+12.6%` / `+16.8%`).
     - **Interactive Bar + Smooth Bezier Trend Line Graph (`_SalesTrendGraphPainter`)**: Animated dual/stacked bars for **Diesel (HSD)** and **Petrol (MS)** with tap-to-inspect callout strip displaying exact date/window, ₹ total, and MS/HSD litres.
     - **Animated Pie / Donut Charts (`_DonutChartPainter`)**: Dual animated donut charts for **Payment Collections Pie Chart** (`PhonePe / UPI`, `Cash`, `Card (POS)`, `Credit Khata` with center Digital % callout) and **Fuel Grade Revenue Pie Chart** (`Diesel` vs `Petrol` with center Total Volume callout).
     - **Visual AI Tips to Increase Station Sales (`AiSalesGrowthTip`)**: Category-filterable cards (`All AI Tips`, `Diesel & Fleet`, `Peak Hours`, `UPI & Express`, `Khata & Cashflow`) combining forecourt photo backdrops (`assets/images/media_1791634198035.png`), animated canvas illustrations (`_ForecourtTipIllustrationPainter`), estimated ₹/volume impact badges, live station telemetry evidence, and a 3-Step Sales Action Plan modal.
   - **Self Login User Indicator (`(Self)` Badge & Label)**:
     - Whenever a user is logged in (`Owner`, `Admin`, `Manager`, or `Shift Staff`), their own user entry across **People & Roles (Users)** (mobile cards & desktop table), **StationTopBar** account switcher dropdown, **Station Overview** (*Team App Versions & Live Location*), **Station Settings** (*User App Version & Device Tracking*), and **Edit Person (`UserFormScreen`)** clearly displays **`(Self)`** next to their name along with a **`Self`** pill badge (`● Self (Your Login)`), resolved via `StationStateProvider.isSelfUser(UserProfile)` matching by ID, normalized 10-digit phone number, or name + role.
   - **Dynamic Roles & Screen Permissions Governance (Owner & Admin Login)**:
     - **Role-Level Screen Permissions Matrix**: Station Owners and Admins can configure which of the 13 station screens (`My Shift`, `Scan Receipt`, `Money Entries`, `Close Shift`, `People & Roles (Users)`, `Station Overview`, `Daily Reports`, `Receipts Inbox`, `Shift Review`, `Money Ledger`, `Credit Khata`, `Pumps & Nozzles`, `Station Settings`) are enabled for each built-in or custom role (**Owner**, **Admin**, **Manager**, **Shift staff**, plus custom roles) from both **People & Roles** and **Station Settings**. Includes 1-tap presets (*Preset: Users Only*, *Preset: Forecourt + Users*, *Reset Role Default*) and instant Cloud Firestore sync (`/stations/chatrai/settings/general.roleScreenPermissions` and `customRoles`).
     - **Per-User Custom Screen Permission Overrides**: Owners and Admins can customize screen access for any individual user via the **Screens** button on user cards/rows or directly inside `UserFormScreen` (*Inherit Role Default* vs *Custom Screen Override* stored in `UserProfile.permissions`).
     - **Dynamic Shell Enforcement**: `StaffShell` dynamically builds bottom navigation tabs (and a `More` sheet when >5 screens are permitted, or a clean full-screen view when 1 screen such as *Users Only* is permitted) strictly from `state.getAllowedScreensForUser(currentUser)`. Core Owner/Admin screens (`station_overview`, `people_management`, `station_settings`) are lock-out protected for Owner and Admin accounts.
   - **Scoped Manager Role User Management with Owner/Admin Approval & APK Sharing**:
     - **Owners** and **Admins** (`user.hasOwnerPrivileges`) access `OwnerShell`. **Managers** (`UserRole.manager`) log into `StaffShell` (never exposing unpermitted Owner portal pages) and receive their permitted tabs (`PeopleManagementScreen` / Users tab + forecourt tabs or Users-only preset).
     - When a **Manager** adds a new user (`addNewUser`) or edits an existing user (`updateUser`), the user enters a `pending_approval` state (`approvalStatus: 'pending_approval'`, `requestedBy`, and `pendingEditData` for edits to existing approved users) and dispatches an instant Owner notification. Unapproved new users are blocked from logging in until approved by an Owner or Admin. Managers only view/manage non-Owner/non-Admin accounts.
     - **Owners & Admins** see a **Pending User Approvals** banner on both **Station Overview** and **People & Roles** with 1-tap **Approve** (`approveUserRequest`) and **Reject** (`rejectUserRequest`) actions.
     - **Managers**, **Admins**, and **Owners** can share the latest versioned Android APK (`Share / Download APK` header button, per-user `Share APK` button on `PeopleManagementScreen`, and top-bar profile menu item) via WhatsApp (pre-filled with APK download link, mobile login, and Security PIN), clipboard copy, or direct download.
   - **Shift-Only Real Device GPS User Location Tracking Behind Feature Flag & Google Maps Deep Links (v1.0.27+28)**:
     - Integrates `geolocator` (`LocationService.fetchRealDevicePosition`) on Android, iOS, and Web to acquire **real hardware GPS coordinates** and resolve human-readable location names (`LocationService.resolveLocationName`, e.g., `RFS Chatrai Forecourt`, `Chatrai, AP`).
     - **Shift-Only Lifecycle & Feature Flag**: Controlled by `StationSettings.enableLiveLocationTracking` (toggleable in **Station Settings -> Location & Scan**). Location tracking runs **only while the user's shift is actively in progress** (`isUserShiftInProgress`) and automatically stops the moment the user closes/submits their shift (`submitShiftForReview`). Staff can also tap `Start shift` on `MyShiftScreen` to start/resume their shift.
     - **1-Tap Google Maps Deep Link**: Tapping the user's location name or coordinates on `MyShiftScreen`, `StationOverviewScreen`, `PeopleManagementScreen`, or `ReceiptInboxScreen` opens the exact coordinates directly in Google Maps (`LocationService.openInGoogleMaps`).
   - **Full Untruncated Mobile Layout Across All Staff & Owner Screens (`v1.0.27+28`)**:
     - Stacks **Nozzle 1 (Petrol)** and **Nozzle 2 (Diesel)** on `ScanReceiptScreen` into full-width mobile cards (`< 600px`) with explicit header badges (`Prev: 170,271.900 L`) and full-width `TextField`s.
     - Responsive mobile action cards in `StationSettingsScreen -> Database & Testing` (`_buildDatabaseActionCard` stacking description and full-width button on `< 620px` viewports) and wrapped headers/version cards in `StationSettingsScreen -> App Version & Updates` (`Running Latest ✓` and `Cloud Version & APK Distribution` never overflow horizontally).
     - Responsive vertical stacking of `Handover to` / `Date & Time` and `Submit shift for review` / `View details` buttons on `CloseShiftScreen`, horizontal scrollable nozzle tables on `PumpSetupScreen`, and `Expanded` / `Wrap` protection on `CreditKhataScreen` and `MoneyLedgerScreen`.
   - **Permanent Entry Deletion & Tombstone Sync**: Added first-class Delete Entry actions across both Owner `MoneyLedgerScreen` (mobile cards and desktop table) and Staff `MoneyEntriesScreen` with confirmation dialogs. Deleting an entry removes it from local state, deletes `/stations/chatrai/entries/<entryId>` in Cloud Firestore, and records the ID in `StationSettings.deletedEntryIds` tombstones so stale browser/device caches can never re-upload deleted entries. Fixed the startup async race condition between `SharedPreferences` and Firestore snapshots and updated `web/index.html` to purge legacy `localStorage` entry keys before boot.
   - **Versioned APK Download Links**: Official APK download links embed the target release version and build number directly in the URL and filename (`https://reya-filling-station-chatrai.web.app/static/reya-filling-station-v1.0.27+28.apk`) with `no-cache, no-store, must-revalidate` CDN headers so Android devices always download the exact latest APK binary (hosted at `/static/reya-filling-station.bin` to bypass Firebase `.apk` ignore rules).
   - **Per-User App Version & Device Tracking**: Records every user's installed app version (`appVersion`, e.g., `v1.0.27+28 (Android)` / `v1.0.27+28 (Web)`) and `lastSeenAt` (IST) on login and session restore, syncs to Cloud Firestore (`/stations/chatrai/members/<userId>`), and displays per-user version badges across **People & Roles**, **Station Overview** (*Team App Versions & Live Location (1m Sync)*), and **Station Settings -> App Version & Updates**.
   - **Realistic Multi-User, Multi-Pump Sample Use-Case Dataset (`seedSampleUseCaseDataToFirestore`)**: Provides a 1-tap **Load Sample Use-Case Data (Users, Entries & Reports)** action in **Station Settings -> Database & Testing** (and pre-seeded in live Cloud Firestore) with 8 realistic users (`Kalyan`, `Ranjit`, `Abhilash`, `Ramesh Babu`, `Venkat Rao`, `Srinivas`, `Anjaneyulu`, `Prabhakar`), 2 active pumps with 4 verified opening/closing receipt scans (`3,640.00 L` net sold = `₹4,01,306.30`), 13 Money Entries with explicit IST times across `PhonePe`, `Card`, `Credit`, `Cash`, `Expense`, and `To owner` (`₹1,10,000.00` handover), 3 Credit Khata accounts (`₹40,000.00`), and 2 shifts (`Morning` & `Evening`).
   - **End-to-End Shift Review & Approval Workflow**:
     - **Active-Only Shift Visibility**: Unassigned or unstarted (`Scheduled`) shifts are hidden on `StationOverviewScreen` and `ShiftReviewScreen` until an assigned staff member logs in and starts or submits their shift. The **Approve Shift & Handover** button is never shown when a shift is `Scheduled`.
     - **Staff Close Shift & View Details Modal**: Attendants can inspect the full **Shift Reconciliation Details** modal (`View details`) showing nozzle-by-nozzle meter calculations, payment breakdowns, cash handover, and recent shift money entries, then submit the shift for owner review (`Submit shift for review`), which persists to Cloud Firestore (`/stations/chatrai/shifts`) and triggers an instant owner notification.
     - **Interactive Shift Approval Requests on Overview**: `StationOverviewScreen` displays prominent `Shift Approval Request` cards and tappable `Today's Shifts` rows/cards. Tapping any shift request (or shift notification in the top bar bell) deep-links directly to that shift on `ShiftReviewScreen`.
     - **Owner Shift Approval & Correction Actions**: Owners can verify cash handover and click **Approve Shift & Handover** (marking the shift `Approved` in green across both portals) or **Request Correction** (returning the shift to `In progress` with an owner note visible on the staff Close Shift screen).
     - **Authoritative Shift Pruning**: Deleting a shift in Station Settings immediately removes it from `_allShifts`, unassigns users via `clearAssignedShift: true`, and deletes it from local `SharedPreferences` and Cloud Firestore (`/stations/chatrai/shifts`) so deleted shifts never reappear.
     - **Complete Operational & Dispenser Purge Reset**: Single-click **Clear Records** in Station Settings resets all entries, receipts, credit khata balances, notifications, shift handovers, and resets dispenser nozzle `currentTotaliserMl` to `previousAcceptedReadingMl` (`0.0 L` net sold) across both local storage and Cloud Firestore.
     - **Real-Time In-App Update Prompt & Banner + Instant Web Cache Busting**: `OwnerShell` and `StaffShell` reactively monitor `StationSettings` and `apkReleases` from Cloud Firestore, displaying a live top update banner and triggering `ForceUpdateDialog` in real time as soon as a newer version is published. `web/index.html` and `firebase.json` enforce `no-cache, no-store, must-revalidate` and automatically unregister stale service workers and clear browser `CacheStorage` when `/version.json` changes.
   - **Mobile-First Owner Operations Portal**: Architected strictly for viewports from 360px–430px up to 4K displays with >=44px touch targets.
     - **OwnerShell Mobile Architecture**: Eliminates redundant nested double AppBars, integrates leading hamburger menu via `GlobalKey<ScaffoldState>`, provides a 5-destination mobile bottom navigation bar (`Overview`, `Reports`, `Ledger`, `Receipts`, `More`) where `More` opens a tactile **More Station Controls** bottom sheet (`Shifts`, `Credit Khata`, `People & Roles`, `Pump Setup`, `Station Settings`, plus full drawer), and introduces a 1-tap swipeable category pill track.
     - **Station Overview**: Full multi-line text on all Overview stat tiles and pump subtotals (zero `...` truncation on mobile), mobile shift cards, and full-width touchable latest receipt card.
     - **Daily Report**: Responsive header wrap preventing overflow; wrapped date steppers and shift dropdowns; horizontal scrollable fuel calculation table.
     - **Receipt Inbox**: Master-detail segmented navigation (`Slips (N)` vs `Review Slip`) providing instant slip review on mobile without scrolling past 10 cards.
     - **People & Roles**: Transformed 8-column 920px table into mobile user cards with avatars, role pills, PIN indicators, and 44px+ edit/delete touch targets.
     - **Credit Khata**: Responsive balance header wrap and stacked mobile payment collection form.
     - **Pumps Setup & Shift Review**: Horizontally scrollable pump selector choice chips and mobile shift cards.
     - **Money Ledger & Settings**: Mobile-first warning banners, stacked form inputs, and responsive card layouts.

6. **Operational Governance, Dynamic Categories & Firestore Tools**:
   - **OCR Camera Restriction Setting**: Station owners/admins can disable shift staff totaliser camera scanning in settings; staff app immediately disables scanning and guides manual reporting.
   - **Dynamic Entry Categories CRUD**: Fully configurable transaction categories with add, edit, toggle, and an alert dialog confirmation before deletion.
   - **Dynamic Shift Timings CRUD & Dynamic Firestore Sync**: Full Add Shift, Edit Shift name/time range with quick preset chips, and Delete Shift with safety confirmations. Shifts dynamically update `StationSettings`, propagate across active shifts and staff user assignments, and sync in real time with Cloud Firestore.
   - **Interactive Calendar & Shift Selectors**: Functional day stepper `< Date >`, calendar date picker (`showDatePicker`), and shift dropdown across Daily Reports and Shift Reviews.
   - **People Management Filters & Session Tracking**: Real-time search by name, phone, village, and email, alongside Role/Status filters and active session logged-in status chips.
   - **Category Mapping Audit Dialog**: Replaces temporary feedback with an authoritative dialog to inspect and map uncategorized physical ledger debit entries.
   - **Editable Station Location & Forecourt Perimeter Controls**: Configurable station name, GPS latitude (°N), GPS longitude (°E), and geofence boundary radius (50m–500m) with preset chips (Chatrai Forecourt, Chatrai Bypass) and live coordinates sync to Firestore.
   - **Developer Testing Controls**: Single-click "Seed to Firestore" and "Clear / Purge Collections" buttons with safety alerts for testing operational states.

7. **Production Branding, Hardware Biometrics & Session Continuity**:
   - **Custom Petrol Dispenser Branding**: Custom high-resolution green dispenser icons generated for Android launcher mipmaps (`ic_launcher.png`), web favicon, and PWA manifests (`Icon-192`, `Icon-512`, `Icon-maskable`).
   - **Biometric Quick Login (Fingerprint & Face ID)**: Native hardware biometric authentication via `local_auth` and Android `FlutterFragmentActivity`, configurable in Station Settings.
   - **Real Camera & Gallery Photo Capture**: Direct hardware camera and album photo capture for receipt slips and baseline meter evidence using `image_picker`.
   - **Persistent Session State**: Active user logins and live user updates persist across page reloads via `SharedPreferences`.
   - **Multi-Pump Forecourt View**: Staff My Shift screen displays all station pumps (Pump 1 & Pump 2) with both nozzles, yesterday's baseline, and today's reading.
   - **Dispenser CRUD, Edit Pumps & Baseline Setup**: Full pump management with Add Pump modal, Edit Pump dialog (updating name, serial, nozzle fuel types, rates, and totalisers), pump deletion with safety confirmation, opening baseline setter, and base totaliser photo proof upload.

8. **In-App Versioning & Authoritative APK Force Update Engine (v1.0.12+13)**:
   - **In-App Version Badges**: Ubiquitous `VersionFooter` widget displays current installed version (`v1.0.12+13`) across `LoginScreen`, `StationTopBar` header, `MyShiftScreen` status row, account menu, and `OwnerShell` sidebar.
   - **Semantic Version Comparator**: `AppVersionService` accurately evaluates major, minor, patch, and build numbers against target values in Cloud Firestore (`/stations/chatrai/settings/general`).
   - **Blocking Force Update Dialog**: Displays a non-dismissible `AlertDialog` with `PopScope(canPop: false)` and `barrierDismissible: false` on Android devices whenever an older app version is detected, displaying Telugu & English prompts and opening the APK download URL via `UrlLauncherHelper`. Scoped exclusively to Android mobile devices; web sessions automatically run the latest hosted release.
   - **Web JS Interop URL Launcher & PackageInfo Bypass**: Bypasses missing web method channels entirely by using conditional imports (`web_launcher_web.dart` / `web_launcher_stub.dart`) with `dart:js` `window.open` for WhatsApp sharing and downloads, eliminating `MissingPluginException` on web while retaining native intents on mobile.
   - **Direct Firebase CDN APK Hosting**: The physical compiled Android release APK (`reya-filling-station.apk`, 88.7 MB) is hosted directly on Firebase Hosting at `/static/reya-filling-station.apk` with `Content-Type: application/vnd.android.package-archive` and `Content-Disposition: attachment; filename="reya-filling-station.apk"` headers, ensuring direct browser downloads without triggering SPA routing to the dashboard.
   - **APK Upload & Register in Firestore**: Dedicated dialog in Tab 4 to register new APK releases, update download URLs (with official Firebase Hosting CDN presets), enforce update policies, and record release audit metadata directly in Firestore (`/stations/chatrai/apkReleases/`).
   - **APK Release Deletion & 7-Day Auto Purge**: Single-item release deletion (`deleteApkRelease`) and bulk cleanup (`purgeApkReleasesOlderThan`) deleting records older than a week from Firestore and local cache, triggered automatically on screen load and on demand.
   - **Direct WhatsApp APK Share Link & Clipboard Copy**: One-touch sharing via WhatsApp (`https://wa.me/?text=...`) with pre-formatted release notes and direct download link, copy-to-clipboard, and direct browser download trigger.
   - **Cloud Releases History**: Real-time list of published Android APKs stored in Firestore with build numbers, IST publication timestamps, binary sizes, delete buttons, and instant share buttons.

9. **OCR Receipt Auto-Fill, Admin Security PIN Gate & Meter Save Validation**:
   - **On-Device Receipt OCR Pipeline**: Automatically extracts `CumVolume`, `Date`, and `Time` from IndianOil receipt slips (`FP. ID 1 & 2`, `Nozzle No1 & No2`) using Google ML Kit and regex tokenization, auto-filling forecourt fields.
   - **Instant Pump Switching**: Changing the dispenser dropdown instantly refreshes that pump's active nozzles, previous baseline readings, and resets the capture state.
   - **Action-Oriented Capture State**: Button displays "Capture Photo" with live camera/gallery picking, transitioning to "Extracting with OCR..." with progress indication.
   - **Branded Receipt Simulation**: Slip simulation card displays official branding: `Reya filling station receipt capture`.
   - **Strict Meter Save Validation Gates**:
     - Submissions without a newly captured receipt image are rejected (`Please capture a receipt photo before saving meter readings`).
     - Submissions with unchanged meter readings (`Closing == Opening`) or negative volume deltas are rejected.
     - Rejected counter entries trigger explicit error dialogs and rollback warnings.

10. **Remote Live Logging, Sentinel Alert Agent & Mobile Viewport Polish (v1.0.8+9)**:
    - **Multi-Column Real Dispenser Slip OCR**: Parser accurately resolves real IndianOil thermal slips where labels and values are printed across separate lines or columns (`Date` / `Time` / `FP. ID :3`), accented nozzle markers (`Nozzle Noló` mapped to Nozzle 1), and lookback scanning above `CumVolume:` to extract offset totaliser readings (`86106.490 L`) while strictly ignoring intermediate shift sales.
    - **Live Remote Logging & 4-Day Retention Purge**: `RemoteLoggingService` tracks screen navigation, user logins, and operational errors directly to Cloud Firestore (`/stations/chatrai/appLogs/`). Automatically purges records older than 4 days upon user login and audits failures.
    - **Sentinel Alert Agent & WhatsApp Dispatch**: `SentinelAlertAgent` monitors critical forecourt red flags (account lockout after 3 failed PIN attempts, suspended user access, geofence breaches) and immediately dispatches alerts to WhatsApp (`+919492757943`) and Firestore (`/stations/chatrai/sentinelAlerts/`).
    - **OCR Diagnostics Bug Icon Feature Flag**: Station Owners can control the visibility of the orange diagnostics icon beside "Capture Photo" via Station Settings (`Everyone`, `Owners & Managers Only`, or `Disabled`).
    - **Mobile-First Top Bar & Prominent Version Visibility**: `StationTopBar` dynamically adapts to mobile screens (`< 600px`), stacking the compact version badge under the app title, hiding bulky date badges on compact views, and displaying full version badges in the account menu and staff shift header.
   - **Clean Zero-Trust Login**: Eliminated test credential chips from the login screen; authentic entry required.
   - **Mandatory Admin Security PIN (Max 6 Digits)**: Configurable in People Management (`UserFormScreen`) for each staff member and owner; strictly verified upon sign-in.
   - **Post-Login Biometric Enrollment**: Fingerprint and Face authentication prompts now appear post-login rather than unauthenticated login screen.

10. **PhonePe Mobile Subtitle, Strict Pump Slip Validation, Filtered Dynamic Ledger & Guardian Constraints**:
   - **PhonePe Mobile Display**: 'Recorded in this shift' prominently displays the customer's 10-digit mobile number for PhonePe entries.
   - **Pump Mismatch 'Wrong pump' Gate**: When an uploaded receipt slip's serial number or FP ID does not match the active dispenser (e.g. Pump 1 slip uploaded for Pump 2), scanning is strictly rejected with a 'Wrong pump' alert dialog and fields are cleared.
   - **Direct Target Pump Navigation**: Clicking 'Scan Today' or any pump card on `MyShiftScreen` directly switches the Scan tab to the targeted pump.
   - **Dynamic Money Ledger with Filters & Pagination**: Live integer calculations from `state.entries`; interactive Date filter, Staff member filter, Subtab categorizations (`Cash`, `PhonePe`, `Card`, `Credit`, `Paid out`), and 10-item pagination with `PaginationControl`.
   - **Strict Character Constraints (Project Guardian Mandate)**: Standard text fields max 30 chars, phone numbers strictly 10 digits (`digitsOnly`), and meter readings max 15 chars enforced across all forms.

11. **Credit Khata Auto-Registration, Dynamic Collections, Real Notifications & Receipt Approvals**:
    - **Compulsory Credit Customer Selection & Auto-Registration**: When attendants select the Credit category in shift money entries, customer selection is compulsory. Attendants can select from registered credit customers or add a new customer with vehicle details. New customers are automatically enrolled in CreditCustomer with their initial outstanding balance and appear in the Owner Credit Khata portal.
    - **Overhauled Forecourt Collections & Settlement**: Money ledger cash card updated to display total collections received (Cash + PhonePe/UPI + Card), detailed breakdown by payment mode, credit sales, expenses, cash given to owner, physical cash in hand, and net forecourt balance.
    - **Removal of Legacy 'Category to Confirm'**: Discarded all legacy 'Category to confirm' badges and notes across Money Ledger and Daily Station Reports.
    - **Real Dynamic Event Notifications**: Eliminated static dummy notifications; dynamically generates notifications for credit entries, money transactions, receipt scans, and shift change requests.
    - **Accurate Last Recorded Timestamp**: My Shift screen displays the actual timestamp of the latest scanned receipt or displays Awaiting today\'s scan instead of misleading live clock updates.
    - **Dynamically Computed Daily Reports**: All Daily Station Report metric cards (Recorded Sales, PhonePe + Card, Credit, Cash Given to Owner) and fuel calculations are dynamically derived from actual shift entries and pump readings.
    - **Receipt Approval Workflow**: Owner-uploaded receipts are automatically marked Approved by Owner. Attendant-scanned receipts default to Pending review with explicit Approve receipt (updates pump nozzles) and Reject buttons.
    - **Interactive Receipt Image Viewer**: Clicking Open original image launches a full-resolution interactive viewer with zoom and pan to inspect receipt slips.

12. **Money Entries History, Edit with Confirmation, Infinite Scroll & Zero-Volume Reports Fix**:
    - **Comprehensive Money Entries History**: Shows all recorded entries with IST-formatted business date and 12-hour timestamp on every transaction card, ordered latest first.
    - **Infinite Scroll & Load More Navigation**: Seamless progressive scrolling loaded in batches of 15 items with manual 'Load More' fallback, accommodating daily shifts with 30-40+ entries without UI clutter.
    - **Two-Step Entry Edit Modal & Confirmation Dialog**: Shift staff can modify transaction category, amount, reference note, and PhonePe mobile number, guarded by an explicit confirmation dialog before committing updates to Firestore.
    - **Keyboard Enter Key Navigation on Login Screen**: Tapping Enter in the email/phone field automatically moves focus to the PIN input, and tapping Enter in the PIN field automatically submits the credentials for immediate sign-in.
    - **Daily Reports Zero-Volume Crash Fix**: Implemented test volume clamping (`effectiveTestVolume <= grossVolumeMl`) in `ReconciliationService` and error resilience in `StationStateProvider.sampleShiftReport` to completely eliminate grey screen crashes when opening daily reports on idle pumps.

13. **Receipt OCR Below-Line CumVolume Extraction & Intermediate Shift2Sale Exclusion (v1.0.6+7)**:
    - **Pre-Scan Masking of Shift Counters**: Pre-scans and strictly masks all intermediate counters declared as `Shift1Sale`, `Shift1Vol`, `Shift2Sale`, `Shift2Vol`, `Shift3Sale`, `ShDaySale`, `ShDayVol`, `ShMTHSale`, `ShMTHVol` and their wrapped numeric lines, preventing shift sales (e.g. `20,951.850`) from ever being chosen as CumVolume.
    - **Reliable Below-Line Extraction**: Reliably locates the cumulative dispensing totaliser printed directly on the lines below the `CumVolume:` label.
    - **Optical Artifact Resilience**: Recognizes thermal print optical ambiguities (`CurnVolume`, `CumVo1`, `CunVol`) without falling into generic fallback mode.
    - **Same-Line CumSale Token Splitting**: Handles tight thermal line spacing where `171054.450 CumSale : 18989346.490` are printed on the same line without aborting volume extraction.
    - **Bottom-Up Safe Section Fallback**: When anchor keywords are damaged, scans from the bottom of the section upwards, strictly bypassing all intermediate shift counters.

14. **Staff Receipt Slip Image Preservation & Owner Full-Screen Inspector Base64 Fix (v1.0.12+13)**:
    - **Compressed In-Memory Base64 Data URI**: In `ScanReceiptScreen`, camera-captured slips are compressed (`maxWidth: 1280`, `maxHeight: 1280`, `imageQuality: 75`) to 80–150 KB and serialized as `data:image/jpeg;base64,...` data URIs, fitting securely into Firestore documents without external storage dependencies.
    - **Direct Owner Image Inspector**: `ReceiptInboxScreen` decodes Base64 data URIs directly via `Image.memory` inside `InteractiveViewer`, providing full zoom and pan into the exact receipt slip uploaded by staff attendants.
    - **Asset Fallback Cleanup**: Replaced all hardcoded references to the app mockup tabs infographic (`media_1791616403909.jpg`) with the authoritative IndianOil dispenser receipt slip asset (`media_1791634198035.png`).
---

## 📐 Golden Worked Fixture (Reconciliation Proof)

| Parameter | Petrol (Pump 1 Nozzle 1) | Diesel (Pump 1 Nozzle 2) | Combined / Total |
| :--- | :--- | :--- | :--- |
| **Opening Reading** | 168,676.720 L | 273,287.210 L | — |
| **Closing Reading** | 168,971.850 L | 273,901.000 L | — |
| **Gross Volume** | 295.130 L | 613.790 L | 908.920 L |
| **Approved 5L Test** | 5.000 L | 5.000 L | 10.000 L |
| **Billable Volume** | 290.130 L | 608.790 L | 898.920 L |
| **Fuel Rate** | ₹117.52 / L | ₹105.21 / L | — |
| **Calculated Fuel Sales** | ₹34,096.08 | ₹64,050.80 | **₹98,146.88** |
| **Payments: PhonePe** | — | — | ₹33,067.00 |
| **Payments: Card (`swiping`)** | — | — | ₹4,532.00 |
| **Payments: Credit (`N.C`)** | — | — | ₹30,000.00 |
| **Payments: Cash Sales** | — | — | **₹30,547.00** |
| **Cash Debits (Bus Bill)** | — | — | ₹17,373.00 |
| **Food Expense (`curries`)**| — | — | ₹100.00 |
| **Given to Owner** | — | — | **₹13,074.00** |
| **Cash Variance** | — | — | **₹0.00** |

---

## 🚀 Running & Verification Instructions

### 1. Prerequisites
- **Flutter SDK**: `>= 3.41.9`
- **Dart SDK**: `>= 3.11.5`
- **Firebase CLI**: `>= 15.18.0`

### 2. Run Automated Test Suite (26 Tests)
```bash
flutter test
```
Validates:
- `test/reconciliation_test.dart` (Exact integer paise/mL, fuel sales formulas, zero cash variance, boundary errors)
- `test/ocr_parser_test.dart` (IndianOil hierarchical parsing, SHA-256 deduplication, date validation)
- `test/ocr_and_security_pin_test.dart` (CumVolume/Date/Time extraction, Security PIN authentication gate, empty/invalid PIN rejection)
- `test/app_version_test.dart` (Semantic version comparator, update policy, build number precedence)
- `test/location_boundary_test.dart` (150m uncertainty geofence logic, GPS accuracy bounds)
- `test/widget_test.dart` (Zero-Trust login gate, StaffShell forecourt controls, OwnerShell operations portal)

### 3. Build & Run Responsive Web Distribution
```bash
flutter build web --base-href "/"
```
Compiled bundle generated at `D:\reya-filling-station\build\web`.
To run locally:
```bash
flutter run -d chrome
```

### 4. Build Installable Android Release APK
```bash
flutter build apk --release
```
Production release Android APK generated at:
`D:\reya-filling-station\build\app\outputs\flutter-apk\app-release.apk`

Debug testing APK generated at:
`D:\reya-filling-station\build\app\outputs\flutter-apk\app-debug.apk`

---

## 🛡️ Live Verification & Security Controls
1. **Zero Mock Entries**: No hardcoded transactions; all entries are dynamically generated by staff or fetched from Firestore.
2. **Auto-Updated Pump Readings**: Staff receipt scans immediately increment the matching pump nozzle cumulative meters in state and `/stations/chatrai/pumps/{id}`.
3. **Owner Base Totaliser Proof**: Authoritative reference proof upload in Owner settings to eradicate wrong updates.
4. **Dynamic IST Formatting**: All dates and times format dynamically to Asia/Kolkata (IST) without legacy fixtures.

## 📁 Project Structure

```
D:\reya-filling-station/
├── lib/
│   ├── main.dart                        # Multi-provider app host with dual-mode switch
│   ├── core/
│   │   ├── constants/colors.dart        # Sunlight contrast forecourt palette
│   │   ├── constants/dimensions.dart    # 56-64px touch target standards
│   │   └── formatting/                  # Currency (paise), Volume (mL), Date (IST)
│   ├── l10n/app_strings.dart            # Telugu (తెలుగు) & English localization
│   ├── models/                          # UserProfile, Pump, Shift, ReceiptScan, CreditCustomer
│   ├── services/
│   │   ├── reconciliation_service.dart  # Fixed-precision calculation engine
│   │   ├── ocr_parser_service.dart      # Hierarchical IndianOil receipt parser
│   │   ├── location_service.dart        # 150m uncertainty-aware geofence
│   │   └── station_state_provider.dart  # Central reactive state & simulation fixtures
│   └── ui/
│       ├── common/station_top_bar.dart  # Language switch, notifications, role switcher
│       ├── staff/                       # Forecourt Mobile Shell (4 bottom tabs)
│       └── owner/                       # Owner Operations Portal (9 desktop views)
├── test/                                # 14 golden automated test cases
├── firestore.rules                      # Production zero-trust security rules
├── storage.rules                        # Cloud Storage receipt upload rules
├── firebase.json                        # Firebase Hosting, Firestore, Storage & Emulators
├── config/roadmap_phases.json           # Canonical Project Guardian roadmap
└── progress.md                          # Progress log with recent IST changes
```


## Web startup loading experience

The initial HTML shows a local vehicle-refueling-to-dashboard animated GIF while Flutter downloads
and Firebase initializes, then removes it on Flutter's first rendered frame. It does
not wait for every live Firestore subscription; station data continues syncing through
the existing provider. Reduced-motion users see a still image, and slow startup shows
a Reload action after 20 seconds. Receipt OCR/HEIC libraries now load on the first scan,
with shared download promises and retry after a download failure. No new dependencies.
Source assets: `web/fuel-to-dashboard.gif` and `web/fuel-to-dashboard-still.png`.
Build with `flutter build web --release`; publish through the existing Firebase flow.
The GIF was created and previewed before website implementation changes.

The loader attendant refuels a compact car; rupee coins then flow into the dashboard. The earlier fuel can illustration has been replaced in both GIF and reduced-motion PNG.


## Manager and shift-staff footer navigation

APK and web share `StaffShell`: default shift staff see My Shift, Scan, Entries and
Close; default managers also see Users. Role and per-user screen permissions still
control which destinations are shown. A single permitted screen now retains its
selected footer icon and label (64px target), including the manager Users Only
preset; it no longer removes the entire footer. To restore all authorized default
destinations, an Owner/Admin can reset role defaults and remove per-user overrides.
The fix does not automatically expand anyone's permissions.
Mobile shift actions wrap, Users filters fit phone widths, and pagination uses
compact controls below 650px with 44px buttons. Regression checks:
`flutter test test/staff_footer_navigation_test.dart`.


## Release v1.0.30+31

This release includes the vehicle-refueling web startup GIF, lazy receipt-tool
downloads, persistent manager/staff single-screen footer, and mobile layout fixes.
Version/build are aligned in pubspec, AppVersionService, StationSettings, the
bootstrap cache key and generated version.json. Build commands:
`flutter build apk --release --target-platform android-arm,android-arm64` and
`flutter build web --release`.
Copy the release APK into `build/web/static/reya-filling-station.bin` and its
versioned `.apk` filename before `firebase deploy --only hosting`.
Firebase ignores `.apk` files; APK download URLs rewrite to the hosted `.bin`.
Verify APK SHA-256 and package version, then patch only the release fields in
Firestore settings and register the APK release. Preserve the existing signing
configuration, force-update policy and all other station settings. Do not run
the full seeder to publish an update.
Website: https://reya-filling-station-chatrai.web.app
APK: https://reya-filling-station-chatrai.web.app/static/reya-filling-station-v1.0.30+31.apk

Deployment verified on 12 Oct 2026 10:19 am IST: website and APK v1.0.30+31 are live. The APK is 71.0 MiB (74,493,293 bytes); signing matches previous installations. All 103 Flutter tests passed.


## Focused Owner Overview — v1.0.31+32

Owner Overview now opens a compact **Summary** with four key totals and shortcuts.
A fixed, horizontally scrollable section track separates **Operations** (meter
readings, shifts, receipts and cash handovers), **AI Insights** (sales trends,
payment mix and growth suggestions), **Team** (user approvals, app versions and
shift locations), and **Reports** (the existing daily report with date/shift filters).
Only the selected view is built; analytics no longer runs during Summary hydration.
AI remains Owner/Admin only; Team and Reports honor their existing screen permissions.
Long overview and handover collections use ten-item pagination. Mobile report rows
wrap and chart legends stack when space is limited. No new dependencies or APIs.
Regression checks: `flutter test test/owner_overview_sections_test.dart`.
Release builds use `flutter build web --release --target lib/main.dart` and
`flutter build apk --release --target-platform android-arm,android-arm64`.

Released v1.0.31+32 on 12 Oct 2026 10:40 am IST. Website: https://reya-filling-station-chatrai.web.app ; APK: https://reya-filling-station-chatrai.web.app/static/reya-filling-station-v1.0.31+32.apk . All 108 tests and Project Guardian passed.


## Footer-only Owner Navigation — v1.0.32+33

The owner portal uses one footer navigation on phones, tablets and desktop:
Overview, Reports, Ledger, Receipts and More. The duplicated top category row,
hamburger drawer and desktop sidebar have been removed. More still opens Shifts,
Credit, Users, Pumps and Settings in a scrollable sheet; its obsolete Full Drawer
shortcut is removed. The RFS header, language, notifications, profile controls and
Overview's Summary/Operations/AI Insights/Team/Reports tabs remain available.
Desktop content is capped at 1440px and footer controls at 960px. Mobile role
actions wrap with 44px targets. No new dependencies, APIs or permission changes.
Regression checks: `flutter test test/owner_footer_only_navigation_test.dart`.

Footer-only navigation released as v1.0.32+33 on 12 Oct 2026 11:00 am IST. Website: https://reya-filling-station-chatrai.web.app ; APK: https://reya-filling-station-chatrai.web.app/static/reya-filling-station-v1.0.32+33.apk . All 111 tests and Project Guardian passed.


## Signed silent updates (integration; migration pending)

Added `shorebird_code_push` 2.0.7 and injectable Provider metadata diagnostics in
Owner Settings → App Version. Shorebird downloads compatible signed Dart changes
in the background and applies them on a later cold launch after users optionally
install the first Shorebird base APK. Diagnostics never block initial rendering,
restart shifts, or write private patch telemetry. AppVersionService remains APK-only.
Production remains v1.0.32+33; the planned migration is v1.0.33+34.

Android releases now require the owner-authenticated AIPCC Shorebird builder,
Flutter 3.41.9/Dart 3.11.5, the original certificate, signed keys and
`--no-tree-shake-icons`. Do not use older vanilla release instructions above for
OTA-enabled bases. Staging QA must precede stable promotion; no per-patch approval
or APK announcement is required after the established QA gate. Native/plugin,
asset, permissions or SDK changes require a new base.

Web deployments use `python scripts/build_web_release.py`, then the existing
Firebase Hosting deploy. `web_revision` refreshes caches without APK version bumps.
Migration publication uses `scripts/publish_reya_migration.cjs` only after signature,
version and public hash verification, and sets `forceUpdate:false`.
Shorebird login/init, a designated Android phone and physical OTA/rollback checks
are pending. The local key backup needs an encrypted off-device copy before rollout.
See [rollout specification](docs/specs/silent-updates.md) and
[architecture decision](docs/decisions/adr-002-signed-silent-updates.md).
Validation: 115 Flutter tests; web release build successful. No production change.


## Local Shorebird migration APK — v1.0.33+34

Generated Shorebird-enabled migration APK v1.0.33+34 using the user-owned free account, pinned Flutter 3.41.9/Dart 3.11.5, original application ID/certificate, embedded patch public key and full bundled icons. Local APK hash: 86925739cb09250b55076cf66f36fd00fd8d40b3ac9e7aecf0b23237c99399fe. 115 Flutter tests and 21 release API tests pass. Excluded generated Android SDK paths from source-provenance comparisons while retaining native-source checks. APK is ready for device installation/testing; no phone connected, no Firebase deployment or production update announcement.

Install the migration APK over the current APK without uninstalling. Subsequent signed Dart patches can download silently and apply on a cold launch; actual device validation remains pending. The release service excludes android/local.properties because Flutter regenerates SDK paths and build metadata. Native source, dependency, asset and certificate checks remain enforced.


## Mandatory migration publication — v1.0.33+34

Published website and signed Shorebird migration APK v1.0.33+34 to Firebase Hosting. Verified the public APK SHA256 86925739cb09250b55076cf66f36fd00fd8d40b3ac9e7aecf0b23237c99399fe matches the identity-verified base. At the user's request because station APK use has not begun, published latestVersion=1.0.33, latestBuildNumber=34 and forceUpdate=true, preserving unrelated settings. Migration publisher now supports explicit --force while remaining optional by default. Previous v1.0.32+33 installations receive the mandatory update policy; Android installation still requires user confirmation. Physical-device OTA download/activation QA remains pending; no OTA patch was promoted.


## Current-data insights and separate administration screens (staged Dart change)

Purge now removes saved/cloud cash handovers as well as other operational records.
AI Insights uses actual period records and rate segments; missing days contribute
zero. Empty periods show **Nothing to analyse**. Fixed growth, forecast savings,
invented payment mixes and customer-name suggestions have been removed.
Users, Roles and Permissions are separate screens. Desktop widths from 1024px
use a side menu; smaller views keep the footer. Restricted roles retain only their
existing permitted destinations. Record lists use ten-item pagination.

Target Shorebird base: **v1.0.33+34**, with no APK version bump or new assets/plugins.
125 Flutter tests and 20 release-service tests pass. Android staging verification
is pending; these changes are not yet on the public website or stable patch track.
See [implementation and test steps](docs/specs/current-data-insights-and-admin-navigation.md).

Signed **Patch 1** for base **v1.0.33+34** is uploaded to **staging**. Its source/artifact metadata and signing-key fingerprint are retained outside Git. Device verification is pending; stable delivery and the public website are unchanged.


## Owner-authorized deployment without device testing

The owner chose to deploy signed Patch 1 for v1.0.33+34 without a physical Android test device. Promotion now accepts exact-patch protected local authorization evidence with device testing explicitly marked skipped. Signing, artifact identity, free-account and native/asset checks remain enforced. 125 Flutter tests, 22 release checks and the web build pass; no physical-device test is claimed.

Deployed: **Patch 1 on stable**, base **v1.0.33+34**, website revision **20261012153722-f54e05abc5e17720** at https://reya-filling-station-chatrai.web.app . Physical-device QA was skipped at the owner's request. Live startup/code/hash checks pass, and the original migration APK/update policy are preserved. Migration APK users receive the signed patch through normal background download and next cold-launch activation.

Roles and screen access are managed exclusively on the dedicated **Roles** and **Permissions** screens. Settings contains station, scanner, shift, database and release configuration without a duplicate role editor.

Settings cleanup is published as stable **Patch 2** on base **v1.0.33+34**, and website revision **20261012165537-7e7bac6d42d2f5c3**. Background download and subsequent cold launch apply the patch. Physical-device testing was skipped at the owner's request.

## Purge and APK retention (12 Oct 2026)

Firebase returned HTTP 429 Quota exceeded for older APK record deletion; 17 older release records and four cloud handovers remain. Local handover tombstones prevent failed cloud deletes or stale caches from restoring purged activity. Purge reads server-only and reports incomplete cloud deletion. Older APK files removed and links redirect to current v1.0.33+34; UI lists current/newer releases only. Tombstones are local to the device that invokes purge; other devices require successful cloud deletion. No live financial records were deleted by this maintenance change.

Published signed stable Patch 3 for base v1.0.33+34 and website revision 20261012171506-81291e1b070e297f. Removed six retired public APK files; older version links redirect to the current APK and retired release entries are hidden. Purge stores local handover tombstones, uses server-only deletion reads and shows incomplete cloud deletion in red. 126 Flutter tests including stale-cache resurrection regression and 22 release checks passed; published revision/code/current APK hashes and older-link redirects verified. Firebase HTTP 429 Quota exceeded blocked deletion of 17 older cloud release records; four cloud handovers remain until the owner retries purge successfully. Physical-device testing skipped under standing owner authorization. No live financial records were deleted by maintenance.
