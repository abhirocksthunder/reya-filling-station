# Reya Filling Station (రేయా ఫిల్లింగ్ స్టేషన్)

[![Flutter](https://img.shields.io/badge/Flutter-3.41.9-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.11.5-0175C2?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-reya--filling--station--chatrai-FFCA28?logo=firebase)](https://console.firebase.google.com)
[![Project Guardian](https://img.shields.io/badge/Project_Guardian-PASS-success)](https://github.com)

A rural-first petrol filling station management, meter reading capture, and financial reconciliation application architected for forecourt operations in Chatrai, Andhra Pradesh. Built with Flutter cross-platform (Android APK & Responsive Web), backed by Google Cloud Firestore (`reya-filling-station-chatrai`).

---

## 🌟 Key Capabilities

1. **Rural-First forecourt Usability**:
   - High-contrast color palette (`#0C4A4D` Deep Forest Teal & `#E65100` Action Orange) readable in blinding direct sunlight.
   - Large 56px–64px tactile touch targets for one-handed thumb interaction and forecourt gloves.
   - Instant dual-language toggle (**Telugu `తెలుగు`** & **English `EN`**).
   - Replaced accounting abstractions with physical notebook concepts: *"Cash with me"*, *"Cash given to owner"*, *"ph.p"*, *"swiping"*, *"N.C"*, and *"curries/food"*.

2. **Hierarchical IndianOil OCR Pipeline**:
   - Automatically parses IndianOil dispenser printout slips (`FP. ID`, `Pump SNo`, `Date: dd/MM/yyyy`, `Time: HH:mm:ss`).
   - Hierarchically locates `Nozzle NoX`, then extracts its immediate `CumVolume`. Discards intermediate counters (`Shif1Sale`, `ShDayVol`, `CumSale`).
   - Enforces monotonic counter continuity (`Closing >= Opening`) and SHA-256 fingerprint deduplication.
   - Automatic business date validation against Asian/Kolkata station time, flagging previous-day slips.

3. **Exact Integer Paise & Millilitres Calculations**:
   - Zero floating-point drift across platforms. Stored as integer paise (`₹98,146.88` = `9814688` paise) and integer millilitres (`168,676.720 L` = `168676720` mL).
   - Half-up rounding per nozzle line.
   - Approved calibration test volume deduction (e.g. 5.000 L) before billable fuel value multiplication.

4. **Zero-Trust Security & Station Scoping**:
   - Granular Firestore security rules with commit-time membership validation (`owner`, `manager`, `shiftStaff`).
   - Clients cannot forge accepted readings; immutable reading history and latest pointers are strictly backend-managed.
   - 150m uncertainty-aware geofence boundary calculation (`Distance + Accuracy <= 150m`).

5. **Complete Dual-Experience Shell**:
   - **Staff Forecourt Shell**: My Shift, Scan Receipt, Money Entries, Close Shift.
   - **Owner Operations Portal**: Station Overview, Receipt Inbox, Shift Reviews, Daily Money Ledger, Credit Khata (Sri Sai Travels, School Bus), People & Roles, Pumps Setup, Station Settings, and Daily Station Reports.

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

### 2. Run Automated Test Suite (14 Tests)
```bash
flutter test
```
Validates:
- `test/reconciliation_test.dart` (Exact integer paise/mL, fuel sales formulas, zero cash variance, boundary errors)
- `test/ocr_parser_test.dart` (IndianOil hierarchical parsing, SHA-256 deduplication, date validation)
- `test/location_boundary_test.dart` (150m uncertainty geofence logic, GPS accuracy bounds)
- `test/widget_test.dart` (Forecourt UI rendering)

### 3. Build & Run Responsive Web Distribution
```bash
flutter build web --base-href "/"
```
Compiled bundle generated at `D:\reya-filling-station\build\web`.
To run locally:
```bash
flutter run -d chrome
```

### 4. Build Installable Android APK
```bash
flutter build apk --debug
```
Installable Android APK generated at:
`D:\reya-filling-station\build\app\outputs\flutter-apk\app-debug.apk`

---

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
