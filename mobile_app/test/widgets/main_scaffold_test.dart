import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/l10n/app_localizations.dart';
import 'package:mobile_app/models/app_user.dart';
import 'package:mobile_app/services/app_settings.dart';
import 'package:mobile_app/theme/app_theme.dart';
import 'package:mobile_app/widgets/main_scaffold.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

// A minimal AppUser that satisfies the MainScaffold's needs.
// The scaffold only reads the `role` to determine tab visibility.
final _mockUser = AppUser(
  uid: 'test-uid',
  email: 'test@test.com',
  name: 'Test User',
  role: UserRole.public, // Role is overridden by the test cases
  status: UserStatus.active,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

// ── Helpers ────────────────────────────────────────────────────────────────

// MainScaffold builds SettingsScreen inside its IndexedStack, which reads
// AppLocalizations and SettingsScope. Tests must therefore provide both the
// localization delegates and a SettingsScope. AppSettings is backed by a
// mocked SharedPreferences (set up per test below).
late AppSettings _settings;

Widget _scaffold(UserRole role) => SettingsScope(
      settings: _settings,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MainScaffold(role: role, user: _mockUser.copyWith(role: role)),
      ),
    );

/// Finds text that is a direct descendant of the NavigationBar
Finder _navLabel(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _settings = await AppSettings.load();
  });

  group('tab visibility — public role', () {
    testWidgets('shows exactly 3 destinations', (tester) async {
      await tester.pumpWidget(_scaffold(UserRole.public));
      expect(find.byType(NavigationBar), findsOneWidget);
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.destinations.length, 3);
    });

    testWidgets('shows Home, Settings, Profile', (tester) async {
      await tester.pumpWidget(_scaffold(UserRole.public));
      expect(_navLabel('Home'), findsOneWidget);
      expect(_navLabel('Settings'), findsOneWidget);
      expect(_navLabel('Profile'), findsOneWidget);
    });

    testWidgets('does NOT show Feedback tab', (tester) async {
      await tester.pumpWidget(_scaffold(UserRole.public));
      expect(_navLabel('Feedback'), findsNothing);
    });
  });

  group('tab visibility — resident role', () {
    testWidgets('shows exactly 4 destinations', (tester) async {
      await tester.pumpWidget(_scaffold(UserRole.resident));
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.destinations.length, 4);
    });

    testWidgets('shows Home, Feedback, Settings, Profile', (tester) async {
      await tester.pumpWidget(_scaffold(UserRole.resident));
      expect(_navLabel('Home'), findsOneWidget);
      expect(_navLabel('Feedback'), findsOneWidget);
      expect(_navLabel('Settings'), findsOneWidget);
      expect(_navLabel('Profile'), findsOneWidget);
    });
  });

  group('tab visibility — admin role', () {
    testWidgets('shows exactly 3 destinations', (tester) async {
      await tester.pumpWidget(_scaffold(UserRole.admin));
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.destinations.length, 3);
    });

    testWidgets('does NOT show Feedback tab', (tester) async {
      await tester.pumpWidget(_scaffold(UserRole.admin));
      expect(_navLabel('Feedback'), findsNothing);
    });
  });

  group('index mapping', () {
    testWidgets('public: Settings is index 1, Profile is 2', (tester) async {
      await tester.pumpWidget(_scaffold(UserRole.public));
      await tester.tap(_navLabel('Settings'));
      await tester.pumpAndSettle();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
      await tester.tap(_navLabel('Profile'));
      await tester.pumpAndSettle();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 2);
    });

    testWidgets('resident: Feedback is 1, Settings is 2, Profile is 3',
        (tester) async {
      await tester.pumpWidget(_scaffold(UserRole.resident));
      await tester.tap(_navLabel('Feedback'));
      await tester.pumpAndSettle();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
      await tester.tap(_navLabel('Settings'));
      await tester.pumpAndSettle();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 2);
      await tester.tap(_navLabel('Profile'));
      await tester.pumpAndSettle();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 3);
    });
  });

  group('tab switching', () {
    testWidgets('updates IndexedStack index and can return to Home',
        (tester) async {
      await tester.pumpWidget(_scaffold(UserRole.resident));
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);
      await tester.tap(_navLabel('Settings'));
      await tester.pumpAndSettle();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 2);
      await tester.tap(_navLabel('Home'));
      await tester.pumpAndSettle();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);
    });

    testWidgets('role change resets selected index to 0', (tester) async {
      UserRole role = UserRole.resident;
      late StateSetter outerSetState;

      await tester.pumpWidget(
        SettingsScope(
          settings: _settings,
          child: MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StatefulBuilder(
              builder: (context, setState) {
                outerSetState = setState;
                return MainScaffold(
                    role: role, user: _mockUser.copyWith(role: role));
              },
            ),
          ),
        ),
      );

      await tester.tap(_navLabel('Feedback'));
      await tester.pumpAndSettle();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);

      outerSetState(() => role = UserRole.public);
      await tester.pumpAndSettle();

      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.destinations.length, 3);
    });
  });
}
