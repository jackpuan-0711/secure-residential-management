import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/management_backend_service.dart';
import 'package:mobile_app/widgets/admin_management_section.dart';
import 'package:mocktail/mocktail.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

class _FakeAccountBackend extends ManagementBackendService {
  _FakeAccountBackend(this.accounts, this.candidate)
    : super(functions: _MockFirebaseFunctions());

  final ManagedAdminAccounts accounts;
  final ManagedAdminAccount candidate;
  String? addedEmail;

  @override
  Future<ManagedAdminAccounts> listAdminAccounts() async => accounts;

  @override
  Future<ManagedAdminAccount> findAdminCandidate({
    required String email,
  }) async {
    if (email != candidate.email) {
      throw const ManagementBackendException('Account not found.');
    }
    return candidate;
  }

  @override
  Future<void> addAdmin({required String email}) async {
    addedEmail = email;
  }
}

void main() {
  testWidgets('administrator picker searches verified accounts by email', (
    tester,
  ) async {
    final backend = _FakeAccountBackend(
      const ManagedAdminAccounts(admins: []),
      ManagedAdminAccount(
        uid: 'bob-uid',
        email: 'bob@example.com',
        name: 'Bob',
        createdAt: DateTime(2026, 2, 1),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminManagementSection(backend: backend)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bob@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Search'));
    await tester.pumpAndSettle();

    final result = find.widgetWithText(ListTile, 'bob@example.com');
    expect(result, findsOneWidget);

    await tester.tap(result);
    await tester.pumpAndSettle();
    expect(backend.addedEmail, 'bob@example.com');
  });
}
