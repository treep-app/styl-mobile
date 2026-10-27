import 'package:flutter/material.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';

const _accent = Color(0xFF4F6BFF);
const _muted = Color(0xFF8B93A7);
const _stepsBg = Color(0xFFEEF2FF);

/// Confirmation after a team invitation is sent.
class InvitationSentScreen extends StatelessWidget {
  const InvitationSentScreen({super.key, required this.args});

  final InvitationSentArgs args;

  @override
  Widget build(BuildContext context) {
    final contact = args.invitation.contact?.trim().isNotEmpty == true
        ? args.invitation.contact!
        : (args.invitation.email ?? args.invitation.phone ?? 'them');
    final salon = args.salonName;
    final emailed = args.invitation.isEmail;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).popUntil(
                      (route) =>
                          route.settings.name == AppRoutes.providerSalonTeam ||
                          route.isFirst,
                    ),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    color: AppColors.brandPrimary,
                  ),
                  const Expanded(
                    child: Text(
                      'Invitation sent',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: SizedBox(
                      width: 140,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.mail_outline_rounded,
                            size: 88,
                            color: _accent.withValues(alpha: 0.18),
                          ),
                          const Icon(
                            Icons.mail_outline_rounded,
                            size: 64,
                            color: Color(0xFF9AA3B8),
                          ),
                          Positioned(
                            top: 8,
                            right: 28,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: _accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Invitation sent!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: _muted,
                      ),
                      children: [
                        TextSpan(
                          text: emailed
                              ? "We've emailed "
                              : "We've texted ",
                        ),
                        TextSpan(
                          text: contact,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                        const TextSpan(text: ' with an invitation to join '),
                        TextSpan(
                          text: '$salon.',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandPrimary,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    decoration: BoxDecoration(
                      color: _stepsBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        _NextStep(number: 1, label: 'They receive your invitation'),
                        SizedBox(height: 14),
                        _NextStep(
                          number: 2,
                          label: 'They create or log in to their account',
                        ),
                        SizedBox(height: 14),
                        _NextStep(
                          number: 3,
                          label:
                              'They accept and complete their professional profile',
                        ),
                        SizedBox(height: 14),
                        _NextStep(
                          number: 4,
                          label:
                              "You'll be notified and can activate them for bookings",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed(
                            AppRoutes.providerAddProfessional,
                            arguments: AddProfessionalArgs(
                              shopId: args.shopId,
                              salonName: salon,
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Invite another professional',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          AppRoutes.providerSalonTeam,
                          (route) => false,
                          arguments: SalonSetupArgs(shopId: args.shopId),
                        );
                      },
                      child: const Text(
                        'View team',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.brandPrimary,
                        ),
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

class _NextStep extends StatelessWidget {
  const _NextStep({required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _accent, width: 1.5),
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: _accent,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
