'use strict';

const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test, before, after, beforeEach } = require('node:test');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { firestoreEmulatorOptions } = require('./test_environment');
const {
  doc, setDoc, getDoc, deleteDoc, serverTimestamp,
} = require('firebase/firestore');

const PROJECT_ID = 'residential-management-a3fbf';
const RULES_PATH = join(__dirname, '..', 'firestore.rules');
const DEVICE_UID = 'Jk5TxhM3xCOj9dgrSm4F0Z92fq13';
const STATION_ID = 'q0mfxs4doqGSBxlAJVU3';

let testEnv;

const deviceDb = () => testEnv.authenticatedContext(DEVICE_UID).firestore();
const otherDeviceDb = () => testEnv.authenticatedContext('other-device').firestore();
const residentDb = () => testEnv.authenticatedContext('resident-uid', {
  email_verified: true,
}).firestore();

async function seedRegistration(uid = DEVICE_UID, stationId = STATION_ID) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'iot_devices', uid), {
      stationId,
      enabled: true,
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
  await seedRegistration();
});

test('registered ESP32 writes valid state to its station', async () => {
  await assertSucceeds(setDoc(
    doc(deviceDb(), 'ev_device_status', STATION_ID),
    {
      state: 'charging', adc: 4095, online: true, lastSeenAt: serverTimestamp(),
    },
  ));
});

test('prototype available state is accepted as an idle-compatible state', async () => {
  await assertSucceeds(setDoc(
    doc(deviceDb(), 'ev_device_status', STATION_ID),
    {
      state: 'available', adc: 0, online: true, lastSeenAt: serverTimestamp(),
    },
  ));
});

test('registered ESP32 cannot write another station', async () => {
  await assertFails(setDoc(
    doc(deviceDb(), 'ev_device_status', 'another-station'),
    { state: 'idle', adc: 0, online: true, lastSeenAt: serverTimestamp() },
  ));
});

test('unregistered device cannot write status', async () => {
  await assertFails(setDoc(
    doc(otherDeviceDb(), 'ev_device_status', STATION_ID),
    { state: 'idle', adc: 0, online: true, lastSeenAt: serverTimestamp() },
  ));
});

test('invalid state, ADC, or extra field is denied', async () => {
  const ref = doc(deviceDb(), 'ev_device_status', STATION_ID);
  await assertFails(setDoc(ref, {
    state: 'fault', adc: 0, online: true, lastSeenAt: serverTimestamp(),
  }));
  await assertFails(setDoc(ref, {
    state: 'idle', adc: 4096, online: true, lastSeenAt: serverTimestamp(),
  }));
  await assertFails(setDoc(ref, {
    state: 'idle', adc: 0, online: true,
    lastSeenAt: serverTimestamp(), userId: 'forged',
  }));
});

test('verified app user reads device state; anonymous device cannot', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'ev_device_status', STATION_ID), {
      state: 'idle', adc: 0, online: true, lastSeenAt: serverTimestamp(),
    });
  });

  await assertSucceeds(getDoc(
    doc(residentDb(), 'ev_device_status', STATION_ID),
  ));
  await assertFails(getDoc(
    doc(deviceDb(), 'ev_device_status', STATION_ID),
  ));
});

test('device cannot delete status or modify its registration', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'ev_device_status', STATION_ID), {
      state: 'idle', adc: 0, online: true, lastSeenAt: serverTimestamp(),
    });
  });

  await assertFails(deleteDoc(
    doc(deviceDb(), 'ev_device_status', STATION_ID),
  ));
  await assertFails(setDoc(
    doc(deviceDb(), 'iot_devices', DEVICE_UID),
    { stationId: 'another-station', enabled: true },
  ));
});
