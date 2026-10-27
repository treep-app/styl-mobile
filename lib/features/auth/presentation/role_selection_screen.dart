import 'package:flutter/material.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/role_option_card.dart';
import '../../../widgets/styl_primary_button.dart';

enum UserRole { customer, serviceProvider }

/// Compact role gate — select identity, then Sign Up or Log In.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  UserRole _role = UserRole.customer;

  bool get _isProvider => _role == UserRole.serviceProvider;

  void _signUp() {
    Navigator.of(context).pushNamed(
      _isProvider ? AppRoutes.providerSignUp : AppRoutes.customerSignUp,
    );
  }

  void _logIn() {
    Navigator.of(context).pushNamed(
      _isProvider ? AppRoutes.providerLogin : AppRoutes.customerLogin,
      arguments: LoginArgs(isServiceProvider: _isProvider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, 16 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                AppAssets.logo,
                width: 44,
                height: 44,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 28),
              const Text(
                'Who are you?',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPrimary,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pick an account type to continue.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: AppColors.lightOnSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              RoleOptionCard(
                title: 'Customer',
                subtitle: 'Book salons and mobile barbers near you.',
                assetPath: AppAssets.roleCustomer,
                selected: _role == UserRole.customer,
                onTap: () => setState(() => _role = UserRole.customer),
              ),
              const SizedBox(height: 12),
              RoleOptionCard(
                title: 'Service Provider',
                subtitle: 'Manage bookings for your salon or mobile barber work.',
                assetPath: AppAssets.roleServiceProvider,
                selected: _role == UserRole.serviceProvider,
                onTap: () => setState(() => _role = UserRole.serviceProvider),
              ),
              const Spacer(),
              StylPrimaryButton(
                label: 'Sign Up',
                onPressed: _signUp,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _logIn,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brandPrimary,
                    side: const BorderSide(
                      color: AppColors.brandPrimary,
                      width: 1.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  child: const Text(
                    'Log In',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandPrimary,
                    ),
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
