'use strict';

// ─────────────────────────────────────────────────────────────────────────
// Emulator-backed security-rules tests for /maintenance_requests
// (firestore.rules). Create is profile-authorised (verified resident); status
// transitions are admin/superadmin CLAIM only. See visitor_invitations test
// header for the run command and the profile-seeding rationale.
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

const residentCtx = () =>
  testEnv.authenticatedContext('resident-uid', { email_verified: true });
const otherResidentCtx = () =>
  testEnv.authenticatedContext('resident-2', { email_verified: true });
const adminCtx = () =>
  testEnv.authenticatedContext('admin-uid', { role: 'admin', email_verified: true });
const superadminCtx = () =>
  testEnv.authenticatedContext('super-uid', { role: 'superadmin', email_verified: true });
const anonCtx = () => testEnv.unauthenticatedContext();

function validPayload(uid, unit, overrides = {}) {
  return {
    residentId: uid,
    unitNumber: unit,
    category: 'plumbing',
    title: 'Leaking tap',
    description: 'The kitchen tap drips constantly.',
    status: 'pending',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    handledBy: null,
    resolvedAt: null,
    ...overrides,
  };
}

async function seedUser(uid, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', uid), {
      uid, email: `${uid}@example.com`, name: uid,
      role: 'resident', status: 'active', unitNumber: 'A-12-5', ...data,
    });
  });
}

async function seedRequest(id, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'maintenance_requests', id), {
      residentId: 'resident-uid',
      unitNumber: 'A-12-5',
      category: 'plumbing',
      title: 'Leaking tap',
      description: 'Drips.',
      status: 'pending',
      createdAt: Timestamp.fromDate(new Date('2026-06-01T00:00:00Z')),
      updatedAt: Timestamp.fromDate(new Date('2026-06-01T00:00:00Z')),
      handledBy: null,
      resolvedAt: null,
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
after(async () => { if (testEnv) await testEnv.cleanup(); });
beforeEach(async () => {
  await testEnv.clearFirestore();
  await seedUser('resident-uid', { unitNumber: 'A-12-5' });
  await seedUser('resident-2', { unitNumber: 'B-1-1' });
});

// ═════════════════════════════════════════════════════════════════════════
describe('create', () => {
  test('verified resident, own unit, pending → ALLOW', async () => {
    const db = residentCtx().firestore();
    await assertSucceeds(
      setDoc(doc(db, 'maintenance_requests', 'm1'),
        validPayload('resident-uid', 'A-12-5')),
    );
  });

  test('unit != verified profile unit → DENY', async () => {
    const db = residentCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'maintenance_requests', 'm1'),
        validPayload('resident-uid', 'Z-9-9')),
    );
  });

  test('status != pending → DENY', async () => {
    const db = residentCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'maintenance_requests', 'm1'),
        validPayload('resident-uid', 'A-12-5', { status: 'resolved' })),
    );
  });

  test('pre-set handledBy → DENY', async () => {
    const db = residentCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'maintenance_requests', 'm1'),
        validPayload('resident-uid', 'A-12-5', { handledBy: 'admin-uid' })),
    );
  });

  test('extra field → DENY (hasOnly / CWE-915)', async () => {
    const db = residentCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'maintenance_requests', 'm1'),
        validPayload('resident-uid', 'A-12-5', { priorityBoost: true })),
    );
  });

  test('admin (not a resident profile) → DENY', async () => {
    const db = adminCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'maintenance_requests', 'm1'),
        validPayload('admin-uid', 'A-12-5')),
    );
  });

  test('unauthenticated → DENY', async () => {
    const db = anonCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'maintenance_requests', 'm1'),
        validPayload('resident-uid', 'A-12-5')),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════
describe('read', () => {
  test('owner reads own → ALLOW', async () => {
    await seedRequest('m1');
    await assertSucceeds(getDoc(doc(residentCtx().firestore(), 'maintenance_requests', 'm1')));
  });
  test('another resident reads it → DENY', async () => {
    await seedRequest('m1');
    await assertFails(getDoc(doc(otherResidentCtx().firestore(), 'maintenance_requests', 'm1')));
  });
  test('admin reads any → ALLOW', async () => {
    await seedRequest('m1');
    await assertSucceeds(getDoc(doc(adminCtx().firestore(), 'maintenance_requests', 'm1')));
  });
});

// ═════════════════════════════════════════════════════════════════════════
describe('update (status — admin only)', () => {
  test('admin advances status + stamps audit → ALLOW', async () => {
    await seedRequest('m1');
    const db = adminCtx().firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'maintenance_requests', 'm1'), {
        status: 'inProgress', handledBy: 'admin-uid',
        updatedAt: serverTimestamp(), resolvedAt: null,
      }),
    );
  });

  test('superadmin resolves → ALLOW', async () => {
    await seedRequest('m1');
    const db = superadminCtx().firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'maintenance_requests', 'm1'), {
        status: 'resolved', handledBy: 'super-uid',
        updatedAt: serverTimestamp(), resolvedAt: serverTimestamp(),
      }),
    );
  });

  test('filing resident advances own status → DENY (claim required)', async () => {
    await seedRequest('m1');
    const db = residentCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'maintenance_requests', 'm1'), {
        status: 'resolved', handledBy: 'resident-uid',
        updatedAt: serverTimestamp(), resolvedAt: serverTimestamp(),
      }),
    );
  });

  test('admin also edits the request body → DENY (hasOnly)', async () => {
    await seedRequest('m1');
    const db = adminCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'maintenance_requests', 'm1'), {
        status: 'inProgress', handledBy: 'admin-uid',
        updatedAt: serverTimestamp(), title: 'Rewritten title',
      }),
    );
  });

  test('admin stamps handledBy != self → DENY', async () => {
    await seedRequest('m1');
    const db = adminCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'maintenance_requests', 'm1'), {
        status: 'inProgress', handledBy: 'someone-else',
        updatedAt: serverTimestamp(), resolvedAt: null,
      }),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════
describe('delete', () => {
  test('admin → DENY (audit record)', async () => {
    await seedRequest('m1');
    await assertFails(deleteDoc(doc(adminCtx().firestore(), 'maintenance_requests', 'm1')));
  });
});
