import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/complete_profile_screen.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/user_repository.dart';
import 'package:mobile_app/utils/validators.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late AuthService authService;
  late UserRepository userRepository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: 'test-uid',
        email: 'test@example.com',
        displayName: 'Test User',
        isEmailVerified: true,
      ),
    );
    authService = AuthService.withInstance(mockAuth);
    userRepository = UserRepository(firestore: fakeFirestore);
  });

  Widget buildScreen() => MaterialApp(
        home: CompleteProfileScreen(
          authService: authService,
          userRepository: userRepository,
        ),
      );

  group('CompleteProfileScreen', () {
    testWidgets('renders email from AuthService current user',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      expect(find.text('test@example.com'), findsOneWidget);
    });

    testWidgets('public radio is selected by default; unit field not visible',
        (tester) async {
      await tester.pumpWidget(buildScreen());

      // Public is default — unit field must not be visible
      expect(find.byKey(const Key('unitNumberField')), findsNothing);

      // Resident radio exists and is tappable (not the active selection)
      expect(find.text("I'm a resident"), findsOneWidget);
    });

    testWidgets('selecting resident radio reveals the unit field',
        (tester) async {
      await tester.pumpWidget(buildScreen());

      await tester.tap(find.text("I'm a resident"));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unitNumberField')), findsOneWidget);
    });

    testWidgets('resident branch with empty unit shows validation error',
        (tester) async {
      await tester.pumpWidget(buildScreen());

      await tester.tap(find.text("I'm a resident"));
      await tester.pumpAndSettle();

      // Leave unit field empty and submit
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Unit number is required'), findsOneWidget);
    });

    testWidgets(
        'resident branch with out-of-range unit (A-99-99) shows validation error',
        (tester) async {
      await tester.pumpWidget(buildScreen());

      await tester.tap(find.text("I'm a resident"));
      await tester.pumpAndSettle();

      // Floor 99 / unit 99 are out of range (max 30 / 20). The input
      // formatter uppercases but can't fix an out-of-range value, so the
      // shared validator rejects it.
      await tester.enterText(
          find.byKey(const Key('unitNumberField')), 'A-99-99');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text(unitNumberError), findsOneWidget);
    });

    testWidgets(
        'resident branch with A-12-3 succeeds and calls createUserProfile',
        (tester) async {
      await tester.pumpWidget(buildScreen());

      await tester.tap(find.text("I'm a resident"));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('unitNumberField')), 'A-12-3');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Verify the Firestore doc was created with resident role
      final doc =
          await fakeFirestore.collection('users').doc('test-uid').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['role'], 'resident');
      expect(doc.data()!['status'], 'pending_approval');
      expect(doc.data()!['requestedUnit'], 'A-12-3');
    });

    testWidgets(
        'public branch calls createPublicProfile (NOT createUserProfile)',
        (tester) async {
      await tester.pumpWidget(buildScreen());

      // Public radio is already selected by default — submit directly
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final doc =
          await fakeFirestore.collection('users').doc('test-uid').get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['role'], 'public');
      expect(doc.data()!['status'], 'active');
    });

    testWidgets(
        'SECURITY: unitNumber is null in created doc for both branches',
        (tester) async {
      // --- Resident branch ---
      await tester.pumpWidget(buildScreen());

      await tester.tap(find.text("I'm a resident"));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('unitNumberField')), 'B-5-10');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      var doc =
          await fakeFirestore.collection('users').doc('test-uid').get();
      expect(doc.data()!['unitNumber'], isNull,
          reason: 'Resident signup must never populate verified unitNumber');

      // --- Public branch (fresh firestore) ---
      fakeFirestore = FakeFirebaseFirestore();
      userRepository = UserRepository(firestore: fakeFirestore);

      // Use a unique key so Flutter creates a new State (forces initState to
      // run again with the updated userRepository, rather than reusing the
      // existing State via didUpdateWidget).
      await tester.pumpWidget(MaterialApp(
        home: CompleteProfileScreen(
          key: const Key('public-branch'),
          authService: authService,
          userRepository: userRepository,
        ),
      ));

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      doc = await fakeFirestore.collection('users').doc('test-uid').get();
      expect(doc.data()!['unitNumber'], isNull,
          reason: 'Public signup must never populate verified unitNumber');
    });
  });
}
