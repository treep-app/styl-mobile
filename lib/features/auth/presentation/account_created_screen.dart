import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/post_auth_navigation.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/styl_primary_button.dart';

class AccountCreatedArgs {
  const AccountCreatedArgs({this.isServiceProvider = false});

  final bool isServiceProvider;
}

/// Success after phone verification + role. Email is never required here.
class AccountCreatedScreen extends StatelessWidget {
  const AccountCreatedScreen({
    super.key,
    this.args = const AccountCreatedArgs(),
  });

  final AccountCreatedArgs args;

  Future<void> _continue(BuildContext context) async {
    final auth = context.read<AuthController>();
    final dest = await resolvePostAuthDestination(auth);
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      dest.route,
      (route) => false,
      arguments: dest.arguments,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 16 + bottom),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F7FB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  size: 42,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'All set!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your account has been created.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: AppColors.lightOnSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              const _CheckRow(label: 'Account created'),
              const _CheckRow(label: 'Phone verified'),
              const _CheckRow(label: 'Profile set up'),
              const _CheckRow(label: "Let's get you started!"),
              const Spacer(flex: 3),
              StylPrimaryButton(
                label: 'Continue to STYL',
                onPressed: () => _continue(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.brandPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
