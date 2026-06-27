# Residential Hub Flutter App

Role-based Flutter client for public users, residents, gate staff, admins, and
superadmins. Firebase Authentication supplies identity; the genesis
superadmin and gate staff use signed claims, while protected Firestore profiles
hold administrator and resident roles. Firestore rules are the authorization
boundary.

## Implemented flows

- Public registration, email verification, profile completion, and resident
  applications.
- Resident announcements, visitor passes, maintenance, and EV charging.
- Visitor QR issuance, scheduled-day validation, check-in/check-out auditing,
  and a manual pass-code fallback when a gate camera is unavailable.
- Gate-staff-only scanner home.
- Admin resident approvals and property operations.
- Superadmin administrator add/remove controls and all admin operations.

## Local verification

```powershell
flutter pub get
flutter analyze
flutter test
flutter build web --release
```

Use the Firebase emulator commands in the repository root README for local
integration testing. Camera scanning requires HTTPS or localhost on web, the
Android `CAMERA` permission, and the iOS camera usage description already
included in the platform projects.

## Release prerequisites

Before a production launch, configure store signing, production Firebase
projects, authorized domains, privacy/support contact details, monitoring,
backups, retention policy, and operational staff provisioning. Never ship an
emulator build or commit signing keys/service-account credentials.
