import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/widgets/styl_avatar.dart';
import '../../customer/presentation/looks_ui.dart';
import 'widgets/provider_looks_chrome.dart';

/// Looksy More tab — account, salon, help.
class ProviderMoreScreen extends StatefulWidget {
  const ProviderMoreScreen({super.key});

  @override
  State<ProviderMoreScreen> createState() => _ProviderMoreScreenState();
}

class _ProviderMoreScreenState extends State<ProviderMoreScreen> {
  ShopDto? _shop;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final shops =
          await context.read<AuthController>().catalogApi.listMyShops();
      if (!mounted) return;
      setState(() {
        _shop = shops.where((s) => s.isOwner == true).firstOrNull ??
            (shops.isNotEmpty ? shops.first : null);
      });
    } catch (_) {}
  }

  Future<void> _logout() async {
    await context.read<AuthController>().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.welcome,
      (route) => false,
    );
  }

  void _open(String route, [Object? args]) {
    Navigator.of(context).pushNamed(route, arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final name = user?.fullName?.trim().isNotEmpty == true
        ? user!.fullName!
        : 'Professional';

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            const Text(
              'More',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: LooksUi.ink,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 18),
            Material(
              color: LooksUi.purpleSoft,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _open(AppRoutes.providerPersonalInfo),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      StylAvatar(
                        size: 56,
                        imageUrl: user?.avatarUrl,
                        name: name,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: LooksUi.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _shop?.name ?? 'Service professional',
                              style: const TextStyle(
                                fontSize: 13,
                                color: LooksUi.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: LooksUi.navGray,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            ProviderLooksMenuCard(
              children: [
                ProviderLooksMenuRow(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  onTap: () => _open(AppRoutes.notifications),
                ),
                ProviderLooksMenuRow(
                  icon: Icons.storefront_outlined,
                  label: 'Manage salon',
                  onTap: () => _open(AppRoutes.providerManageSalon, _shop?.id),
                ),
                ProviderLooksMenuRow(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () => _open(AppRoutes.providerSettings),
                ),
                ProviderLooksMenuRow(
                  icon: Icons.help_outline_rounded,
                  label: 'Help',
                  onTap: () => _open(AppRoutes.providerHelp),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ProviderLooksMenuCard(
              children: [
                ProviderLooksMenuRow(
                  icon: Icons.logout_rounded,
                  label: 'Log out',
                  onTap: _logout,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
