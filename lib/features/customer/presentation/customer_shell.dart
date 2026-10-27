import 'package:flutter/material.dart';

import 'appointments_screen.dart';
import 'customer_home_screen.dart';
import 'customer_shell_tabs.dart';
import 'explore_screen.dart';
import 'looks_ui.dart';
import 'profile_screen.dart';
import 'saved_screen.dart';

/// Customer root — Home, Explore, Bookings, Saved, Profile.
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  final _appointmentsKey = GlobalKey<AppointmentsScreenState>();
  final _savedKey = GlobalKey<SavedScreenState>();

  @override
  void initState() {
    super.initState();
    CustomerShellTabs.index.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    CustomerShellTabs.index.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;
    setState(() {});
    if (CustomerShellTabs.index.value == CustomerShellTabs.appointments) {
      _appointmentsKey.currentState?.reload();
    }
    if (CustomerShellTabs.index.value == CustomerShellTabs.saved) {
      _savedKey.currentState?.reload();
    }
  }

  void _select(int index) {
    CustomerShellTabs.goTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final index = CustomerShellTabs.index.value;

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: index,
        children: [
          const CustomerHomeScreen(),
          const ExploreScreen(),
          AppointmentsScreen(key: _appointmentsKey),
          SavedScreen(key: _savedKey),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                _NavItem(
                  selected: index == CustomerShellTabs.home,
                  icon: Icons.home_rounded,
                  outlined: Icons.home_outlined,
                  label: 'Home',
                  onTap: () => _select(CustomerShellTabs.home),
                ),
                _NavItem(
                  selected: index == CustomerShellTabs.explore,
                  icon: Icons.search_rounded,
                  outlined: Icons.search_rounded,
                  label: 'Explore',
                  onTap: () => _select(CustomerShellTabs.explore),
                ),
                _NavItem(
                  selected: index == CustomerShellTabs.appointments,
                  icon: Icons.calendar_month_rounded,
                  outlined: Icons.calendar_month_outlined,
                  label: 'Bookings',
                  onTap: () => _select(CustomerShellTabs.appointments),
                ),
                _NavItem(
                  selected: index == CustomerShellTabs.saved,
                  icon: Icons.favorite_rounded,
                  outlined: Icons.favorite_border_rounded,
                  label: 'Saved',
                  onTap: () => _select(CustomerShellTabs.saved),
                ),
                _NavItem(
                  selected: index == CustomerShellTabs.profile,
                  icon: Icons.person_rounded,
                  outlined: Icons.person_outline,
                  label: 'Profile',
                  onTap: () => _select(CustomerShellTabs.profile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.outlined,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final IconData outlined;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? LooksUi.purple : LooksUi.navGray;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? icon : outlined, size: 24, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
