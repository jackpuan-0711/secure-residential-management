import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Local Firebase emulator wiring.
///
/// Enable with:
/// --dart-define=USE_FIREBASE_EMULATORS=true
/// --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
abstract final class FirebaseEmulatorConfig {
  static const bool useEmulators = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
  );
  static const String host = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );

  static Future<void> configure() async {
    if (!useEmulators) return;

    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).useFunctionsEmulator(host, 5001);
  }
}
