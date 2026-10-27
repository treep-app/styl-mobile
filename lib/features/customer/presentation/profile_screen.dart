import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_models.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/styl_avatar.dart';
import 'payments_screen.dart';

/// Customer profile — clean salon-app layout matching provider polish.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _editBlue = Color(0xFF0085F0);
  static const _muted = Color(0xFF4A5568);
  static const _rowIcon = Color(0xFF6B7280);

  WalletDto? _wallet;
  var _loadingWallet = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWallet());
  }

  Future<void> _loadWallet() async {
    setState(() => _loadingWallet = true);
    try {
      final wallet =
          await context.read<AuthController>().paymentsApi.wallet();
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _loadingWallet = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingWallet = false);
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
        : 'Customer';
    final phone = user?.phone ?? '—';
    final email = (user?.email?.trim().isNotEmpty == true)
        ? user!.email!
        : 'Add your email';
    final avatarUrl = user?.avatarUrl;
    final balance = _wallet?.balanceLabel ?? '£0.00';
    final hasPhoto = avatarUrl != null && avatarUrl.trim().isNotEmpty;

    return Material(
      color: Colors.white,
      child: SafeArea(
        child: RefreshIndicator(
          color: AppColors.brandPrimary,
          onRefresh: () async {
            await context.read<AuthController>().reloadMe();
            await _loadWallet();
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
                children: [
                  StylAvatar(
                    size: 88,
                    imageUrl: avatarUrl,
                    name: name,
                    showAddBadge: !hasPhoto,
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        AppRoutes.customerPersonalInfo,
                      );
                    },
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
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              AppRoutes.customerPersonalInfo,
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
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF3F7FB),
                      Color(0xFFE8F1F8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE0E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppColors.brandPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Wallet balance',
                            style: TextStyle(
                              fontSize: 13,
                              color: _muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _loadingWallet ? '…' : balance,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: AppColors.brandPrimary,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PaymentsScreen(),
                            ),
                          );
                        },
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 28, color: Color(0xFFF0F0F0)),
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
                          AppRoutes.customerPersonalInfo,
                        );
                      },
              ),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              InkWell(
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.customerSettings);
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
                onTap: () {
                  Navigator.of(context).pushNamed(AppRoutes.bookAgain);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    children: [
                      Icon(Icons.replay_rounded, size: 22, color: _rowIcon),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Book again',
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
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A5568),
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
                          : const Color(0xFF111827),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF6B7280),
              ),
          ],
        ),
      ),
    );
  }
}
