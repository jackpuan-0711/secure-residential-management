'use strict';

// ─────────────────────────────────────────────────────────────────────────
// Emulator-backed security-rules tests for /visitor_invitations
// (firestore.rules). Proves the gate that VisitorRepository is only a
// convenience layer over.
//
// KEY DIFFERENCE FROM announcements: residents carry NO {role} claim this
// phase, so the create gate authorises from the caller's OWN /users profile.
// These tests therefore SEED /users/{uid} (via withSecurityRulesDisabled) so
// the rule's get() finds a verified-resident profile — exactly as production
// does after admin approval.
//
// HOW TO RUN (from repo root):
//   firebase emulators:exec --only firestore --project residential-management-a3fbf \
//     "npm --prefix firestore-tests test"
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
  setDoc,
  getDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
  Timestamp,
} = require('firebase/firestore');

const PROJECT_ID = 'residential-management-a3fbf';
const RULES_PATH = join(__dirname, '..', 'firestore.rules');

let testEnv;

// ── auth contexts (forged tokens) ───────────────────────────────────────
// Residents have email_verified but NO role claim (this phase).
const residentCtx = () =>
  testEnv.authenticatedContext('resident-uid', { email_verified: true });
const otherResidentCtx = () =>
  testEnv.authenticatedContext('resident-2', { email_verified: true });
const unverifiedResidentCtx = () =>
  testEnv.authenticatedContext('resident-uid', { email_verified: false });
const publicCtx = () =>
  testEnv.authenticatedContext('public-uid', { email_verified: true });
const adminCtx = () =>
  testEnv.authenticatedContext('admin-uid', { role: 'admin', email_verified: true });
const staffCtx = () =>
  testEnv.authenticatedContext('staff-uid', { role: 'staff', email_verified: true });
const anonCtx = () => testEnv.unauthenticatedContext();

const FUTURE = () => Timestamp.fromDate(new Date(Date.now() + 86_400_000));

function validPayload(uid, unit, overrides = {}) {
  return {
    residentId: uid,
    unitNumber: unit,
    visitorName: 'Jane Tan',
    visitorContact: '012-345 6789',
    guestCount: 1,
    vehiclePlate: null,
    visitDate: FUTURE(),
    eta: '6:00 PM',
    status: 'active',
    createdAt: serverTimestamp(),
    expiresAt: FUTURE(),
    cancelledAt: null,
    cancelledBy: null,
    checkedInAt: null,
    checkedInBy: null,
    checkedOutAt: null,
    checkedOutBy: null,
    ...overrides,
  };
}

// Seed a /users profile (bypassing rules) so the create gate's get() resolves.
async function seedUser(uid, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', uid), {
      uid,
      email: `${uid}@example.com`,
      name: uid,
      role: 'resident',
      status: 'active',
      unitNumber: 'A-12-5',
      ...data,
    });
  });
}

// Seed a pass (bypassing rules) for read/update/delete setup.
async function seedPass(id, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'visitor_invitations', id), {
      residentId: 'resident-uid',
      unitNumber: 'A-12-5',
      visitorName: 'Jane Tan',
      visitorContact: '012',
      guestCount: 1,
      vehiclePlate: null,
      visitDate: Timestamp.fromDate(new Date(Date.now() - 1000)),
      eta: '6:00 PM',
      status: 'active',
      createdAt: Timestamp.fromDate(new Date('2026-06-01T00:00:00Z')),
      expiresAt: FUTURE(),
      cancelledAt: null,
      cancelledBy: null,
      checkedInAt: null,
      checkedInBy: null,
      checkedOutAt: null,
      checkedOutBy: null,
      ...data,
    });
  });
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
  // The verified resident, their unit-mate-of-record, and a public user.
  await seedUser('resident-uid', { unitNumber: 'A-12-5' });
  await seedUser('resident-2', { unitNumber: 'B-1-1' });
  await seedUser('public-uid', { role: 'public', status: 'active', unitNumber: null });
});

// ═════════════════════════════════════════════════════════════════════════
describe('create', () => {
  test('verified resident, own uid + own unit → ALLOW', async () => {
    const db = residentCtx().firestore();
    await assertSucceeds(
      setDoc(doc(db, 'visitor_invitations', 't1'), validPayload('resident-uid', 'A-12-5')),
    );
  });

  test('residentId != auth.uid → DENY', async () => {
    const db = residentCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'visitor_invitations', 't1'),
        validPayload('resident-uid', 'A-12-5', { residentId: 'resident-2' })),
    );
  });

  test('unit != verified profile unit → DENY', async () => {
    const db = residentCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'visitor_invitations', 't1'),
        validPayload('resident-uid', 'D-9-9')),
    );
  });

  test('status != active → DENY', async () => {
    const db = residentCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'visitor_invitations', 't1'),
        validPayload('resident-uid', 'A-12-5', { status: 'checkedIn' })),
    );
  });

  test('expiresAt in the past → DENY', async () => {
    const db = residentCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'visitor_invitations', 't1'),
        validPayload('resident-uid', 'A-12-5',
          { expiresAt: Timestamp.fromDate(new Date('2020-01-01T00:00:00Z')) })),
    );
  });

  test('extra field → DENY (hasOnly / CWE-915)', async () => {
    const db = residentCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'visitor_invitations', 't1'),
        validPayload('resident-uid', 'A-12-5', { vip: true })),
    );
  });

  test('guestCount outside allowed range is denied', async () => {
    const db = residentCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'visitor_invitations', 't1'),
        validPayload('resident-uid', 'A-12-5', { guestCount: 0 })),
    );
    await assertFails(
      setDoc(doc(db, 'visitor_invitations', 't2'),
        validPayload('resident-uid', 'A-12-5', { guestCount: 21 })),
    );
  });

  test('public user (no verified unit) -> DENY', async () => {
    const db = publicCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'visitor_invitations', 't1'),
        validPayload('public-uid', 'A-12-5')),
    );
  });

  test('unverified email → DENY', async () => {
    const db = unverifiedResidentCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'visitor_invitations', 't1'),
        validPayload('resident-uid', 'A-12-5')),
    );
  });

  test('unauthenticated → DENY', async () => {
    const db = anonCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'visitor_invitations', 't1'),
        validPayload('resident-uid', 'A-12-5')),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════
describe('read', () => {
  test('owner reads own pass → ALLOW', async () => {
    await seedPass('t1', { residentId: 'resident-uid' });
    const db = residentCtx().firestore();
    await assertSucceeds(getDoc(doc(db, 'visitor_invitations', 't1')));
  });

  test('another resident reads it → DENY (CWE-639)', async () => {
    await seedPass('t1', { residentId: 'resident-uid' });
    const db = otherResidentCtx().firestore();
    await assertFails(getDoc(doc(db, 'visitor_invitations', 't1')));
  });

  test('gate staff reads any pass → ALLOW', async () => {
    await seedPass('t1', { residentId: 'resident-uid' });
    const db = staffCtx().firestore();
    await assertSucceeds(getDoc(doc(db, 'visitor_invitations', 't1')));
  });
});

// ═════════════════════════════════════════════════════════════════════════
describe('update (status transitions)', () => {
  test('owner cancels active pass → ALLOW', async () => {
    await seedPass('t1', { residentId: 'resident-uid', status: 'active' });
    const db = residentCtx().firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'visitor_invitations', 't1'), {
        status: 'cancelled',
        cancelledAt: serverTimestamp(),
        cancelledBy: 'resident-uid',
      }),
    );
  });

  test('non-owner cancels → DENY', async () => {
    await seedPass('t1', { residentId: 'resident-uid', status: 'active' });
    const db = otherResidentCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'visitor_invitations', 't1'), {
        status: 'cancelled',
        cancelledAt: serverTimestamp(),
        cancelledBy: 'resident-2',
      }),
    );
  });

  test('owner changes a non-status field too → DENY (onlyStatusChanged)', async () => {
    await seedPass('t1', { residentId: 'resident-uid', status: 'active' });
    const db = residentCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'visitor_invitations', 't1'),
        {
          status: 'cancelled',
          cancelledAt: serverTimestamp(),
          cancelledBy: 'resident-uid',
          visitorName: 'Someone Else',
        }),
    );
  });

  test('staff checks an active pass in → ALLOW', async () => {
    await seedPass('t1', { residentId: 'resident-uid', status: 'active' });
    const db = staffCtx().firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'visitor_invitations', 't1'), {
        status: 'checkedIn',
        checkedInAt: serverTimestamp(),
        checkedInBy: 'staff-uid',
      }),
    );
  });

  test('staff cannot check in an expired active pass', async () => {
    await seedPass('t1', {
      residentId: 'resident-uid',
      status: 'active',
      expiresAt: Timestamp.fromDate(new Date('2020-01-01T00:00:00Z')),
    });
    const db = staffCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'visitor_invitations', 't1'), {
        status: 'checkedIn',
        checkedInAt: serverTimestamp(),
        checkedInBy: 'staff-uid',
      }),
    );
  });

  test('staff cannot check in before the scheduled visit day', async () => {
    await seedPass('t1', {
      status: 'active',
      visitDate: FUTURE(),
      expiresAt: Timestamp.fromDate(new Date(Date.now() + 172_800_000)),
    });
    const db = staffCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'visitor_invitations', 't1'), {
        status: 'checkedIn',
        checkedInAt: serverTimestamp(),
        checkedInBy: 'staff-uid',
      }),
    );
  });

  test('staff cannot attribute a check-in to another account', async () => {
    await seedPass('t1', { status: 'active' });
    const db = staffCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'visitor_invitations', 't1'), {
        status: 'checkedIn',
        checkedInAt: serverTimestamp(),
        checkedInBy: 'admin-uid',
      }),
    );
  });

  test('staff checks a checked-in pass out with audit fields', async () => {
    await seedPass('t1', {
      status: 'checkedIn',
      checkedInAt: Timestamp.fromDate(new Date(Date.now() - 1000)),
      checkedInBy: 'staff-uid',
    });
    const db = staffCtx().firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'visitor_invitations', 't1'), {
        status: 'checkedOut',
        checkedOutAt: serverTimestamp(),
        checkedOutBy: 'staff-uid',
      }),
    );
  });

  test('resident self-checks-in (active → checkedIn) → DENY', async () => {
    await seedPass('t1', { residentId: 'resident-uid', status: 'active' });
    const db = residentCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'visitor_invitations', 't1'), {
        status: 'checkedIn',
        checkedInAt: serverTimestamp(),
        checkedInBy: 'resident-uid',
      }),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════
describe('delete', () => {
  test('owner → DENY (audit record)', async () => {
    await seedPass('t1', { residentId: 'resident-uid' });
    const db = residentCtx().firestore();
    await assertFails(deleteDoc(doc(db, 'visitor_invitations', 't1')));
  });

  test('admin → DENY (audit record)', async () => {
    await seedPass('t1', { residentId: 'resident-uid' });
    const db = adminCtx().firestore();
    await assertFails(deleteDoc(doc(db, 'visitor_invitations', 't1')));
  });
});
