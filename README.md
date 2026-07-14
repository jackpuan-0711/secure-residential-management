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

## Security Features

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
- The 6-digit app lock PIN is stored using salted hash derivation instead of
  plaintext storage.
- Failed PIN attempts trigger a retry cooldown to reduce brute-force risk.
- Authenticated sessions use idle timeout and replacement detection to sign out
  expired or superseded sessions.
- Security-critical Firestore rules are tested with the Firebase emulator.

## Security Standards Alignment

This project is not formally certified by OWASP or MITRE. The implemented
security controls are mapped to selected OWASP and CWE references as a design
and documentation guide:

- [OWASP MASVS](https://mas.owasp.org/MASVS/) - mobile storage, cryptography,
  authentication, authorization, platform interaction, and privacy controls.
- [OWASP Mobile Top 10 2024](https://owasp.org/www-project-mobile-top-10/) -
  mobile risks such as improper credential usage, insecure authentication,
  inadequate privacy controls, insecure data storage, and insufficient
  cryptography.
- [OWASP Top 10:2025](https://owasp.org/Top10/2025/) - application risks such
  as broken access control, security misconfiguration, cryptographic failures,
  authentication failures, and logging failures.
- [OWASP API Security Top 10 2023](https://owasp.org/API-Security/editions/2023/en/0x11-t10/) -
  API-style authorization risks such as broken object-level authorization,
  broken object property-level authorization, and broken function-level
  authorization.
- [MITRE CWE](https://cwe.mitre.org/) - common weakness identifiers used to map
  security risks to known software weakness categories.

## Security Control Mapping

| Implemented control | OWASP / CWE mapping |
| --- | --- |
| Firebase Auth, email verification, and protected route routing | OWASP A07 Authentication Failures, OWASP Mobile M3 Insecure Authentication/Authorization, CWE-287 |
| Fingerprint / biometric verification before app access | OWASP MASVS-AUTH, OWASP Mobile M3 Insecure Authentication/Authorization |
| 6-digit app lock PIN with salted hash storage | OWASP MASVS-AUTH, OWASP MASVS-CRYPTO, OWASP Mobile M9 Insecure Data Storage, OWASP Mobile M10 Insufficient Cryptography, CWE-522 |
| PIN retry cooldown after repeated failures | CWE-307 |
| One-active-session enforcement and idle timeout | OWASP A07 Authentication Failures, CWE-613 |
| Role-based Firestore authorization rules | OWASP A01 Broken Access Control, OWASP API1 Broken Object Level Authorization, OWASP API5 Broken Function Level Authorization, CWE-862, CWE-863 |
| Superadmin-only administrator management | CWE-269 |
| Field allowlisting for sensitive Firestore writes | OWASP API3 Broken Object Property Level Authorization, CWE-915 |
| Resident ownership checks for profiles, visitor passes, maintenance requests, and EV sessions | OWASP API1 Broken Object Level Authorization, CWE-639 |
| Visitor QR payloads that contain opaque tokens instead of visitor personal data | OWASP MASVS-PRIVACY, OWASP Mobile M6 Inadequate Privacy Controls, CWE-200, CWE-359 |
| Server timestamps, status transitions, and audit fields | OWASP A09 Security Logging and Alerting Failures, CWE-778 |
| Emulator-backed Firestore rules tests | Security verification for access-control and data-integrity rules |

## Project Layout

- `mobile_app/` - Flutter app.
- `functions/` - optional callable backend for Blaze-plan deployments.
- `firestore.rules` - Firestore authorization rules.
- `firestore-tests/` - Emulator-backed Firestore rules tests.
- `tools/admin-bootstrap/` - one-time superadmin bootstrap script.

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
