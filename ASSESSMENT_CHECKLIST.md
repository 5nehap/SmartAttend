# SmartAttend – Technical Assessment Checklist

> Use this document during the demo recording and verbal assessment to ensure full coverage of all technical features.

---

## Demo Login Credentials

| Role | Email | Password | Employee ID |
|---|---|---|---|
| Admin | admin@test.com | admin123 | ADM001 |
| Employee (John) | john@test.com | 123456 | EMP001 |
| Employee (Sarah) | sarah@test.com | 123456 | EMP002 |

---

## Demo Video Recording Checklist

Walk through the following steps in order. Check each box as you complete it.

- [ ] **1.** Launch SmartAttend — observe splash screen → auto-redirects to Login (or Home if session persisted)
- [ ] **2.** Login as **Admin** (admin@test.com / admin123)
- [ ] **3.** Show **Admin Dashboard** — verify stats are displayed (total employees, present today, absent today)
- [ ] **4.** Tap **"Generate QR Code"**
- [ ] **5.** Show **QR Generator screen** — QR image visible, 60-second countdown running
- [ ] **6.** Watch QR expire — observe countdown reach 0 and QR become invalid
- [ ] **7.** Tap to **generate a new QR code** — fresh QR and new 60-second countdown
- [ ] **8.** Go back to Admin Dashboard → tap **Logout**
- [ ] **9.** Login as **Employee John** (john@test.com / 123456)
- [ ] **10.** Show **Employee Dashboard** — verify today's status (no check-in yet)
- [ ] **11.** Tap **"Scan QR Code"**
- [ ] **12.** Scan the admin's QR code (admin must have a live QR on their device)
- [ ] **13.** Show **successful check-in confirmation** (bottom sheet or snackbar)
- [ ] **14.** Go back to dashboard — verify **check-in time is displayed**
- [ ] **15.** Ask admin to generate a **new QR code** (previous one is consumed/expired)
- [ ] **16.** Tap **"Scan QR Code"** again → scan new QR → show **successful check-out confirmation**
- [ ] **17.** Tap **"Attendance History"** — show today's record with check-in and check-out times
- [ ] **18.** Tap **Logout**
- [ ] **19.** Login as **Admin** again (admin@test.com / admin123)
- [ ] **20.** Tap **"Attendance Records"**
- [ ] **21.** Show **employee list** with today's attendance status (John should show "Checked Out")
- [ ] **22.** Tap on **John's card** → navigate to Employee Details screen
- [ ] **23.** Show **full attendance history** for John (today's record visible)

---

## Technical Explanation (for verbal assessment)

### Why BLoC?

BLoC (Business Logic Component) strictly separates UI from business logic. All state changes are driven by **Events → BLoC → States**:

- The UI dispatches Events (`AuthLoginRequested`, `AttendanceMarkFromQRRequested`, etc.)
- The BLoC processes the event (calls repositories, updates state)
- The UI rebuilds via `BlocBuilder` / `BlocListener` based on the new State

**`setState` is never used for business logic** anywhere in the codebase — only for local UI state like `_obscurePassword` or `_searchQuery`. This makes the code testable, maintainable, and scalable.

---

### Why SQLite?

SQLite (via `sqflite`) provides reliable **offline-first** data storage. Key design decisions:

- All attendance records are written to SQLite before anything else
- The app works fully without any network connectivity
- A `UNIQUE` constraint on `(employeeId, date)` prevents duplicate attendance records at the database level
- Three tables: `employees`, `attendance`, `qr_sessions`

---

### How QR Validation Works

1. Admin taps "Generate QR" → `QRBloc` generates a **256-bit cryptographically random token** (64 hex characters)
2. A `QRSessionModel` is saved to the `qr_sessions` SQLite table with `expiresAt = now + 60 seconds`
3. The QR image encodes a JSON payload: `{ sessionId, createdAt, expiresAt, token }`
4. Employee scans the QR → `QRBloc` receives `QRValidateRequested`
5. The token is compared using **constant-time equality** to prevent timing attacks
6. The `expiresAt` timestamp is checked against `DateTime.now()`
7. If valid, the session is **immediately invalidated** (marked `isUsed = 1`) in SQLite
8. `AttendanceMarkFromQRRequested` is dispatched to `AttendanceBloc` → attendance recorded

> ⚠️ **This is a LOCAL MOCK implementation.** In production, step 5–6 should be performed on a secure backend server via `POST /validate-qr`. The token should never be validated on the client in a real deployment.

---

### How Duplicate Attendance is Prevented

- SQLite `attendance` table has a **`UNIQUE` constraint on `(employeeId, date)`** — the database itself rejects duplicates
- `AttendanceRepository.markAttendance()` checks whether a check-in record already exists before recording check-out
- If both check-in and check-out already exist, the scan is rejected and `AttendanceResult.alreadyComplete` is returned
- `AttendanceBloc` emits `AttendanceAlreadyComplete` → UI shows appropriate message

---

### How GPS Coordinates are Captured

`LocationService` calls `geolocator.getCurrentPosition()` with a timeout. GPS is **non-blocking**:

- If GPS is unavailable, permissions are denied, or a timeout occurs → returns `null` coordinates
- Attendance **always records**, even without GPS
- When coordinates are available, they are saved to `checkInLatitude` / `checkInLongitude` (and checkout equivalents) in the `attendance` table

**Android permissions** (in `AndroidManifest.xml`, requested at runtime):
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`

---

### How Dio Integration Works

`ApiService` uses Dio configured with:
- **Base URL:** `https://api.smartattend.local/v1` *(mock — intentionally unreachable)*
- **Connection + receive timeout:** 5 seconds

All Dio methods are wrapped in `try/catch`. When the API fails (which it always does in this mock setup), the exception is **caught silently**. The SQLite write has already happened before the Dio call, so no data is lost.

---

### How to Migrate to a Real Backend

1. Replace `AppConstants.apiBaseUrl` with the real server URL
2. Update `ApiService` response parsing to match the real API schema
3. Move QR token validation to the backend (`POST /validate-qr`)
4. Add proper JWT authentication headers to Dio requests
5. Replace silent `catch` blocks with meaningful error handling (e.g. emit error states)

> The BLoC architecture makes this migration transparent — **no UI changes are needed**. Only `ApiService` and `AppConstants` require updates.

---

## Architecture Verification Checklist

Use this to verify the codebase during assessment:

- [ ] `AuthBloc` handles login, logout, and session restore (`AuthSessionCheckRequested`)
- [ ] `AttendanceBloc` handles check-in, check-out, and attendance history
- [ ] `QRBloc` handles QR generation, 60-second countdown timer, validation, and expiry
- [ ] `AdminBloc` handles dashboard stats, employee list, and employee detail
- [ ] SQLite has exactly **3 tables:** `employees`, `attendance`, `qr_sessions`
- [ ] `setState` is **never** used for business logic (only local UI state)
- [ ] GPS is **non-blocking** — attendance records even without coordinates
- [ ] Dio failures are **always silent** — SQLite is the source of truth
- [ ] QR expires in **exactly 60 seconds**
- [ ] Duplicate attendance is prevented at both the repository and database levels
- [ ] All 4 BLoCs are properly closed/disposed when their screens are disposed
- [ ] `AndroidManifest.xml` has CAMERA, INTERNET, and LOCATION permissions

---

## Test Results Reference

> Run each test file **separately** to avoid SQLite singleton lock conflicts.

```bash
flutter test test/database_test.dart
flutter test test/qr_test.dart
flutter test test/step6_test.dart
flutter test test/bloc_test.dart
```

| Test File | Expected Tests | Result |
|---|---|---|
| database_test.dart | 23 | *(fill in after run)* |
| qr_test.dart | 19 | *(fill in after run)* |
| step6_test.dart | 22 | *(fill in after run)* |
| bloc_test.dart | — | *(fill in after run)* |

---

*SmartAttend – Assessment Checklist v1.0*
