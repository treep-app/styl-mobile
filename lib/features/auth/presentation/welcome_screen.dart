import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/auth/session_store.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';

class _WelcomeSlide {
  const _WelcomeSlide({
    required this.imageUrl,
    required this.headline,
  });

  final String imageUrl;
  final String headline;
}

/// Get Started / Log In gate. Phone auth — never email.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const slides = <_WelcomeSlide>[
    _WelcomeSlide(
      imageUrl:
          'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=1600&q=80',
      headline:
          'Find the look.\nFind the right professional.\nBook instantly.',
    ),
    _WelcomeSlide(
      imageUrl:
          'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=1600&q=80',
      headline: 'Hair, colour, and texture.\nBook the stylist who gets you.',
    ),
    _WelcomeSlide(
      imageUrl:
          'https://images.unsplash.com/photo-1632345031435-8727f6897d53?w=1600&q=80',
      headline: 'Nails, lashes, and beauty.\nYour next look, one tap away.',
    ),
  ];

  Future<void> _go(BuildContext context, String route) async {
    await SessionStore().setOnboardingDone();
    if (!context.mounted) return;
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: WelcomeHero(
        onGetStarted: () => _go(context, AppRoutes.customerSignUp),
        onLogIn: () => _go(context, AppRoutes.customerLogin),
      ),
    );
  }
}

/// Full-bleed STYL welcome — swipeable cinematic hero.
class WelcomeHero extends StatefulWidget {
  const WelcomeHero({
    super.key,
    required this.onGetStarted,
    required this.onLogIn,
  });

  final VoidCallback onGetStarted;
  final VoidCallback onLogIn;

  @override
  State<WelcomeHero> createState() => _WelcomeHeroState();
}

class _WelcomeHeroState extends State<WelcomeHero> {
  static const _autoPlay = Duration(milliseconds: 4800);

  late final PageController _pager;
  var _index = 0;
  var _dragging = false;
  Timer? _timer;

  List<_WelcomeSlide> get _slides => WelcomeScreen.slides;

  @override
  void initState() {
    super.initState();
    _pager = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _precache());
    _startAutoPlay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pager.dispose();
    super.dispose();
  }

  void _precache() {
    if (!mounted) return;
    for (final slide in _slides) {
      precacheImage(NetworkImage(slide.imageUrl), context);
    }
  }

  void _startAutoPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(_autoPlay, (_) {
      if (!mounted || _dragging || !_pager.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _pager.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onPageChanged(int i) {
    if (_index == i) return;
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final slide = _slides[_index];

    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n is ScrollStartNotification && n.dragDetails != null) {
              _dragging = true;
            } else if (n is ScrollEndNotification) {
              _dragging = false;
              _startAutoPlay();
            }
            return false;
          },
          child: PageView.builder(
            controller: _pager,
            itemCount: _slides.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, i) {
              return Image.network(
                _slides[i].imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: AppColors.brandPrimary,
                ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const ColoredBox(color: Color(0xFF0B1220));
                },
              );
            },
          ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x73000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xE6001428),
                ],
                stops: [0, 0.22, 0.42, 1],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, 20 + bottom),
            child: Column(
              children: [
                const Text(
                  'STYL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    height: 1,
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: Text(
                    slide.headline,
                    key: ValueKey(slide.headline),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: widget.onGetStarted,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.brandPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: widget.onLogIn,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    child: const Text(
                      'Log In',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Beauty, Barbering. Hair. Nails. And more.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final active = i == _index;
                    return GestureDetector(
                      onTap: () {
                        _pager.animateToPage(
                          i,
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 18 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? Colors.white : const Color(0x66FFFFFF),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
