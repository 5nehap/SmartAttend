# SmartAttend – Smart QR-Based Attendance Management

## Project Overview

SmartAttend is a Flutter-based mobile attendance management application that uses QR codes for seamless, secure, and location-aware attendance tracking. The app supports two roles — **Admin** and **Employee** — with an offline-first architecture backed by SQLite and a clean BLoC state management pattern.

---

## Features

- **Two roles:** Admin and Employee, each with tailored dashboards
- **QR code attendance:** Each QR session expires in exactly **60 seconds**
- **Real-time GPS location capture** at check-in and check-out
- **SQLite local database** — the single source of truth for all data
- **BLoC state management** — strict separation of UI and business logic
- **Session persistence** via SharedPreferences (auto-login on relaunch)
- **Complete attendance history** per employee
- **Admin records:** view all attendance records, search employees, view employee detail with full history

---

## Technology Stack

| Package | Version | Purpose |
|---|---|---|
| Flutter | 3.41.2 | Cross-platform UI framework |
| Dart | 3.11.0 | Programming language |
| flutter_bloc | ^8.1.6 | BLoC-only state management |
| sqflite | ^2.4.1 | Local SQLite database |
| dio | ^5.8.0+1 | REST API client (mock, non-blocking) |
| qr_flutter | ^4.1.0 | QR code generation |
| mobile_scanner | ^6.0.4 | QR code scanning |
| geolocator | ^13.0.2 | GPS coordinates |
| shared_preferences | ^2.3.5 | Session persistence |
| intl | ^0.20.2 | Date/time formatting |

---

## Architecture Overview

SmartAttend uses the **BLoC (Business Logic Component)** pattern throughout. All state changes are driven by **Events → BLoC → States**; `setState` is never used for business logic.

**Four BLoCs:**
- `AuthBloc` — authentication and session management
- `AttendanceBloc` — check-in, check-out, attendance history
- `QRBloc` — QR generation, 60-second countdown, validation, expiry
- `AdminBloc` — dashboard summary, employee list, employee detail

**SQLite is the source of truth.** Dio (REST API) calls are fire-and-forget; all failures are caught silently and never block the user flow.

---

## Project Folder Structure

```
lib/
├── core/
│   ├── constants/        # AppConstants (API URL, timeouts, durations)
│   ├── database/         # DatabaseHelper (SQLite — 3 tables, seed data)
│   ├── di/               # AppDependencies (dependency injection wiring)
│   ├── services/         # SessionService, LocationService, ApiService (Dio)
│   └── theme/            # AppColors, AppTheme
├── data/
│   ├── models/           # EmployeeModel, AttendanceModel, QRSessionModel
│   └── repositories/     # AuthRepository, AttendanceRepository,
│                         # QRRepository, AdminRepository
├── features/
│   ├── auth/             # AuthBloc + SplashScreen, LoginScreen
│   ├── attendance/       # AttendanceBloc + EmployeeDashboard,
│   │                     # AttendanceHistory
│   ├── qr/               # QRBloc + QRGenerator, QRScanner,
│   │                     # _ScannerResultSheet
│   └── admin/            # AdminBloc + AdminDashboard, EmployeeRecords,
│                         # AdminAttendanceRecords, EmployeeDetails
└── shared/widgets/       # AppCard, DashboardWidgets, AppSnackbar,
                          # AppButton, LoadingView
```

---

## SQLite Database Design

Three tables are created by `DatabaseHelper`:

### `employees`
| Column | Type | Notes |
|---|---|---|
| id | TEXT | Primary key (e.g. EMP001) |
| name | TEXT | Full name |
| email | TEXT | Unique login email |
| password | TEXT | Stored plain-text (demo only) |
| role | TEXT | `admin` or `employee` |
| department | TEXT | Department name |
| joinDate | TEXT | ISO 8601 date |

### `attendance`
| Column | Type | Notes |
|---|---|---|
| id | INTEGER | Auto-increment PK |
| employeeId | TEXT | FK → employees.id |
| date | TEXT | ISO 8601 date |
| checkInTime | TEXT | ISO 8601 datetime (nullable) |
| checkOutTime | TEXT | ISO 8601 datetime (nullable) |
| checkInLatitude | REAL | GPS lat at check-in (nullable) |
| checkInLongitude | REAL | GPS lng at check-in (nullable) |
| checkOutLatitude | REAL | GPS lat at check-out (nullable) |
| checkOutLongitude | REAL | GPS lng at check-out (nullable) |
| status | TEXT | `present`, `checked-out`, etc. |
| UNIQUE | — | `(employeeId, date)` prevents duplicates |

### `qr_sessions`
| Column | Type | Notes |
|---|---|---|
| id | TEXT | UUID session ID |
| token | TEXT | 64-char hex (256-bit random) |
| createdAt | TEXT | ISO 8601 datetime |
| expiresAt | TEXT | createdAt + 60 seconds |
| isUsed | INTEGER | 0 = valid, 1 = used/expired |

---

## BLoC Architecture

### AuthBloc
Handles login (`AuthLoginRequested`), logout (`AuthLogoutRequested`), and session restore on cold start (`AuthSessionCheckRequested`). Reads/writes session via `SessionService` (SharedPreferences). On success emits `AuthAuthenticated`; on failure emits `AuthFailure`.

### AttendanceBloc
Handles check-in and check-out triggered by QR scan (`AttendanceMarkFromQRRequested`), and loads attendance history (`AttendanceHistoryRequested`). Delegates to `AttendanceRepository` which writes to SQLite and fires a silent Dio call.

### QRBloc
Generates a QR session (`QRGenerateRequested`) with a cryptographically random 64-hex-char token saved to SQLite. Runs a `Timer.periodic` countdown (`QRCountdownUpdated`) from 60 to 0 seconds, then emits `QRExpired` (`QRExpireRequested`). Validates an employee scan (`QRValidateRequested`) by checking token match and expiry in SQLite, then marks the session used.

### AdminBloc
Loads dashboard summary stats (`AdminDashboardRequested`), the full employee list with today's attendance status (`AdminEmployeeStatusLoadRequested`), and individual employee detail with full history (`AdminEmployeeDetailRequested`).

---

## QR Generation and Validation Workflow

```
Admin taps "Generate QR"
        │
        ▼
QRBloc generates 64-char hex token + sessionId (UUID)
Saves QRSessionModel to SQLite (expiresAt = now + 60s)
Emits QRSessionActive → QRGeneratorScreen shows QR image
        │
        ▼
60-second Timer.periodic countdown
        │
   Timer hits 0 → QRBloc marks session expired in SQLite
        │
        ▼
Employee scans QR with mobile_scanner
Payload JSON: { sessionId, createdAt, expiresAt, token }
        │
        ▼
QRBloc.QRValidateRequested:
  1. Load QRSessionModel from SQLite by sessionId
  2. Check isUsed == false
  3. Check expiresAt > DateTime.now()
  4. Compare token (constant-time equality)
  5. Mark session as used in SQLite
  6. Dispatch AttendanceMarkFromQRRequested to AttendanceBloc
        │
        ▼
AttendanceBloc writes check-in or check-out to SQLite
Dio call fires (always fails silently)
```

> **⚠️ Note:** QR validation is a **local mock implementation**. In production, the token should be validated server-side via a secure backend endpoint (e.g. `POST /validate-qr`).

---

## Employee Attendance Workflow

1. **Login** → SplashScreen restores session or redirects to LoginScreen
2. **Employee Dashboard** shows today's check-in/check-out status
3. **Tap "Scan QR Code"** → opens QRScannerScreen (requests camera)
4. **Scan admin's QR** → check-in recorded in SQLite with GPS coords
5. **Dashboard updates** to show check-in time
6. **Tap "Scan QR Code" again** (admin must generate a new QR)
7. **Scan QR** → check-out recorded in SQLite with GPS coords
8. **Tap "Attendance History"** → full history list displayed

> GPS is captured at both check-in and check-out. If GPS is unavailable (permissions denied, timeout, or no signal), attendance **still records** without coordinates.

---

## Admin Features

| Feature | Description |
|---|---|
| Dashboard | Summary stats: total employees, present today, absent today |
| Generate QR | Creates a 60-second QR session for employees to scan |
| Attendance Records | Full list of all employees with today's attendance status; searchable |
| Employee Details | Individual employee profile with complete attendance history |

---

## GPS Integration

`LocationService` wraps `geolocator.getCurrentPosition()` with a timeout. GPS is **non-blocking**:
- If GPS is unavailable, permissions are denied, or a timeout occurs, the method returns `null` coordinates
- Attendance always records regardless of GPS availability

**Android Permissions** (declared in `AndroidManifest.xml`, requested at runtime):
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`

---

## Dio API Integration (Mock)

`ApiService` uses Dio configured with:
- **Base URL:** `https://api.smartattend.local/v1` *(mock — intentionally unreachable)*
- **Connection timeout:** 5 seconds
- **Receive timeout:** 5 seconds

All methods (`login`, `fetchEmployees`, `submitAttendance`, `fetchAttendanceHistory`) are wrapped in `try/catch`. When the API is unreachable, the exception is **caught silently** and the app continues using SQLite data only.

**To migrate to a real backend:**
1. Replace `AppConstants.apiBaseUrl` with the real server URL
2. Update `ApiService` response parsing to match the real API schema
3. Move QR token validation to the backend (`POST /validate-qr`)
4. Add JWT authentication headers
5. Remove the silent `catch` blocks (or handle errors meaningfully in the UI)

> The BLoC architecture makes this migration transparent — no UI changes required.

---

## Installation Instructions

**Prerequisites:**
- Flutter SDK **3.41+** (`flutter --version` to check)
- Dart SDK **3.11+** (bundled with Flutter)
- Android SDK with **minSdk 21** (Android 5.0+)
- A connected Android device or emulator

---

## How to Run

```bash
# 1. Install dependencies
flutter pub get

# 2. Run on connected device or emulator
flutter run
```

---

## Demo Login Credentials

| Role | Email | Password | Employee ID |
|---|---|---|---|
| Admin | admin@test.com | admin123 | ADM001 |
| Employee | john@test.com | 123456 | EMP001 |
| Employee | sarah@test.com | 123456 | EMP002 |

> Credentials are pre-seeded into the SQLite database on first launch.

---

## Testing Instructions

> **Important:** Run each test file **separately** to avoid SQLite singleton lock conflicts between test suites.

```bash
flutter test test/database_test.dart
flutter test test/qr_test.dart
flutter test test/step6_test.dart
flutter test test/bloc_test.dart
```

Expected results: all tests pass (23 + 19 + 22 + bloc suite).

---

## Build APK

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-debug.apk` or `app-release.apk`

---

## Known Limitations

- QR validation is **local mock only** — no real backend token verification
- API endpoints are mock — Dio calls always fail silently by design
- No network-based authentication (credentials validated against local SQLite)
- Test files must be run **separately** (SQLite singleton constraint)

---

## Future Improvements

- Real backend API for server-side QR token validation
- Push notifications for attendance reminders
- Multi-day attendance reports with PDF/CSV export
- Admin ability to manually edit or override attendance records
- Face recognition as an additional security layer for check-in

---

*SmartAttend — built with Flutter, BLoC, and SQLite.*
