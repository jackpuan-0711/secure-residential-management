import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/user_role.dart';
import 'package:mobile_app/services/auth_service.dart';

void main() {
  test('sign-in token event resolves the admin claim once', () async {
    final auth = MockFirebaseAuth(
      signedIn: false,
      mockUser: MockUser(
        uid: 'admin-1',
        email: 'admin@example.com',
        isEmailVerified: true,
        customClaim: {'role': 'admin'},
      ),
    );
    final service = AuthService.withInstance(auth);
    final routedIdentity = service.authStateChanges
        .firstWhere((identity) => identity != null)
        .timeout(const Duration(seconds: 2));

    await service.signIn(email: 'admin@example.com', password: 'password');
    final identity = await routedIdentity;

    expect(identity!.uid, 'admin-1');
    expect(identity.role, UserRole.admin);
  });
}
