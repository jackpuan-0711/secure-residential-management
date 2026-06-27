'use strict';

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
  serverTimestamp,
} = require('firebase/firestore');

const PROJECT_ID = 'residential-management-a3fbf';
const RULES_PATH = join(__dirname, '..', 'firestore.rules');

let testEnv;

const userCtx = (uid) =>
  testEnv.authenticatedContext(uid, { email_verified: true });
const adminCtx = () =>
  testEnv.authenticatedContext('admin-uid', {
    role: 'admin',
    email_verified: true,
  });
const profileAdminCtx = () =>
  testEnv.authenticatedContext('profile-admin', { email_verified: true });
const superadminCtx = () =>
  testEnv.authenticatedContext('super-uid', {
    role: 'superadmin',
    email_verified: true,
  });
const anonCtx = () => testEnv.unauthenticatedContext();

function residentProfile(uid, overrides = {}) {
  return {
    uid,
    email: `${uid}@example.com`,
    name: 'Resident User',
    role: 'resident',
    status: 'pending_approval',
    requestedRole: null,
    requestedUnit: 'A-12-3',
    unitNumber: null,
    phoneNumber: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    approvedAt: null,
    approvedBy: null,
    rejectedAt: null,
    rejectedBy: null,
    mfaEnrolled: false,
    fcmTokens: [],
    ...overrides,
  };
}

function publicProfile(uid, overrides = {}) {
  return {
    uid,
    email: `${uid}@example.com`,
    name: 'Public User',
    role: 'public',
    status: 'active',
    requestedRole: null,
    requestedUnit: null,
    unitNumber: null,
    phoneNumber: null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    approvedAt: null,
    approvedBy: null,
    rejectedAt: null,
    rejectedBy: null,
    mfaEnrolled: false,
    fcmTokens: [],
    ...overrides,
  };
}

async function seedUser(uid, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', uid), data);
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
});

describe('create', () => {
  test('resident signup payload from Flutter -> ALLOW', async () => {
    const db = userCtx('new-resident').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'users', 'new-resident'), residentProfile('new-resident')),
    );
  });

  test('public signup payload from Flutter -> ALLOW', async () => {
    const db = userCtx('new-public').firestore();
    await assertSucceeds(
      setDoc(doc(db, 'users', 'new-public'), publicProfile('new-public')),
    );
  });

  test('missing requestedRole no longer breaks profile creation', async () => {
    const db = userCtx('legacy-client').firestore();
    const payload = publicProfile('legacy-client');
    delete payload.requestedRole;
    await assertSucceeds(setDoc(doc(db, 'users', 'legacy-client'), payload));
  });

  test('cannot create someone else profile', async () => {
    const db = userCtx('attacker').firestore();
    await assertFails(
      setDoc(doc(db, 'users', 'victim'), publicProfile('victim')),
    );
  });

  test('cannot self-grant admin role', async () => {
    const db = userCtx('attacker').firestore();
    await assertFails(
      setDoc(
        doc(db, 'users', 'attacker'),
        publicProfile('attacker', { role: 'admin' }),
      ),
    );
  });

  test('cannot create profile with verified unit already set', async () => {
    const db = userCtx('attacker').firestore();
    await assertFails(
      setDoc(
        doc(db, 'users', 'attacker'),
        residentProfile('attacker', { unitNumber: 'A-12-3' }),
      ),
    );
  });

  test('unauthenticated create -> DENY', async () => {
    const db = anonCtx().firestore();
    await assertFails(setDoc(doc(db, 'users', 'anon'), publicProfile('anon')));
  });
});

describe('read', () => {
  beforeEach(async () => {
    await seedUser('resident-1', residentProfile('resident-1'));
  });

  test('owner reads self -> ALLOW', async () => {
    const db = userCtx('resident-1').firestore();
    await assertSucceeds(getDoc(doc(db, 'users', 'resident-1')));
  });

  test('other user reads profile -> DENY', async () => {
    const db = userCtx('resident-2').firestore();
    await assertFails(getDoc(doc(db, 'users', 'resident-1')));
  });

  test('admin reads profile -> ALLOW', async () => {
    const db = adminCtx().firestore();
    await assertSucceeds(getDoc(doc(db, 'users', 'resident-1')));
  });
});

describe('self update', () => {
  beforeEach(async () => {
    await seedUser('public-1', publicProfile('public-1'));
  });

  test('owner updates name and phone -> ALLOW', async () => {
    const db = userCtx('public-1').firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'users', 'public-1'), {
        name: 'Updated Name',
        phoneNumber: '+60123456789',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('owner cannot update role -> DENY', async () => {
    const db = userCtx('public-1').firestore();
    await assertFails(
      updateDoc(doc(db, 'users', 'public-1'), {
        role: 'admin',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('public user applies for resident access -> ALLOW', async () => {
    const db = userCtx('public-1').firestore();
    await assertSucceeds(
      updateDoc(doc(db, 'users', 'public-1'), {
        status: 'pending_approval',
        requestedRole: 'resident',
        requestedUnit: 'B-2-10',
        updatedAt: serverTimestamp(),
      }),
    );
  });
});

describe('management transitions', () => {
  beforeEach(async () => {
    await seedUser(
      'profile-admin',
      publicProfile('profile-admin', { role: 'admin', name: 'Profile Admin' }),
    );
    await seedUser('resident-applicant', residentProfile('resident-applicant'));
    await seedUser('admin-candidate', publicProfile('admin-candidate'));
  });

  test('profile-authorized admin reads and approves resident -> ALLOW', async () => {
    const db = profileAdminCtx().firestore();
    await assertSucceeds(
      getDoc(doc(db, 'users', 'resident-applicant')),
    );
    await assertSucceeds(
      updateDoc(doc(db, 'users', 'resident-applicant'), {
        role: 'resident',
        requestedRole: null,
        status: 'active',
        unitNumber: 'A-12-3',
        requestedUnit: null,
        approvedAt: serverTimestamp(),
        approvedBy: 'profile-admin',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('public user cannot approve a resident', async () => {
    const db = userCtx('admin-candidate').firestore();
    await assertFails(
      updateDoc(doc(db, 'users', 'resident-applicant'), {
        role: 'resident',
        requestedRole: null,
        status: 'active',
        unitNumber: 'A-12-3',
        requestedUnit: null,
        approvedAt: serverTimestamp(),
        approvedBy: 'admin-candidate',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('superadmin adds and removes an administrator -> ALLOW', async () => {
    const db = superadminCtx().firestore();
    const ref = doc(db, 'users', 'admin-candidate');

    await assertSucceeds(
      updateDoc(ref, {
        role: 'admin',
        approvedAt: serverTimestamp(),
        approvedBy: 'super-uid',
        adminRemovedAt: null,
        adminRemovedBy: null,
        updatedAt: serverTimestamp(),
      }),
    );
    await assertSucceeds(
      updateDoc(ref, {
        role: 'public',
        approvedAt: null,
        approvedBy: null,
        adminRemovedAt: serverTimestamp(),
        adminRemovedBy: 'super-uid',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  test('regular admin cannot add another administrator', async () => {
    const db = profileAdminCtx().firestore();
    await assertFails(
      updateDoc(doc(db, 'users', 'admin-candidate'), {
        role: 'admin',
        approvedAt: serverTimestamp(),
        approvedBy: 'profile-admin',
        adminRemovedAt: null,
        adminRemovedBy: null,
        updatedAt: serverTimestamp(),
      }),
    );
  });
});
