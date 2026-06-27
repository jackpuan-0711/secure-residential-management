'use strict';

function firestoreEmulatorOptions(rules) {
  const endpoint = process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
  const url = new URL(`http://${endpoint}`);
  return {
    host: url.hostname,
    port: Number(url.port || 8080),
    rules,
  };
}

module.exports = { firestoreEmulatorOptions };
