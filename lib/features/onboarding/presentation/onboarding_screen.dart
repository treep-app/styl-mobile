import 'package:flutter/material.dart';

import '../../../core/auth/session_store.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/styl_primary_button.dart';

/// First-launch walkthrough — then the STYL Get Started / Log In welcome.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  var _index = 0;

  static const _pages = <_OnboardPage>[
    _OnboardPage(
      title: 'Barber-level cuts',
      subtitle:
          'Watch craft meet style — book barbers who know fades, trims, and classic cuts.',
      icon: Icons.content_cut_rounded,
      accent: Color(0xFFE8F1F8),
      imageUrl:
          'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=900&q=80',
    ),
    _OnboardPage(
      title: 'Styled by experts',
      subtitle:
          'From color to care — connect with talented stylists who bring your look to life.',
      icon: Icons.face_retouching_natural_rounded,
      accent: Color(0xFFFFF0EA),
      imageUrl:
          'https://images.unsplash.com/photo-1562322140-8baeececf3df?w=900&q=80',
    ),
    _OnboardPage(
      title: 'Book in minutes',
      subtitle:
          'Pick a stylist, choose a time, and confirm — no calls, no waiting around.',
      icon: Icons.event_available_rounded,
      accent: Color(0xFFF3F7FB),
      imageUrl:
          'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=900&q=80',
    ),
    _OnboardPage(
      title: 'Find the best salon',
      subtitle:
          'Browse top-rated salons near you — ratings, photos, and the right fit for every visit.',
      icon: Icons.storefront_rounded,
      accent: Color(0xFFEAF6F2),
      imageUrl:
          'https://images.unsplash.com/photo-1585747860715-2ba37e788b70?w=900&q=80',
    ),
  ];

  bool get _isLast => _index == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish({String? nextRoute}) async {
    await SessionStore().setOnboardingDone();
    if (!mounted) return;
    if (nextRoute != null) {
      Navigator.of(context).pushReplacementNamed(nextRoute);
      return;
    }
    Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final size = MediaQuery.sizeOf(context);
    final heroHeight = (size.height * 0.48).clamp(280.0, 420.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Image.asset(
                      AppAssets.logo,
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const Spacer(),
                  if (!_isLast)
                    TextButton(
                      onPressed: _finish,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: AppColors.lightOnSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _HeroVisual(
                          height: heroHeight,
                          accent: page.accent,
                          icon: page.icon,
                          imageUrl: page.imageUrl,
                        ),
                        const SizedBox(height: 28),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brandPrimary,
                            height: 1.15,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15.5,
                            height: 1.5,
                            color: AppColors.lightOnSurfaceVariant,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 20 + bottomInset),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.brandPrimary
                              : const Color(0xFFD8DEE8),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 22),
                  StylPrimaryButton(
                    label: _isLast ? 'Continue' : 'Next',
                    onPressed: _next,
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

class _OnboardPage {
  const _OnboardPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.imageUrl,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String imageUrl;
}

class _HeroVisual extends StatelessWidget {
  const _HeroVisual({
    required this.height,
    required this.accent,
    required this.icon,
    required this.imageUrl,
  });

  final double height;
  final Color accent;
  final IconData icon;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: AppColors.brandPrimary, size: 26),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            top: 28,
            bottom: 18,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: accent,
                      child: Icon(
                        icon,
                        size: 64,
                        color: AppColors.brandPrimary.withValues(alpha: 0.35),
                      ),
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return ColoredBox(
                        color: accent,
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                        ),
                      );
                    },
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.brandPrimary.withValues(alpha: 0.18),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
