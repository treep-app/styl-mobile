import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/post_auth_navigation.dart';
import '../../../core/auth/session_store.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';

/// Figma "Splash Screen" (#217:2591) — centered STYL logo on white.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _goNext());
  }

  Future<void> _goNext() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final auth = context.read<AuthController>();
    if (!auth.bootstrapped) {
      await auth.bootstrap();
    }
    if (!mounted) return;

    if (auth.isLoggedIn) {
      final dest = await resolvePostAuthDestination(auth);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        dest.route,
        arguments: dest.arguments,
      );
      return;
    }

    final onboardingDone = await SessionStore().isOnboardingDone();
    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed(
      onboardingDone ? AppRoutes.welcome : AppRoutes.onboarding,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoSize = (constraints.maxWidth * 0.53).clamp(160.0, 199.0);
            return Center(
              child: Image.asset(
                AppAssets.logo,
                width: logoSize,
                height: logoSize,
                fit: BoxFit.contain,
              ),
            );
          },
        ),
      ),
    );
  }
}
