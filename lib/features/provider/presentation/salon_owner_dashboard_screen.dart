import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/notifications/notification_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/styl_avatar.dart';
import 'provider_clients_screen.dart';

const _accent = Color(0xFF6B5CE7);
const _ink = Color(0xFF003E6F);
const _muted = Color(0xFF5B6B7C);

/// Salon owner hub — menu matching product “Salon Owner Dashboard”.
class SalonOwnerDashboardScreen extends StatefulWidget {
  const SalonOwnerDashboardScreen({super.key});

  @override
  State<SalonOwnerDashboardScreen> createState() =>
      _SalonOwnerDashboardScreenState();
}

class _SalonOwnerDashboardScreenState extends State<SalonOwnerDashboardScreen> {
  ShopDto? _shop;
  var _loading = true;
  String? _selectedId = 'dashboard';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Arriving at the owner hub means setup is finished — never resume wizard.
      final store = SessionStore();
      await store.setOwnerOnboardingComplete(true);
      await store.clearProviderSetup();
      await _load();
      if (mounted) {
        context.read<NotificationController>().refresh();
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthController>();
    try {
      final shops = await auth.catalogApi.listMyShops();
      if (!mounted) return;
      setState(() {
        _shop = shops.where((s) => s.isOwner == true).firstOrNull ??
            (shops.isNotEmpty ? shops.first : null);
        _loading = false;
      });
    } on ApiException catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _open(String id, Future<void> Function() action) async {
    setState(() => _selectedId = id);
    await action();
    if (mounted) setState(() => _selectedId = 'dashboard');
  }

  Future<void> _switchToCustomer() async {
    await SessionStore().setPreferCustomerView(true);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.customerShell,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final salonName = _shop?.name.trim().isNotEmpty == true
        ? _shop!.name
        : (user?.fullName?.trim().isNotEmpty == true
            ? "${user!.fullName!.trim()}'s Salon"
            : 'My Salon');
    final logoUrl = (_shop?.imageUrls.length ?? 0) > 1
        ? _shop!.imageUrls[1]
        : (_shop?.imageUrls.isNotEmpty == true ? _shop!.imageUrls.first : null);
    final avatarUrl = logoUrl ?? user?.avatarUrl;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                    child: Row(
                      children: [
                        const Text(
                          'STYL',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () async {
                            final inbox =
                                context.read<NotificationController>();
                            await Navigator.of(context).pushNamed(
                              AppRoutes.notifications,
                            );
                            if (!mounted) return;
                            inbox.refresh();
                          },
                          icon: Badge(
                            isLabelVisible: context
                                    .watch<NotificationController>()
                                    .unreadCount >
                                0,
                            smallSize: 8,
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: _ink,
                            ),
                          ),
                        ),
                        StylAvatar(
                          size: 36,
                          name: user?.fullName,
                          imageUrl: user?.avatarUrl,
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              AppRoutes.providerPersonalInfo,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        StylAvatar(
                          size: 48,
                          name: salonName,
                          imageUrl: avatarUrl,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                salonName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Owner • Salon',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [
                        _MenuItem(
                          id: 'dashboard',
                          selectedId: _selectedId,
                          icon: Icons.home_outlined,
                          label: 'Dashboard',
                          onTap: () => setState(() => _selectedId = 'dashboard'),
                        ),
                        _MenuItem(
                          id: 'manage_salon',
                          selectedId: _selectedId,
                          icon: Icons.storefront_outlined,
                          label: 'Manage Salon',
                          onTap: () => _open('manage_salon', () async {
                            await Navigator.of(context).pushNamed(
                              AppRoutes.providerManageSalon,
                              arguments: _shop?.id,
                            );
                            await _load();
                          }),
                        ),
                        _MenuItem(
                          id: 'services',
                          selectedId: _selectedId,
                          icon: Icons.content_cut_outlined,
                          label: 'Manage Services',
                          onTap: () => _open('services', () async {
                            await Navigator.of(context).pushNamed(
                              AppRoutes.providerServices,
                              arguments: ProviderServicesArgs(
                                shopId: _shop?.id,
                              ),
                            );
                          }),
                        ),
                        _MenuItem(
                          id: 'bookings',
                          selectedId: _selectedId,
                          icon: Icons.calendar_month_outlined,
                          label: 'Bookings',
                          onTap: () => _open('bookings', () async {
                            await Navigator.of(context).pushNamed(
                              AppRoutes.providerAppointmentsList,
                            );
                          }),
                        ),
                        _MenuItem(
                          id: 'team',
                          selectedId: _selectedId,
                          icon: Icons.groups_outlined,
                          label: 'Team',
                          onTap: () => _open('team', () async {
                            await Navigator.of(context).pushNamed(
                              AppRoutes.providerSalonTeam,
                              arguments: SalonSetupArgs(shopId: _shop?.id),
                            );
                            await _load();
                          }),
                        ),
                        _MenuItem(
                          id: 'customers',
                          selectedId: _selectedId,
                          icon: Icons.person_outline_rounded,
                          label: 'Customers',
                          onTap: () => _open('customers', () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ProviderClientsScreen(),
                              ),
                            );
                          }),
                        ),
                        _MenuItem(
                          id: 'messages',
                          selectedId: _selectedId,
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Messages',
                          onTap: () => _open('messages', () async {
                            await Navigator.of(context).pushNamed(
                              AppRoutes.notifications,
                            );
                          }),
                        ),
                        _MenuItem(
                          id: 'analytics',
                          selectedId: _selectedId,
                          icon: Icons.bar_chart_rounded,
                          label: 'Analytics',
                          onTap: () => _open('analytics', () async {
                            await Navigator.of(context).pushNamed(
                              AppRoutes.providerAnalytics,
                            );
                          }),
                        ),
                        _MenuItem(
                          id: 'settings',
                          selectedId: _selectedId,
                          icon: Icons.settings_outlined,
                          label: 'Settings',
                          onTap: () => _open('settings', () async {
                            await Navigator.of(context).pushNamed(
                              AppRoutes.providerSettings,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: OutlinedButton(
                      onPressed: _switchToCustomer,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _ink,
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sync_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Switch to Customer View',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.id,
    required this.selectedId,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final String id;
  final String? selectedId;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = selectedId == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? _accent : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: selected ? Colors.white : _ink,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : _ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
