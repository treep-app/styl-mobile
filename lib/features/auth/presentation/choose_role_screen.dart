import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/journey_choice_card.dart';
import '../../../widgets/styl_primary_button.dart';

enum PostOtpRole { customer, serviceProfessional }

/// After phone OTP — pick Customer or Service Professional.
class ChooseRoleScreen extends StatefulWidget {
  const ChooseRoleScreen({super.key});

  @override
  State<ChooseRoleScreen> createState() => _ChooseRoleScreenState();
}

class _ChooseRoleScreenState extends State<ChooseRoleScreen> {
  var _role = PostOtpRole.customer;
  var _busy = false;

  Future<void> _continue() async {
    if (_busy) return;
    setState(() => _busy = true);
    final auth = context.read<AuthController>();
    final store = SessionStore();
    try {
      if (_role == PostOtpRole.serviceProfessional) {
        // Promote to BARBER immediately so restarts never land on customer UI.
        await auth.completeOnboarding(role: 'BARBER');
        await store.setProviderSetupStage('provider_type');
        await store.setProviderSetupShopId(null);
        if (!mounted) return;
        Navigator.of(context).pushNamed(AppRoutes.providerType);
        return;
      }

      await store.clearProviderSetup();
      await auth.completeOnboarding(role: 'CLIENT');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.customerPersonalInfo,
        arguments: const CustomerPersonalInfoArgs(fromOnboarding: true),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 16 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: AppColors.brandPrimary,
              ),
              const SizedBox(height: 8),
              const Text(
                'How would you like\nto use STYL?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brandPrimary,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You can always add another role later.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppColors.lightOnSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              JourneyChoiceCard(
                title: 'Customer',
                subtitle:
                    'Find and book barbers, salons and beauty professionals.',
                icon: Icons.person_outline_rounded,
                selected: _role == PostOtpRole.customer,
                onTap: () => setState(() => _role = PostOtpRole.customer),
              ),
              const SizedBox(height: 12),
              JourneyChoiceCard(
                title: 'Service Professional',
                subtitle: 'Offer your services and get more customers.',
                icon: Icons.content_cut_rounded,
                selected: _role == PostOtpRole.serviceProfessional,
                onTap: () =>
                    setState(() => _role = PostOtpRole.serviceProfessional),
              ),
              const Spacer(),
              StylPrimaryButton(
                label: _busy ? 'Saving…' : 'Continue',
                isLoading: _busy,
                onPressed: _busy ? null : _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
