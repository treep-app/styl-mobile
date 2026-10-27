import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Shared shimmer scope for skeleton placeholders.
class StylShimmer extends StatefulWidget {
  const StylShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<StylShimmer> createState() => _StylShimmerState();

  static Animation<double>? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.animation;
  }
}

class _StylShimmerState extends State<StylShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScope(
      animation: _controller,
      child: widget.child,
    );
  }
}

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({
    required this.animation,
    required super.child,
  });

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_ShimmerScope oldWidget) =>
      animation != oldWidget.animation;
}

/// A single rounded placeholder “bone”.
class StylBone extends StatelessWidget {
  const StylBone({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final animation = StylShimmer.of(context);
    final base = const Color(0xFFE8ECF1);
    final highlight = const Color(0xFFF7F9FC);

    Widget bone = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

    if (animation == null) return bone;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final t = animation.value;
            return LinearGradient(
              begin: Alignment(-1.0 - t * 2, 0),
              end: Alignment(1.0 - t * 2, 0),
              colors: [base, highlight, base],
              stops: const [0.25, 0.5, 0.75],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: bone,
    );
  }
}

/// Customer home skeleton matching dashboard layout.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return StylShimmer(
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StylBone(width: 140, height: 18),
                    SizedBox(height: 8),
                    StylBone(width: 200, height: 12),
                  ],
                ),
              ),
              StylBone(width: 40, height: 40, radius: 20),
            ],
          ),
          const SizedBox(height: 18),
          const StylBone(height: 44, radius: 12),
          const SizedBox(height: 16),
          const StylBone(height: 72, radius: 14),
          const SizedBox(height: 22),
          const StylBone(width: 120, height: 16),
          const SizedBox(height: 12),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, _) => const StylBone(width: 140, height: 168, radius: 14),
            ),
          ),
          const SizedBox(height: 22),
          const StylBone(width: 90, height: 16),
          const SizedBox(height: 12),
          const _SalonCardBone(),
          const SizedBox(height: 10),
          const _SalonCardBone(),
          const SizedBox(height: 10),
          const _SalonCardBone(),
        ],
      ),
    );
  }
}

class _SalonCardBone extends StatelessWidget {
  const _SalonCardBone();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        StylBone(width: 72, height: 72, radius: 12),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StylBone(width: 160, height: 14),
              SizedBox(height: 8),
              StylBone(width: 120, height: 12),
              SizedBox(height: 8),
              StylBone(width: 80, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact appointment list skeleton.
class AppointmentsSkeleton extends StatelessWidget {
  const AppointmentsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return StylShimmer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Expanded(child: StylBone(width: 160, height: 22)),
                StylBone(width: 88, height: 26, radius: 14),
              ],
            ),
            const SizedBox(height: 14),
            const StylBone(height: 44, radius: 12),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                itemCount: 6,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, _) => const _AppointmentRowBone(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentRowBone extends StatelessWidget {
  const _AppointmentRowBone();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightOutlineVariant),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 64,
            child: Column(
              children: [
                StylBone(width: 36, height: 10),
                SizedBox(height: 6),
                StylBone(width: 28, height: 20),
                SizedBox(height: 6),
                StylBone(width: 36, height: 10),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StylBone(width: 140, height: 14),
                SizedBox(height: 8),
                StylBone(width: 180, height: 12),
                SizedBox(height: 10),
                StylBone(width: 64, height: 18, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Notifications inbox skeleton.
class NotificationsSkeleton extends StatelessWidget {
  const NotificationsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return StylShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: 8,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, _) => Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.lightOutlineVariant),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StylBone(width: 40, height: 40, radius: 12),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: StylBone(height: 13)),
                        SizedBox(width: 12),
                        StylBone(width: 28, height: 11),
                      ],
                    ),
                    SizedBox(height: 8),
                    StylBone(height: 12),
                    SizedBox(height: 6),
                    StylBone(width: 160, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Payments tab skeleton.
class PaymentsSkeleton extends StatelessWidget {
  const PaymentsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return StylShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: const [
          Center(child: StylBone(width: 100, height: 18)),
          SizedBox(height: 10),
          Center(child: StylBone(width: 220, height: 12)),
          SizedBox(height: 28),
          StylBone(width: 140, height: 16),
          SizedBox(height: 14),
          StylBone(height: 64, radius: 12),
          SizedBox(height: 10),
          StylBone(height: 64, radius: 12),
          SizedBox(height: 28),
          StylBone(width: 90, height: 16),
          SizedBox(height: 14),
          StylBone(height: 18, width: 180),
          SizedBox(height: 10),
          StylBone(height: 14, width: 140),
          SizedBox(height: 18),
          StylBone(height: 18, width: 160),
          SizedBox(height: 10),
          StylBone(height: 14, width: 120),
        ],
      ),
    );
  }
}

/// Vertical salon/barber list skeleton.
class SalonListSkeleton extends StatelessWidget {
  const SalonListSkeleton({super.key, this.count = 8});

  final int count;

  @override
  Widget build(BuildContext context) {
    return StylShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, _) => const _SalonCardBone(),
      ),
    );
  }
}

/// Provider dashboard skeleton.
class ProviderHomeSkeleton extends StatelessWidget {
  const ProviderHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return StylShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Row(
            children: [
              StylBone(width: 28, height: 22, radius: 6),
              Spacer(),
              StylBone(width: 72, height: 22, radius: 8),
              Spacer(),
              StylBone(width: 28, height: 22, radius: 6),
            ],
          ),
          const SizedBox(height: 22),
          const StylBone(width: 240, height: 26, radius: 8),
          const SizedBox(height: 10),
          const StylBone(width: 160, height: 14, radius: 6),
          const SizedBox(height: 22),
          const StylBone(height: 96, radius: 20),
          const SizedBox(height: 18),
          const StylBone(height: 320, radius: 18),
        ],
      ),
    );
  }
}
