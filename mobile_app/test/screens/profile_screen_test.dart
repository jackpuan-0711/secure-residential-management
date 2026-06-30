import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/screens/profile_screen.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/user_repository.dart';

void main() {
  testWidgets('profile dialog saves a phone number without a route crash', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final repository = UserRepository(firestore: firestore);
    await repository.createPublicProfile(
      uid: 'user-1',
      email: 'user@example.com',
      name: 'Test User',
    );
    final user = (await repository.getUserProfile('user-1'))!;
    final auth = AuthService.withInstance(
      MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: user.uid, email: user.email),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ProfileScreen(
          user: user,
          authService: auth,
          userRepository: repository,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(1), '012-345 6789');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('012-345 6789'), findsOneWidget);
    expect(
      (await repository.getUserProfile(user.uid))!.phoneNumber,
      '012-345 6789',
    );
  });
}
