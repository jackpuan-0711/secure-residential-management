# Secure Residential Management

Secure Residential Management is a Flutter + Firebase application for gated
residential communities. It combines resident onboarding, role-based
administration, visitor QR passes, maintenance reporting, announcements, EV
charging management, and device-level app protection in one mobile-first system.

The project is designed as a security-focused final year project. Firebase Auth,
custom claims, Firestore authorization rules, emulator-backed rules tests, and
device-local app locking work together to protect resident data and prevent
unauthorized privilege changes.

## Main Features

- Email/password authentication, email verification, profile completion, and
  role-based routing for public users, residents, staff, admins, and
  superadmins.
- Fingerprint/biometric verification and a 6-digit app lock PIN for protected
  signed-in sessions.
- One-active-session protection with Firestore session markers, idle timeout,
  and automatic sign-out when a session is replaced or expired.
- Resident approval workflow where admins can approve resident applications or
  reject users into public access.
- Superadmin console for adding and removing administrator accounts without
  allowing ordinary admins to self-promote or promote others.
- Announcements module with admin/superadmin posting, editing, priority, pinning,
  and rule-protected audit fields.
- Visitor management with resident-generated QR passes, gate-staff scanning,
  manual-code validation, check-in/check-out transitions, and audit history.
- Maintenance request workflow for residents to submit unit issues and admins to
  manage repair status.
- EV charging module for residents to start, stop, and review charging sessions.
- Admin EV station management with live device-status support for ESP32 charger
  telemetry.
- Firestore security rules and emulator tests covering users, sessions,
  announcements, visitors, maintenance, EV charging, and IoT device status.

## Latest Updates

- Added fingerprint/biometric authentication on Android and iOS through native
  platform integration.
- Added a local 6-digit app lock PIN with hashed storage, retry cooldown, and
  runtime unlock state.
- Added secure session tracking so only the latest login remains active for an
  account.
- Updated privacy and security screens to manage app-lock behavior.
- Added Firestore rules and tests for the new `auth_sessions` collection.
- Improved EV charger administration and stabilized IoT device-status handling.

## Project Layout

- `mobile_app/` - Flutter app.
- `functions/` - optional callable backend for Blaze-plan deployments.
- `firestore.rules` - Firestore authorization rules.
- `firestore-tests/` - Emulator-backed Firestore rules tests.
- `tools/admin-bootstrap/` - one-time superadmin bootstrap script.

## Security Model

- Superadmin and staff access is controlled by signed Firebase Auth custom
  claims.
- Administrator access is stored in protected Firestore profiles and can only be
  changed by the superadmin flow.
- Residents cannot self-assign roles, verified units, approval status, or admin
  privileges.
- Firestore rules use owner checks, role checks, allowlisted fields, server
  timestamps, and audit invariants to prevent unauthorized writes.
- Visitor QR codes contain only opaque tokens, not visitor personal details.
- App sessions are guarded by biometric verification, a device-local PIN, and
  one-active-session enforcement.

## Run The App

```powershell
cd mobile_app
flutter pub get
flutter run
```

For local development with Auth and Firestore emulators:

```powershell
firebase emulators:start --only auth,firestore
```

In another terminal:

```powershell
cd mobile_app
flutter run -d chrome `
  --dart-define=USE_FIREBASE_EMULATORS=true `
  --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

Use `FIREBASE_EMULATOR_HOST=10.0.2.2` for the Android emulator.

For a quick web preview of the built app:

```powershell
cd mobile_app
flutter build web
python -m http.server 5500 --bind 127.0.0.1 -d build\web
```

Open `http://127.0.0.1:5500`.

## Backend

The production Spark-plan workflow uses Firebase Auth plus rule-gated
Firestore transactions. Cloud Functions are optional and are not required for
resident approval or administrator management.

Build callable functions:

```powershell
cd functions
npm install
npm run build
```

Run Firestore rules tests with the emulator:

```powershell
firebase emulators:exec --only firestore --project residential-management-a3fbf "npm --prefix firestore-tests test"
```

## First Superadmin

Create the first Firebase Auth account in the Firebase Console, then configure
and run:

```powershell
cd tools\admin-bootstrap
npm install
node bootstrap_admin.mjs
```

The bootstrap script sets the signed `role=superadmin` custom claim and mirrors
the profile into Firestore.

## Verification Commands

```powershell
cd mobile_app
flutter analyze
flutter test
flutter build web

cd ..\functions
npm run build

cd ..
firebase emulators:exec --only firestore --project residential-management-a3fbf "npm --prefix firestore-tests test"
```
