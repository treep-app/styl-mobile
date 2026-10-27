import 'package:flutter/material.dart';

import 'looks_ui.dart';

/// Looksy-style illustrated category icons (no circular frame).
class LooksyCategoryIcon extends StatelessWidget {
  const LooksyCategoryIcon({
    super.key,
    required this.categoryId,
    this.size = 52,
  });

  final String categoryId;
  final double size;

  static const assets = <String, String>{
    'barber': 'assets/icons/categories/barber.png',
    'womens': 'assets/icons/categories/womens.png',
    'nails': 'assets/icons/categories/nails.png',
    'lashes': 'assets/icons/categories/lashes.png',
    'braids': 'assets/icons/categories/braids.png',
    'beard': 'assets/icons/categories/beard.png',
    'colour': 'assets/icons/categories/colour.png',
    'extensions': 'assets/icons/categories/extensions.png',
    'beauty': 'assets/icons/categories/beauty.png',
    'more': 'assets/icons/categories/more.png',
  };

  @override
  Widget build(BuildContext context) {
    final asset = assets[categoryId] ?? assets['more']!;
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => Icon(
          Icons.spa_rounded,
          size: size * 0.72,
          color: LooksUi.ink.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
