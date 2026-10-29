import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/post_auth_navigation.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';

/// Fallback route only (deep links / router recovery). Cold start uses
/// [resolveStartupDestination] in `main()` so users see one OS splash, not two.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
  }

  Future<void> _redirect() async {
    try {
      final auth = context.read<AuthController>();
      if (!auth.bootstrapped) {
        await auth.bootstrap();
      }
      if (!mounted) return;

      final dest = await resolveStartupDestination(auth);
      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed(
        dest.route,
        arguments: dest.arguments,
      );
    } catch (e, stack) {
      debugPrint('Splash redirect failed: $e\n$stack');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Match native splash background; no logo (OS splash already showed brand).
    return const Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: SizedBox.expand(),
    );
  }
}
