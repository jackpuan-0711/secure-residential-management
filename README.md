# Secure Residential Management

A Flutter + Firebase residential management app for residents, public users,
admins, and superadmins.

## Main Features

- Email/password sign-up, email verification, profile completion, and role
  routing.
- Resident approval queue with rule-gated approval/rejection.
- Superadmin-only administrator add/remove controls.
- Announcements with admin/superadmin posting.
- Resident visitor QR passes with gate check-in/check-out audit history,
  maintenance requests, and EV charging.
- A restricted gate-staff scanner with camera and manual-code validation.
- Admin maintenance queue and EV station management.
- Firestore security rules and emulator tests for the main collections.

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
