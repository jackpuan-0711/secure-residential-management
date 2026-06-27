'use strict';

// ─────────────────────────────────────────────────────────────────────────
// Emulator-backed security-rules tests for /ev_stations and /ev_sessions
// (firestore.rules). Proves: admin-only station management; resident CLAIM
// (available→inUse) vs OWNER RELEASE (inUse→available, proven by a get() on the
// bay's session.userId); owner-scoped session log. See visitor test header for
// the run command.
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
  writeBatch,
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
const anonCtx = () => testEnv.unauthenticatedContext();

async function seedUser(uid, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', uid), {
      uid, email: `${uid}@example.com`, name: uid,
      role: 'resident', status: 'active', unitNumber: 'A-12-5', ...data,
    });
  });
}

async function seedStation(id, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'ev_stations', id), {
      name: 'Station 1', location: 'Basement 2',
      status: 'available', currentSessionId: null, ...data,
    });
  });
}

async function seedSession(id, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'ev_sessions', id), {
      stationId: 'st1', userId: 'resident-uid', unitNumber: 'A-12-5',
      startedAt: Timestamp.fromDate(new Date('2026-06-01T00:00:00Z')),
      endedAt: null, status: 'active', ...data,
    });
  });
}

function validSession(uid, unit, overrides = {}) {
  return {
    stationId: 'st1', userId: uid, unitNumber: unit,
    startedAt: serverTimestamp(), endedAt: null, status: 'active', ...overrides,
  };
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
describe('ev_stations create / read / delete', () => {
  test('admin seeds an available bay → ALLOW', async () => {
    const db = adminCtx().firestore();
    await assertSucceeds(
      setDoc(doc(db, 'ev_stations', 'st1'),
        { name: 'S1', location: 'B2', status: 'available', currentSessionId: null }),
    );
  });

  test('resident seeds a bay → DENY', async () => {
    const db = residentCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'ev_stations', 'st1'),
        { name: 'S1', location: 'B2', status: 'available', currentSessionId: null }),
    );
  });

  test('admin create with status=inUse → DENY (must start available)', async () => {
    const db = adminCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'ev_stations', 'st1'),
        { name: 'S1', location: 'B2', status: 'inUse', currentSessionId: 'x' }),
    );
  });

  test('any verified user reads bays → ALLOW', async () => {
    await seedStation('st1');
    await assertSucceeds(getDoc(doc(residentCtx().firestore(), 'ev_stations', 'st1')));
  });

  test('unauthenticated reads bays → DENY', async () => {
    await seedStation('st1');
    await assertFails(getDoc(doc(anonCtx().firestore(), 'ev_stations', 'st1')));
  });

  test('admin deletes a bay → ALLOW; resident → DENY', async () => {
    await seedStation('st1');
    await assertFails(deleteDoc(doc(residentCtx().firestore(), 'ev_stations', 'st1')));
    await assertSucceeds(deleteDoc(doc(adminCtx().firestore(), 'ev_stations', 'st1')));
  });
});

// ═════════════════════════════════════════════════════════════════════════
describe('ev_stations claim (available → inUse)', () => {
  test('verified resident direct bay claim is denied', async () => {
    await seedStation('st1', { status: 'available' });
    const db = residentCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'ev_stations', 'st1'),
        { status: 'inUse', currentSessionId: 'sess-1' }),
    );
  });

  test('verified resident atomic session create + bay claim is allowed', async () => {
    await seedStation('st1', { status: 'available' });
    const db = residentCtx().firestore();
    const batch = writeBatch(db);
    batch.set(doc(db, 'ev_sessions', 'sess-1'),
      validSession('resident-uid', 'A-12-5'));
    batch.update(doc(db, 'ev_stations', 'st1'),
      { status: 'inUse', currentSessionId: 'sess-1' });

    await assertSucceeds(batch.commit());
  });

  test('claiming an offline bay → DENY', async () => {
    await seedStation('st1', { status: 'offline' });
    const db = residentCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'ev_stations', 'st1'),
        { status: 'inUse', currentSessionId: 'sess-1' }),
    );
  });

  test('claim that also edits name → DENY (affectedKeys)', async () => {
    await seedStation('st1', { status: 'available' });
    const db = residentCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'ev_stations', 'st1'),
        { status: 'inUse', currentSessionId: 'sess-1', name: 'Hijacked' }),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════
describe('ev_stations release (inUse → available)', () => {
  test('session owner direct bay release is denied', async () => {
    await seedSession('sess-1', { userId: 'resident-uid', status: 'active' });
    await seedStation('st1', { status: 'inUse', currentSessionId: 'sess-1' });
    const db = residentCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'ev_stations', 'st1'),
        { status: 'available', currentSessionId: null }),
    );
  });

  test('session owner atomic session completion + bay release is allowed', async () => {
    await seedSession('sess-1', { userId: 'resident-uid', status: 'active' });
    await seedStation('st1', { status: 'inUse', currentSessionId: 'sess-1' });
    const db = residentCtx().firestore();
    const batch = writeBatch(db);
    batch.update(doc(db, 'ev_sessions', 'sess-1'),
      { status: 'completed', endedAt: serverTimestamp() });
    batch.update(doc(db, 'ev_stations', 'st1'),
      { status: 'available', currentSessionId: null });

    await assertSucceeds(batch.commit());
  });

  test('a different resident releases it → DENY (not the session owner)', async () => {
    await seedSession('sess-1', { userId: 'resident-uid', status: 'active' });
    await seedStation('st1', { status: 'inUse', currentSessionId: 'sess-1' });
    const db = otherResidentCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'ev_stations', 'st1'),
        { status: 'available', currentSessionId: null }),
    );
  });

  test('admin direct force-free of in-use bay is denied', async () => {
    await seedSession('sess-1', { userId: 'resident-uid', status: 'active' });
    await seedStation('st1', { status: 'inUse', currentSessionId: 'sess-1' });
    const db = adminCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'ev_stations', 'st1'),
        { status: 'available', currentSessionId: null }),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════
describe('ev_sessions', () => {
  test('verified resident direct session create is denied', async () => {
    const db = residentCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'ev_sessions', 's1'), validSession('resident-uid', 'A-12-5')),
    );
  });

  test('userId != auth.uid → DENY', async () => {
    const db = residentCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'ev_sessions', 's1'),
        validSession('resident-uid', 'A-12-5', { userId: 'resident-2' })),
    );
  });

  test('status != active at create → DENY', async () => {
    const db = residentCtx().firestore();
    await assertFails(
      setDoc(doc(db, 'ev_sessions', 's1'),
        validSession('resident-uid', 'A-12-5', { status: 'completed' })),
    );
  });

  test('owner reads own / other resident denied / admin allowed', async () => {
    await seedSession('s1', { userId: 'resident-uid' });
    await assertSucceeds(getDoc(doc(residentCtx().firestore(), 'ev_sessions', 's1')));
    await assertFails(getDoc(doc(otherResidentCtx().firestore(), 'ev_sessions', 's1')));
    await assertSucceeds(getDoc(doc(adminCtx().firestore(), 'ev_sessions', 's1')));
  });

  test('owner direct session completion is denied', async () => {
    await seedSession('s1', { userId: 'resident-uid', status: 'active' });
    const db = residentCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'ev_sessions', 's1'),
        { status: 'completed', endedAt: serverTimestamp() }),
    );
  });

  test('a different resident completes it → DENY', async () => {
    await seedSession('s1', { userId: 'resident-uid', status: 'active' });
    const db = otherResidentCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'ev_sessions', 's1'),
        { status: 'completed', endedAt: serverTimestamp() }),
    );
  });

  test('delete a session → DENY (audit record)', async () => {
    await seedSession('s1', { userId: 'resident-uid' });
    await assertFails(deleteDoc(doc(adminCtx().firestore(), 'ev_sessions', 's1')));
  });
});
