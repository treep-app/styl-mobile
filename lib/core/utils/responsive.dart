import 'package:flutter/material.dart';

/// Breakpoints and helpers for phone-first iOS / Android layouts.
abstract final class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 840;
}

extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);

  double get screenWidth => screenSize.width;

  double get screenHeight => screenSize.height;

  bool get isCompact => screenWidth < AppBreakpoints.compact;

  EdgeInsets get viewPadding => MediaQuery.paddingOf(this);
}
