import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../customer/presentation/looks_ui.dart';
import 'provider_calendar_screen.dart';
import 'provider_clients_screen.dart';
import 'provider_home_screen.dart';
import 'provider_more_screen.dart';
import 'provider_shell_tabs.dart';

/// Service provider root — Home | Calendar | Clients | More.
class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key});

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  final _calendarKey = GlobalKey<ProviderCalendarScreenState>();
  final _clientsKey = GlobalKey<ProviderClientsScreenState>();
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    ProviderShellTabs.index.value = ProviderShellTabs.home;
    ProviderShellTabs.index.addListener(_onTab);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureBarber());
    _presenceTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      if (!mounted) return;
      try {
        await context.read<AuthController>().reloadMe();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    ProviderShellTabs.index.removeListener(_onTab);
    _presenceTimer?.cancel();
    super.dispose();
  }

  void _onTab() {
    if (!mounted) return;
    setState(() {});
    final i = ProviderShellTabs.index.value;
    if (i == ProviderShellTabs.calendar) {
      _calendarKey.currentState?.reload();
    }
    if (i == ProviderShellTabs.clients) {
      _clientsKey.currentState?.reload();
    }
  }

  void _ensureBarber() {
    final auth = context.read<AuthController>();
    if (auth.user != null && !auth.user!.isBarber) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.customerShell,
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This account is a customer. Choose Service Provider and log in again for the barber home.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = ProviderShellTabs.index.value;

    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: index,
        children: [
          const ProviderHomeScreen(),
          ProviderCalendarScreen(key: _calendarKey),
          ProviderClientsScreen(key: _clientsKey),
          const ProviderMoreScreen(),
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
                  selected: index == ProviderShellTabs.home,
                  icon: Icons.home_rounded,
                  outlined: Icons.home_outlined,
                  label: 'Home',
                  onTap: () => ProviderShellTabs.goTo(ProviderShellTabs.home),
                ),
                _NavItem(
                  selected: index == ProviderShellTabs.calendar,
                  icon: Icons.calendar_month_rounded,
                  outlined: Icons.calendar_month_outlined,
                  label: 'Calendar',
                  onTap: () =>
                      ProviderShellTabs.goTo(ProviderShellTabs.calendar),
                ),
                _NavItem(
                  selected: index == ProviderShellTabs.clients,
                  icon: Icons.people_rounded,
                  outlined: Icons.people_outline_rounded,
                  label: 'Clients',
                  onTap: () =>
                      ProviderShellTabs.goTo(ProviderShellTabs.clients),
                ),
                _NavItem(
                  selected: index == ProviderShellTabs.more,
                  icon: Icons.menu_rounded,
                  outlined: Icons.menu_rounded,
                  label: 'More',
                  onTap: () => ProviderShellTabs.goTo(ProviderShellTabs.more),
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
