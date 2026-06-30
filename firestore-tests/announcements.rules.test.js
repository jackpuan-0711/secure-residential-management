'use strict';

// ─────────────────────────────────────────────────────────────────────────
// Emulator-backed security-rules tests for /announcements (firestore.rules).
//
// WHY THIS EXISTS
//   firestore.rules is the AUTHORITATIVE write/read gate for announcements
//   (AnnouncementRepository on the client is only a convenience layer). These
//   tests exercise that gate directly against the Firestore emulator with
//   forged auth tokens — proving the rule denies what it must and allows only
//   what it must, independent of any client.
//
// HOW TO RUN (from the repo root — boots the emulator, runs, tears down):
//   firebase emulators:exec --only firestore --project residential-management-a3fbf \
//     "npm --prefix firestore-tests test"
//
// CUSTOM CLAIMS
//   authenticatedContext(uid, claims) forges the decoded ID token. We set
//   `role` (the server-minted RBAC claim the rules trust) and `email_verified`
//   exactly as Firebase Auth would surface them at request.auth.token.*.
//
// INDEX CAVEAT (read before trusting the ordering test)
//   The Firestore emulator does NOT enforce composite indexes — it will run a
//   compound orderBy without one and never returns FAILED_PRECONDITION. So the
//   ordering test below proves the QUERY SEMANTICS (pinned desc, postedAt desc)
//   that fake_cloud_firestore could not reproduce in step 1's unit tests; it
//   does NOT prove the firestore.indexes.json declaration itself. That index
//   declaration is what real Firestore requires at deploy time, and is verified
//   by `firebase deploy --only firestore:indexes` (held for review).
// ─────────────────────────────────────────────────────────────────────────

const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test, describe, before, after, beforeEach } = require('node:test');

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { firestoreEmulatorOptions } = require('./test_environment');

const {
  doc,
  collection,
  setDoc,
  getDoc,
  getDocs,
  updateDoc,
  deleteDoc,
  query,
  orderBy,
  serverTimestamp,
  Timestamp,
} = require('firebase/firestore');

// singleProjectMode is true in firebase.json, so the rules-unit-testing
// projectId MUST match the emulator's --project id.
const PROJECT_ID = 'residential-management-a3fbf';
const RULES_PATH = join(__dirname, '..', 'firestore.rules');

let testEnv;

// ── auth-context factories (forged tokens) ──────────────────────────────
const adminCtx = () =>
  testEnv.authenticatedContext('admin-uid', { role: 'admin', email_verified: true });
const superadminCtx = () =>
  testEnv.authenticatedContext('super-uid', { role: 'superadmin', email_verified: true });
const residentCtx = () =>
  testEnv.authenticatedContext('resident-uid', { role: 'resident', email_verified: true });
const publicCtx = () =>
  testEnv.authenticatedContext('public-uid', { role: 'public', email_verified: true });
// A registered user whose email is not yet verified — must be locked out of reads.
const unverifiedCtx = () =>
  testEnv.authenticatedContext('unverified-uid', { role: 'resident', email_verified: false });
// An admin whose email is NOT verified — the claim is present but, per the
// email_verified parity gate, must still be denied both create and delete.
const unverifiedAdminCtx = () =>
  testEnv.authenticatedContext('unverified-admin-uid', { role: 'admin', email_verified: false });
const anonCtx = () => testEnv.unauthenticatedContext();

// A valid create payload for the given author. postedAt uses serverTimestamp()
// so it resolves to request.time on the server — satisfying the rule's
// `postedAt == request.time` server-timestamp clause.
function validPayload(uid, role, overrides = {}) {
  return {
    title: 'Water shut-off Saturday',
    body: 'Mains water will be off 09:00–12:00 for tank cleaning.',
    postedBy: uid,
    postedByRole: role,
    priority: 'info',
    pinned: false,
    postedAt: serverTimestamp(),
    ...overrides,
  };
}

// Seed a doc bypassing rules (for read/update/delete/ordering setup). Uses a
// concrete Timestamp so ordering is deterministic.
async function seed(id, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'announcements', id), data);
  });
}

function seededDoc(overrides = {}) {
  return {
    title: 'Seeded notice',
    body: 'Body.',
    postedBy: 'admin-uid',
    postedByRole: 'admin',
    priority: 'info',
    pinned: false,
    postedAt: Timestamp.fromDate(new Date('2026-06-03T00:00:00Z')),
    ...overrides,
  };
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: firestoreEmulatorOptions(readFileSync(RULES_PATH, 'utf8')),
  });
});

after(async () => {
  if (testEnv) await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// ═════════════════════════════════════════════════════════════════════════
// CREATE
// ═════════════════════════════════════════════════════════════════════════
describe('create', () => {
  test('admin with valid payload → ALLOW', async () => {
    const db = adminCtx().firestore();
    await assertSucceeds(
      setDoc(doc(db, 'announcements', 'ann1'), validPayload('admin-uid', 'admin')),
    );
  });

  test('superadmin with valid payload → ALLOW', async () => {
    const db = superadminCtx().firestore();
    await assertSucceeds(
      setDoc(doc(db, 'announcements', 'ann1'), validPayload('super-uid', 'superadmin')),
    );
  });

  test('resident → DENY', async () => {
    const db = residentCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'announcements', 'ann1'), validPayload('resident-uid', 'resident')),
    );
  });

  test('public → DENY', async () => {
    const db = publicCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'announcements', 'ann1'), validPayload('public-uid', 'public')),
    );
  });

  test('unauthenticated → DENY', async () => {
    const db = anonCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'announcements', 'ann1'), validPayload('whoever', 'admin')),
    );
  });

  test('postedBy != auth.uid → DENY (CWE-639)', async () => {
    const db = adminCtx().firestore();
    await assertFails(
      setDoc(
        doc(db, 'announcements', 'ann1'),
        validPayload('admin-uid', 'admin', { postedBy: 'someone-else' }),
      ),
    );
  });

  test('postedByRole != token.role → DENY (audit integrity)', async () => {
    const db = adminCtx().firestore();
    await assertFails(
      setDoc(
        doc(db, 'announcements', 'ann1'),
        // admin token, but claims superadmin authorship
        validPayload('admin-uid', 'admin', { postedByRole: 'superadmin' }),
      ),
    );
  });

  test('extra field present → DENY (hasOnly / CWE-915)', async () => {
    const db = adminCtx().firestore();
    await assertFails(
      setDoc(
        doc(db, 'announcements', 'ann1'),
        validPayload('admin-uid', 'admin', { isSticky: true }),
      ),
    );
  });

  test("priority='urgent' (not in allowlist) → DENY", async () => {
    const db = adminCtx().firestore();
    await assertFails(
      setDoc(
        doc(db, 'announcements', 'ann1'),
        validPayload('admin-uid', 'admin', { priority: 'urgent' }),
      ),
    );
  });

  test('empty title → DENY', async () => {
    const db = adminCtx().firestore();
    await assertFails(
      setDoc(
        doc(db, 'announcements', 'ann1'),
        validPayload('admin-uid', 'admin', { title: '' }),
      ),
    );
  });

  test('title > 200 chars → DENY', async () => {
    const db = adminCtx().firestore();
    await assertFails(
      setDoc(
        doc(db, 'announcements', 'ann1'),
        validPayload('admin-uid', 'admin', { title: 'a'.repeat(201) }),
      ),
    );
  });

  test('body > 5000 chars → DENY', async () => {
    const db = adminCtx().firestore();
    await assertFails(
      setDoc(
        doc(db, 'announcements', 'ann1'),
        validPayload('admin-uid', 'admin', { body: 'a'.repeat(5001) }),
      ),
    );
  });

  test('client-supplied postedAt (!= request.time) → DENY', async () => {
    const db = adminCtx().firestore();
    await assertFails(
      setDoc(
        doc(db, 'announcements', 'ann1'),
        validPayload('admin-uid', 'admin', {
          postedAt: Timestamp.fromDate(new Date('2000-01-01T00:00:00Z')),
        }),
      ),
    );
  });

  test('unverified-email admin → DENY (email_verified parity)', async () => {
    const db = unverifiedAdminCtx().firestore();
    await assertFails(
      setDoc(
        doc(db, 'announcements', 'ann1'),
        validPayload('unverified-admin-uid', 'admin'),
      ),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════
// READ  (any registered + email-verified user; no pre-login access)
// ═════════════════════════════════════════════════════════════════════════
describe('read', () => {
  beforeEach(async () => {
    await seed('seed1', seededDoc());
  });

  test('unverified email → DENY', async () => {
    const db = unverifiedCtx().firestore();
    await assertFails(getDoc(doc(db, 'announcements', 'seed1')));
  });

  test('unauthenticated → DENY', async () => {
    const db = anonCtx().firestore();
    await assertFails(getDoc(doc(db, 'announcements', 'seed1')));
  });

  test('verified resident → ALLOW', async () => {
    const db = residentCtx().firestore();
    await assertSucceeds(getDoc(doc(db, 'announcements', 'seed1')));
  });

  test('verified public → ALLOW', async () => {
    const db = publicCtx().firestore();
    await assertSucceeds(getDoc(doc(db, 'announcements', 'seed1')));
  });

  test('verified admin → ALLOW', async () => {
    const db = adminCtx().firestore();
    await assertSucceeds(getDoc(doc(db, 'announcements', 'seed1')));
  });
});

// ═════════════════════════════════════════════════════════════════════════
// UPDATE  (immutable — correction = delete + repost)
// ═════════════════════════════════════════════════════════════════════════
describe('update', () => {
  beforeEach(async () => {
    await seed('seed1', seededDoc());
  });

  test('admin edits content with server edit audit → ALLOW', async () => {
    const db = adminCtx().firestore();
    await assertSucceeds(updateDoc(doc(db, 'announcements', 'seed1'), {
      title: 'edited',
      editedBy: 'admin-uid',
      editedAt: serverTimestamp(),
    }));
  });

  test('superadmin edits priority and pinning → ALLOW', async () => {
    const db = superadminCtx().firestore();
    await assertSucceeds(updateDoc(doc(db, 'announcements', 'seed1'), {
      priority: 'critical',
      pinned: true,
      editedBy: 'super-uid',
      editedAt: serverTimestamp(),
    }));
  });

  test('resident edit → DENY', async () => {
    const db = residentCtx().firestore();
    await assertFails(updateDoc(doc(db, 'announcements', 'seed1'), {
      title: 'forged',
      editedBy: 'resident-uid',
      editedAt: serverTimestamp(),
    }));
  });

  test('admin changing original author → DENY', async () => {
    const db = adminCtx().firestore();
    await assertFails(updateDoc(doc(db, 'announcements', 'seed1'), {
      postedBy: 'someone-else',
      editedBy: 'admin-uid',
      editedAt: serverTimestamp(),
    }));
  });

  test('admin forging editedBy → DENY', async () => {
    const db = adminCtx().firestore();
    await assertFails(updateDoc(doc(db, 'announcements', 'seed1'), {
      title: 'edited',
      editedBy: 'someone-else',
      editedAt: serverTimestamp(),
    }));
  });
});

// ═════════════════════════════════════════════════════════════════════════
// DELETE  (admin / superadmin only — moderation / repost)
// ═════════════════════════════════════════════════════════════════════════
describe('delete', () => {
  beforeEach(async () => {
    await seed('seed1', seededDoc());
  });

  test('admin → ALLOW', async () => {
    const db = adminCtx().firestore();
    await assertSucceeds(deleteDoc(doc(db, 'announcements', 'seed1')));
  });

  test('superadmin → ALLOW', async () => {
    const db = superadminCtx().firestore();
    await assertSucceeds(deleteDoc(doc(db, 'announcements', 'seed1')));
  });

  test('resident → DENY', async () => {
    const db = residentCtx().firestore();
    await assertFails(deleteDoc(doc(db, 'announcements', 'seed1')));
  });

  test('unverified-email admin → DENY (email_verified parity)', async () => {
    const db = unverifiedAdminCtx().firestore();
    await assertFails(deleteDoc(doc(db, 'announcements', 'seed1')));
  });
});

// ═════════════════════════════════════════════════════════════════════════
// ORDERING  (closes the multi-field ordering deferred from step 1 unit tests)
//
//   pinned DESC (true before false), then postedAt DESC (newest first).
//   Seeded set:
//     A  pinned=true   2026-06-01
//     B  pinned=true   2026-06-03
//     C  pinned=false  2026-06-05
//     D  pinned=false  2026-06-02
//   Expected: [B, A, C, D]
// ═════════════════════════════════════════════════════════════════════════
describe('ordering', () => {
  beforeEach(async () => {
    await seed('A', seededDoc({ pinned: true, postedAt: Timestamp.fromDate(new Date('2026-06-01T00:00:00Z')) }));
    await seed('B', seededDoc({ pinned: true, postedAt: Timestamp.fromDate(new Date('2026-06-03T00:00:00Z')) }));
    await seed('C', seededDoc({ pinned: false, postedAt: Timestamp.fromDate(new Date('2026-06-05T00:00:00Z')) }));
    await seed('D', seededDoc({ pinned: false, postedAt: Timestamp.fromDate(new Date('2026-06-02T00:00:00Z')) }));
  });

  test('orderBy(pinned desc, postedAt desc) → [B, A, C, D]', async () => {
    const assert = require('node:assert/strict');
    const db = residentCtx().firestore(); // verified reader
    const snap = await assertSucceeds(
      getDocs(
        query(
          collection(db, 'announcements'),
          orderBy('pinned', 'desc'),
          orderBy('postedAt', 'desc'),
        ),
      ),
    );
    const ids = snap.docs.map((d) => d.id);
    assert.deepEqual(ids, ['B', 'A', 'C', 'D']);
  });
});
