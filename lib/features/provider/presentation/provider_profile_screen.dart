import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/styl_avatar.dart';

/// Provider profile — clean salon-app layout (Figma + Dribbble-style).
class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  static const _editBlue = Color(0xFF0085F0);
  static const _onlineGreen = Color(0xFF34C759);
  static const _muted = Color(0xFF8A8A8A);
  static const _rowIcon = Color(0xFF6B7280);

  ShopDto? _shop;
  var _loadingShop = true;
  var _toggling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadShop());
  }

  Future<void> _loadShop() async {
    setState(() => _loadingShop = true);
    try {
      final shops =
          await context.read<AuthController>().catalogApi.listMyShops();
      if (!mounted) return;
      final owned = shops.where((s) => s.isOwner == true).toList();
      setState(() {
        _shop = owned.isNotEmpty
            ? owned.first
            : (shops.isNotEmpty ? shops.first : null);
        _loadingShop = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingShop = false);
    }
  }

  Future<void> _toggleAvailable(bool value) async {
    if (_toggling) return;
    final auth = context.read<AuthController>();
    setState(() => _toggling = true);
    try {
      await auth.setAvailability(value);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update availability.')),
      );
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _logout() async {
    await context.read<AuthController>().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.welcome,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final name = user?.fullName?.trim().isNotEmpty == true
        ? user!.fullName!
        : 'Provider';
    final phone = user?.phone ?? '—';
    final email = (user?.email?.trim().isNotEmpty == true)
        ? user!.email!
        : 'Add your email';
    final available = user?.isAvailableNow ?? false;
    final online = user?.isOnline ?? false;
    final avatarUrl = user?.avatarUrl;
    final hasPhoto = avatarUrl != null && avatarUrl.trim().isNotEmpty;
    final shopName = _shop?.name ?? 'My salon';
    final shopAddress = _shop?.addressLine.isNotEmpty == true
        ? _shop!.addressLine
        : 'Add salon address';
    final shopImage = _shop?.imageUrl;

    return Material(
      color: Colors.white,
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.brandPrimary,
          onRefresh: () async {
            await context.read<AuthController>().reloadMe();
            await _loadShop();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
            children: [
              const Text(
                'Profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      StylAvatar(
                        size: 88,
                        imageUrl: avatarUrl,
                        name: name,
                        showAddBadge: !hasPhoto,
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            AppRoutes.providerPersonalInfo,
                          );
                        },
                      ),
                      Positioned(
                        top: 4,
                        right: 6,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: online ? _onlineGreen : const Color(0xFFBDBDBD),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 14,
                            color: _muted,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              AppRoutes.providerPersonalInfo,
                            );
                          },
                          child: Text(
                            hasPhoto ? 'Edit Profile' : 'Add photo & edit',
                            style: const TextStyle(
                              fontSize: 14,
                              color: _editBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.providerManageSalon,
                      arguments: _shop?.id,
                    );
                  },
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8E8E8)),
                    ),
                    child: SizedBox(
                      height: 96,
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(11),
                            ),
                            child: _loadingShop
                                ? Container(
                                    width: 112,
                                    color: AppColors.lightSurfaceVariant,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  )
                                : (shopImage != null &&
                                        shopImage.trim().isNotEmpty)
                                    ? Image.network(
                                        shopImage,
                                        width: 112,
                                        height: 96,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          width: 112,
                                          color: AppColors.lightSurfaceVariant,
                                          child: const Icon(
                                            Icons.storefront_outlined,
                                            color: _muted,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: 112,
                                        height: 96,
                                        color: AppColors.lightSurfaceVariant,
                                        child: const Icon(
                                          Icons.storefront_outlined,
                                          color: _muted,
                                        ),
                                      ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          shopName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: Color(0xFF111111),
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.edit_square,
                                        size: 18,
                                        color: _editBlue,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    shopAddress,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      height: 1.35,
                                      color: Color(0xFF575757),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 28, color: Color(0xFFF0F0F0)),
              _AvailableRow(
                value: available,
                busy: _toggling,
                onChanged: _toggleAvailable,
              ),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Contact',
                value: phone,
              ),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              _InfoRow(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                value: email,
                onTap: user?.hasEmail == true
                    ? null
                    : () {
                        Navigator.of(context).pushNamed(
                          AppRoutes.providerPersonalInfo,
                        );
                      },
              ),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: shopAddress,
              ),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              InkWell(
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.providerSettings);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    children: [
                      Icon(Icons.settings_outlined, size: 22, color: _rowIcon),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF575757),
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: _muted, size: 20),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              InkWell(
                onTap: _logout,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 22, color: _rowIcon),
                      SizedBox(width: 14),
                      Text(
                        'Log out',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF575757),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailableRow extends StatelessWidget {
  const _AvailableRow({
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(
            Icons.event_available_outlined,
            size: 22,
            color: Color(0xFF6B7280),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Available Now',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111111),
              ),
            ),
          ),
          if (busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch.adaptive(
              value: value,
              activeTrackColor: const Color(0xFF34C759),
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: const Color(0xFF6B7280)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8A8A8A),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: value == 'Add your email'
                          ? AppColors.brandAccent
                          : const Color(0xFF111111),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFB0B0B0),
              ),
          ],
        ),
      ),
    );
  }
}
