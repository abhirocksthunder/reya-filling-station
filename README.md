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

2. **Hardened IndianOil Forecourt OCR Pipeline & Strict Validation Gate**:
   - Automatically parses IndianOil dispenser printout slips (`FP. ID`, `Pump SNo`, `Date: dd/MM/yyyy`, `Time: HH:mm:ss`).
   - **Multi-Pass Parser**: Normalizes line tokens, fixes optical ambiguities (`O`/`o` -> `0`, `l`/`I` -> `1`, faint decimal points), handles thermal receipt line breaks where `CumVolume:` is followed by numeric value on subsequent lines, and strips stray pen marks (e.g. `/ 274487.190`).
   - **Strict Intermediate Counter & Sales Exclusion**: Explicitly ignores intermediate counters (`Shif1Sale`, `Shif1Vol`, `Shif2Sale`, `Shif2Vol`, `Shif3Sale`, `Shif3Vol`, `ShDaySale`, `ShDayVol`, `ShMTHSale`, `ShMTHVol`) and forecourt sales rupees (`CumSale`), isolating only cumulative dispensing totalisers (`10,000` to `9,999,999.999 L`).
   - **In-Browser Tesseract.js OCR Engine**: Enables real client-side OCR directly in Flutter Web using Tesseract.js (v5) with canvas adaptive binarization, eliminating platform dependencies and eradicating silent mock fallbacks.
   - **Strict Forecourt Gates**: Enforces monotonic counter continuity (`Closing >= Opening`), prevents silent mock fallback on mobile captures, and flags mismatches with explicit `Wrong pump` dialogs.

3. **Exact Integer Paise & Millilitres Calculations**:
   - Zero floating-point drift across platforms. Stored as integer paise (`₹98,146.88` = `9814688` paise) and integer millilitres (`168,676.720 L` = `168676720` mL).
   - Half-up rounding per nozzle line.
   - Approved calibration test volume deduction (e.g. 5.000 L) before billable fuel value multiplication.

4. **Zero-Trust Security & Station Scoping**:
   - Granular Firestore security rules with commit-time membership validation (`owner`, `manager`, `shiftStaff`).
   - Clients cannot forge accepted readings; immutable reading history and latest pointers are strictly backend-managed.
   - 150m uncertainty-aware geofence boundary calculation (`Distance + Accuracy <= 150m`).
   - Real-time Firestore synchronization for members, entries, and scan attempts.

5. **Complete Dual-Experience Shell**:
   - **Staff Forecourt Shell**: My Shift, Scan Receipt, Money Entries, Close Shift.
   - **Owner Operations Portal**: Station Overview, Receipt Inbox, Shift Reviews, Daily Money Ledger, Credit Khata, People & Roles, Pumps Setup, Station Settings, and Daily Station Reports.

6. **Operational Governance, Dynamic Categories & Firestore Tools**:
   - **OCR Camera Restriction Setting**: Station owners/admins can disable shift staff totaliser camera scanning in settings; staff app immediately disables scanning and guides manual reporting.
   - **Dynamic Entry Categories CRUD**: Fully configurable transaction categories with add, edit, toggle, and an alert dialog confirmation before deletion.
   - **Shift Timings & Approval Flow**: Configurable morning, evening, and night time ranges by manager; shift staff can request timing changes upon login, requiring manager/owner approval.
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

8. **In-App Versioning & Authoritative APK Force Update Engine**:
   - **In-App Version Badges**: Ubiquitous `VersionFooter` widget (modeled on `restaurant_pos`) displays current installed version (`v1.0.4+5`) across `LoginScreen`, `StationTopBar` header, and `OwnerShell` sidebar.
   - **Semantic Version Comparator**: `AppVersionService` accurately evaluates major, minor, patch, and build numbers against target values in Cloud Firestore (`/stations/chatrai/settings/general`).
   - **Blocking Force Update Dialog**: Displays a non-dismissible `AlertDialog` with `PopScope(canPop: false)` and `barrierDismissible: false` whenever an older app version is detected, displaying Telugu & English prompts and opening the APK download URL via `url_launcher`.
   - **Owner APK Distribution Console**: Dedicated Tab 4 (*App Version & APK Releases*) in `StationSettingsScreen` allowing owners to set target version, build number, APK download link, force update switch, release notes, and preview the update dialog.

9. **OCR Receipt Auto-Fill, Admin Security PIN Gate & Meter Save Validation**:
   - **On-Device Receipt OCR Pipeline**: Automatically extracts `CumVolume`, `Date`, and `Time` from IndianOil receipt slips (`FP. ID 1 & 2`, `Nozzle No1 & No2`) using Google ML Kit and regex tokenization, auto-filling forecourt fields.
   - **Instant Pump Switching**: Changing the dispenser dropdown instantly refreshes that pump's active nozzles, previous baseline readings, and resets the capture state.
   - **Action-Oriented Capture State**: Button displays "Capture Photo" with live camera/gallery picking, transitioning to "Extracting with OCR..." with progress indication.
   - **Branded Receipt Simulation**: Slip simulation card displays official branding: `Reya filling station receipt capture`.
   - **Strict Meter Save Validation Gates**:
     - Submissions without a newly captured receipt image are rejected (`Please capture a receipt photo before saving meter readings`).
     - Submissions with unchanged meter readings (`Closing == Opening`) or negative volume deltas are rejected.
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
