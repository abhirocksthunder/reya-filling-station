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
