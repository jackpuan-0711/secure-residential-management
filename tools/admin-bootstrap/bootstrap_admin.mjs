// tools/admin-bootstrap/bootstrap_admin.mjs
//
// GENESIS ADMIN PROVISIONING — out-of-band, run ONCE, locally.
// Elevates an EXISTING Firebase Auth account to super-admin by:
//   1) setting an unforgeable custom claim { role: 'superadmin' }  (the security boundary)
//   2) mirroring role/status into the Firestore user document (queryable app data)
//
// WHY A CLAIM, NOT JUST A FIRESTORE FIELD (viva):
//   Custom claims can ONLY be set via the Admin SDK (service-account privilege),
//   never from the Flutter client. So admin status stays unforgeable even against
//   a user who finds a Firestore write-rule bug — closes CWE-269 (privilege escalation).
//
// KEY HANDLING (viva): the service-account key is god-mode; it is gitignored and
//   never committed (CWE-798 / OWASP M1). Read from a local path only.

import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync } from 'node:fs';

// --- Config -----------------------------------------------------------------
const SERVICE_ACCOUNT_PATH = './secrets/serviceAccountKey.json'; // GITIGNORED
const ADMIN_EMAIL = 'jackpuan1995@gmail.com';
// ----------------------------------------------------------------------------

const serviceAccount = JSON.parse(readFileSync(SERVICE_ACCOUNT_PATH, 'utf8'));
initializeApp({ credential: cert(serviceAccount) });

const auth = getAuth();
const db = getFirestore();

async function main() {
  // 1) Resolve the UID. The account MUST already exist in Firebase Auth (you
  //    created it via the Console). We never create it / set a password here.
  let user;
  try {
    user = await auth.getUserByEmail(ADMIN_EMAIL);
  } catch (_) {
    console.error(
      `\n[ABORT] No Firebase Auth account for ${ADMIN_EMAIL}.\n` +
      `Create it first: Firebase Console > Authentication > Add user, then re-run.\n`
    );
    process.exit(1);
  }

  const uid = user.uid;

  // 2) The security boundary: set the unforgeable custom claim.
  await auth.setCustomUserClaims(uid, { role: 'superadmin' });

  // 3) Mirror into Firestore as queryable app data. merge:true so we don't
  //    clobber a profile the app may already have created for this account.
  await db.collection('users').doc(uid).set(
    {
      email: ADMIN_EMAIL,
      role: 'superadmin',
      status: 'active',
      elevatedBy: 'genesis-bootstrap-script',
      elevatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  console.log(`\n[OK] ${ADMIN_EMAIL} (uid ${uid}) is now super-admin.`);
  console.log("Claim { role: 'superadmin' } set + Firestore users doc mirrored.");
  console.log('On next login the app must call getIdToken(true) to see the claim.\n');
  process.exit(0);
}

main().catch((e) => { console.error('[ERROR]', e); process.exit(1); });