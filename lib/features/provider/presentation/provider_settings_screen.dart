import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../customer/presentation/payments_screen.dart';

/// Provider Settings — real actions wired to profile, salon, payments, legal.
class ProviderSettingsScreen extends StatefulWidget {
  const ProviderSettingsScreen({super.key});

  @override
  State<ProviderSettingsScreen> createState() => _ProviderSettingsScreenState();
}

class _ProviderSettingsScreenState extends State<ProviderSettingsScreen> {
  final _store = SessionStore();
  var _notificationsEnabled = true;
  var _loadingPrefs = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final enabled = await _store.readNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
      _loadingPrefs = false;
    });
  }

  Future<void> _setNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    await _store.setNotificationsEnabled(value);
  }

  Future<void> _signOut() async {
    await context.read<AuthController>().logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.welcome,
      (route) => false,
    );
  }

  Future<void> _openSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@stylaus.com',
      queryParameters: {'subject': 'STYL provider support'},
    );
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open mail. Email support@stylaus.com'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (user != null) ...[
            Text(
              user.fullName?.trim().isNotEmpty == true
                  ? user.fullName!
                  : 'Your salon account',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user.phone,
              style: const TextStyle(fontSize: 13, color: Color(0xFF8A8A8A)),
            ),
            const SizedBox(height: 20),
          ],
          _SettingsRow(
            icon: Icons.person_outline_rounded,
            title: 'Personal info',
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.providerPersonalInfo,
            ),
          ),
          const Divider(height: 1),
          _SettingsRow(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            trailing: _loadingPrefs
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch.adaptive(
                    value: _notificationsEnabled,
                    activeTrackColor: AppColors.brandPrimary,
                    onChanged: _setNotifications,
                  ),
            onTap: () {
              Navigator.of(context).pushNamed(AppRoutes.notifications);
            },
          ),
          const Divider(height: 1),
          _SettingsRow(
            icon: Icons.credit_card_outlined,
            title: 'Payments',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    backgroundColor: Colors.white,
                    appBar: AppBar(
                      backgroundColor: Colors.white,
                      elevation: 0,
                      title: const Text('Payments'),
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    body: const PaymentsScreen(),
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          _SettingsRow(
            icon: Icons.storefront_outlined,
            title: 'My Salon',
            onTap: () {
              Navigator.of(context).pushNamed(
                AppRoutes.providerSalonProfile,
              );
            },
          ),
          const Divider(height: 1),
          _SettingsRow(
            icon: Icons.groups_outlined,
            title: 'Manage team',
            onTap: () {
              Navigator.of(context).pushNamed(AppRoutes.providerManageSalon);
            },
          ),
          const Divider(height: 1),
          _SettingsRow(
            icon: Icons.help_outline,
            title: 'Help',
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.providerHelp),
          ),
          const Divider(height: 1),
          _SettingsRow(
            icon: Icons.mail_outline_rounded,
            title: 'Contact support',
            onTap: _openSupportEmail,
          ),
          const Divider(height: 1),
          _SettingsRow(
            icon: Icons.description_outlined,
            title: 'Terms & Conditions',
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.providerTerms),
          ),
          const Divider(height: 1),
          _SettingsRow(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Statement',
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.providerPrivacy),
          ),
          const Divider(height: 1),
          _SettingsRow(
            icon: Icons.info_outline,
            title: 'About',
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.providerAbout),
          ),
          const SizedBox(height: 28),
          OutlinedButton(
            onPressed: _signOut,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.brandAccent,
              side: const BorderSide(color: AppColors.brandAccent),
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      tileColor: Colors.transparent,
      leading: Icon(icon, color: Colors.black87),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF575757),
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing ??
          const Icon(Icons.chevron_right, color: Color(0xFFBDBDBD)),
      onTap: onTap,
    );
  }
}
