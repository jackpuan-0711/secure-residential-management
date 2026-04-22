# Sprint 2 Step 6 Progress

- [MANUAL] Task 1: Clear stale emulator data
- [x] Task 2: Refactor AuthGate with nested StreamBuilder
- [x] Task 3: Update HomeScreen to accept AppUser
- [x] Task 4: Verify flutter analyze and flutter test clean
- [x] Task 5: Manual smoke-test instructions in summary

## Task 1 — Manual steps required

Claude Code cannot run interactive shell commands (the emulator UI is browser-based). Do this yourself before the demo:

```powershell
# From the project root (where firebase.json lives):
firebase emulators:start --only firestore,auth --import=./.emulator-data --export-on-exit=./.emulator-data
# If .emulator-data doesn't exist yet, omit the --import/--export flags:
firebase emulators:start --only firestore,auth
```

Then open the Emulator UI (http://localhost:4000):
- **Authentication** tab → delete all existing test users
- **Firestore** tab → delete all docs under the `users/` collection

## Task 4 — Results

```
flutter analyze → No issues found!
flutter test    → All 39 tests passed!
```

---

## Manual smoke test (for demo tomorrow)

Run `flutter run` in mobile_app/ with the Firebase emulator running.

### Test 1: New public user signup end-to-end
1. Open app → sign up with a new email and a 12+ character password
2. Verify email in emulator UI (Authentication tab → click user → mark verified)
3. Hot-restart app (press R in `flutter run`) to force re-check
4. Should land on **CompleteProfileScreen**
5. Select "Continue as public user" → tap Continue
6. Should land on **HomeScreen** showing role=public, status=active

### Test 2: New resident signup end-to-end
1. Sign up with another new email
2. Verify email in emulator
3. Hot-restart
4. On CompleteProfileScreen, select "I'm a resident", enter `A-12-3`, tap Continue
5. Should land on **AwaitingApprovalScreen** showing "Unit under review: A-12-3"

### Test 3: Admin approval (manual in emulator UI)
1. With the resident from Test 2 still on AwaitingApprovalScreen
2. Open Firestore emulator UI → `users/{uid}`
3. Manually edit: set `status` to `active`, set `unitNumber` to `A-12-3`, set `requestedUnit` to `null`
4. In the app, AwaitingApprovalScreen should update automatically (watchUserProfile stream) and route to HomeScreen showing role=resident, status=active

### Expected gaps (known, not bugs)
- Sign-out button works but there is no resident-specific dashboard yet (Step 7)
- Firestore rules are still permissive (Step 5) — do not deploy as-is

### Implementation notes
- `AppUser` has no `emailVerified` field (it belongs to `AuthIdentity`). The email chip on
  HomeScreen is hardcoded to "Verified" — this is correct because AuthGate only routes to
  HomeScreen after email verification is confirmed by the outer StreamBuilder.
- `user.role.name` and `user.status.name` use Dart's built-in enum `.name` property.
  For `UserStatus.pendingApproval`, `.name` returns `"pendingApproval"` (camelCase). This
  is fine for the demo. Step 7 can add a display-label helper if needed.
- `AwaitingApprovalScreen` does its own `getUserProfile` fetch on `initState`. With the
  new router the screen will only ever be shown when the profile already exists (router
  confirmed it), so the profile card will always be visible. No code change needed in that
  screen — it still works correctly.
