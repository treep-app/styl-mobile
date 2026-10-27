import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Shared chrome for Login / Sign Up: canvas + logo + white bottom sheet.
class AuthSheetScaffold extends StatelessWidget {
  const AuthSheetScaffold({
    super.key,
    required this.child,
    this.logoSize,
    this.showBack = true,
    this.onBack,
  });

  final Widget child;
  final double? logoSize;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppColors.lightCanvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = logoSize ??
                (constraints.maxWidth * 0.32).clamp(96.0, 120.0);

            return Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Image.asset(
                          AppAssets.logo,
                          width: size,
                          height: size,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppRadii.xl),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x0DF4F6FA),
                            blurRadius: 50,
                          ),
                        ],
                      ),
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.lg,
                        AppSpacing.page,
                        AppSpacing.lg + bottomInset,
                      ),
                      child: child,
                    ),
                  ],
                ),
                if (showBack && (canPop || onBack != null))
                  Positioned(
                    top: 4,
                    left: 8,
                    child: IconButton(
                      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      color: AppColors.brandPrimary,
                      tooltip: 'Back',
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
