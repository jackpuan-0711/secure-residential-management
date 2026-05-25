import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../theme/app_icons.dart';
import '../screens/home_screen.dart';
import '../screens/feedback_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/profile_screen.dart';

/// Logical tab slots. Defines the canonical order in the nav bar.
enum _Tab { home, feedback, settings, profile }

/// The persistent authenticated shell for all active users.
///
/// Provides a bottom NavigationBar with 3 or 4 visible tabs:
///   Public  → Home | Settings | Profile
///   Resident → Home | Feedback | Settings | Profile
///   Admin   → Home | Settings | Profile
class MainScaffold extends StatefulWidget {
  final UserRole role;
  final AppUser user;

  const MainScaffold({super.key, required this.role, required this.user});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  List<_Tab> get _visibleTabs => [
        _Tab.home,
        if (widget.role == UserRole.resident) _Tab.feedback,
        _Tab.settings,
        _Tab.profile,
      ];

  @override
  void didUpdateWidget(MainScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      setState(() => _selectedIndex = 0);
    }
  }

  Widget _bodyFor(_Tab tab) => switch (tab) {
        _Tab.home => HomeScreen(user: widget.user),
        _Tab.feedback => const FeedbackScreen(),
        _Tab.settings => const SettingsScreen(),
        _Tab.profile => ProfileScreen(user: widget.user),
      };

  NavigationDestination _destinationFor(_Tab tab) => switch (tab) {
        _Tab.home => const NavigationDestination(
            icon: Icon(AppIcons.homeOutlined),
            selectedIcon: Icon(AppIcons.home),
            label: 'Home',
          ),
        _Tab.feedback => const NavigationDestination(
            icon: Icon(AppIcons.feedbackOutlined),
            selectedIcon: Icon(AppIcons.feedback),
            label: 'Feedback',
          ),
        _Tab.settings => const NavigationDestination(
            icon: Icon(AppIcons.settingsOutlined),
            selectedIcon: Icon(AppIcons.settings),
            label: 'Settings',
          ),
        _Tab.profile => const NavigationDestination(
            icon: Icon(AppIcons.profileOutlined),
            selectedIcon: Icon(AppIcons.profile),
            label: 'Profile',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final tabs = _visibleTabs;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: tabs.map(_bodyFor).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: tabs.map(_destinationFor).toList(),
      ),
    );
  }
}
