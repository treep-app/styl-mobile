import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/styl_primary_button.dart';

const _accent = Color(0xFF4F6BFF);
const _ink = Color(0xFF003E6F);
const _muted = Color(0xFF8B93A7);
const _iconBg = Color(0xFFEEF0FF);
const _border = Color(0xFFE8EAF0);

/// Salon owner hub — menu of salon management functions.
class ManageSalonScreen extends StatefulWidget {
  const ManageSalonScreen({super.key, this.shopId});

  final String? shopId;

  @override
  State<ManageSalonScreen> createState() => _ManageSalonScreenState();
}

class _ManageSalonScreenState extends State<ManageSalonScreen> {
  ShopDto? _shop;
  var _loading = true;
  var _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<AuthController>().catalogApi;
      final mine = await api.listMyShops();
      if (!mounted) return;

      ShopDto? shop;
      if (widget.shopId != null) {
        for (final s in mine) {
          if (s.id == widget.shopId) {
            shop = s;
            break;
          }
        }
        shop ??= await api.getShop(widget.shopId!);
      } else {
        shop = mine.where((s) => s.isOwner == true).firstOrNull ??
            (mine.isNotEmpty ? mine.first : null);
      }

      setState(() {
        _shop = shop;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _createSalon() async {
    if (_creating) return;
    setState(() => _creating = true);
    final auth = context.read<AuthController>();
    try {
      final name = (auth.user?.fullName ?? '').trim();
      final created = await auth.catalogApi.createShop({
        'name': name.isEmpty ? 'My Salon' : "$name's Salon",
        'addressLine': 'Address to be added',
        if ((auth.user?.phone ?? '').trim().isNotEmpty)
          'phone': auth.user!.phone,
      });
      if (!mounted) return;
      setState(() {
        _shop = created;
        _creating = false;
      });
      await Navigator.of(context).pushNamed(
        AppRoutes.providerSalonProfile,
        arguments: SalonProfileArgs(shopId: created.id),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }

  Future<void> _open(String route, {Object? arguments}) async {
    await Navigator.of(context).pushNamed(route, arguments: arguments);
    if (mounted) await _load();
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: AppColors.brandPrimary,
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text(
                          'Manage Salon',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Keep your salon information up to date.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: _muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(_error!, textAlign: TextAlign.center),
                              ),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _shop == null
                          ? _EmptySalon(
                              creating: _creating,
                              onCreate: _createSalon,
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _border),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    children: [
                                      _MenuRow(
                                        icon: Icons.storefront_outlined,
                                        title: 'Salon Profile',
                                        subtitle: 'Name, description, photos',
                                        onTap: () => _open(
                                          AppRoutes.providerSalonProfile,
                                          arguments: SalonProfileArgs(
                                            shopId: _shop!.id,
                                          ),
                                        ),
                                      ),
                                      const _MenuDivider(),
                                      _MenuRow(
                                        icon: Icons.badge_outlined,
                                        title: 'Business Details',
                                        subtitle: 'Contact information',
                                        onTap: () => _open(
                                          AppRoutes.providerSalonProfile,
                                          arguments: SalonProfileArgs(
                                            shopId: _shop!.id,
                                          ),
                                        ),
                                      ),
                                      const _MenuDivider(),
                                      _MenuRow(
                                        icon: Icons.location_on_outlined,
                                        title: 'Location',
                                        subtitle: 'Address and map',
                                        onTap: () => _open(
                                          AppRoutes.providerSalonProfile,
                                          arguments: SalonProfileArgs(
                                            shopId: _shop!.id,
                                          ),
                                        ),
                                      ),
                                      const _MenuDivider(),
                                      _MenuRow(
                                        icon: Icons.schedule_outlined,
                                        title: 'Opening Hours',
                                        subtitle: 'Set your working hours',
                                        onTap: () => _open(
                                          AppRoutes.providerSalonHours,
                                          arguments: SalonSetupArgs(
                                            shopId: _shop!.id,
                                          ),
                                        ),
                                      ),
                                      const _MenuDivider(),
                                      _MenuRow(
                                        icon: Icons.groups_outlined,
                                        title: 'Team',
                                        subtitle: 'Manage your professionals',
                                        onTap: () => _open(
                                          AppRoutes.providerSalonTeam,
                                          arguments: SalonSetupArgs(
                                            shopId: _shop!.id,
                                          ),
                                        ),
                                      ),
                                      const _MenuDivider(),
                                      _MenuRow(
                                        icon: Icons.verified_user_outlined,
                                        title: 'Booking Settings',
                                        subtitle:
                                            'Policies, notices and deposits',
                                        onTap: () => _open(
                                          AppRoutes.providerSalonBookingSettings,
                                          arguments: SalonSetupArgs(
                                            shopId: _shop!.id,
                                          ),
                                        ),
                                      ),
                                      const _MenuDivider(),
                                      _MenuRow(
                                        icon: Icons.account_balance_wallet_outlined,
                                        title: 'Payments & Payouts',
                                        subtitle: 'Manage payments',
                                        onTap: () =>
                                            _comingSoon('Payments & Payouts'),
                                      ),
                                      const _MenuDivider(),
                                      _MenuRow(
                                        icon: Icons.verified_outlined,
                                        title: 'Verification',
                                        subtitle: _shop?.isVerified == true
                                            ? 'STYL Verified'
                                            : 'Get verified on STYL',
                                        onTap: () => _open(
                                          AppRoutes.providerSalonVerification,
                                          arguments: SalonSetupArgs(
                                            shopId: _shop!.id,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySalon extends StatelessWidget {
  const _EmptySalon({
    required this.creating,
    required this.onCreate,
  });

  final bool creating;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.storefront_outlined, size: 48, color: _muted),
          const SizedBox(height: 14),
          const Text(
            'No salon yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your salon to manage profile, hours, team and bookings.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _muted, height: 1.4),
          ),
          const SizedBox(height: 22),
          StylPrimaryButton(
            label: creating ? 'Creating…' : 'Create salon',
            onPressed: creating ? null : onCreate,
          ),
        ],
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 70,
      color: Color(0xFFF0F1F5),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFFB0B6C3),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
