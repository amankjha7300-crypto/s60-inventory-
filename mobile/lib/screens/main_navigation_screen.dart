import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'dashboard_screen.dart';
import 'students_screen.dart';
import 'saved_events_screen.dart';
import 'distribution_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(onTabChange: (idx) => setState(() => _currentIndex = idx)),
      const StudentsScreen(),
      const SavedEventsScreen(),
      const DistributionScreen(),
      const SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.primaryOrange.withOpacity(0.18),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: AppColors.primaryNavy),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.primaryOrange),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined, color: AppColors.primaryNavy),
            selectedIcon: Icon(Icons.school, color: AppColors.primaryOrange),
            label: 'Students',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined, color: AppColors.primaryNavy),
            selectedIcon: Icon(Icons.event, color: AppColors.primaryOrange),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_giftcard_outlined, color: AppColors.primaryNavy),
            selectedIcon: Icon(Icons.card_giftcard, color: AppColors.primaryOrange),
            label: 'Rewards',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined, color: AppColors.primaryNavy),
            selectedIcon: Icon(Icons.tune, color: AppColors.primaryOrange),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
