import 'package:flutter/material.dart';

/// Compact STYL Verified checkmark shown next to salon names.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({
    super.key,
    this.size = 16,
    this.showLabel = false,
    this.color = const Color(0xFF4F6BFF),
  });

  final double size;
  final bool showLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.verified_rounded, size: size, color: color);
    if (!showLabel) return icon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 4),
        Text(
          'Verified',
          style: TextStyle(
            fontSize: size * 0.75,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Name + optional verified badge in one row.
class VerifiedSalonName extends StatelessWidget {
  const VerifiedSalonName({
    super.key,
    required this.name,
    required this.isVerified,
    this.style,
    this.maxLines = 1,
    this.badgeSize = 16,
    this.showLabel = false,
  });

  final String name;
  final bool isVerified;
  final TextStyle? style;
  final int maxLines;
  final double badgeSize;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (isVerified) ...[
          const SizedBox(width: 4),
          VerifiedBadge(size: badgeSize, showLabel: showLabel),
        ],
      ],
    );
  }
}
