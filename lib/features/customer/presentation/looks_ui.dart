import 'package:flutter/material.dart';

/// Looksy-home tokens — purple marketplace dashboard (STYL wordmark).
abstract final class LooksUi {
  static const ink = Color(0xFF1A1633);
  static const purple = Color(0xFF6B4EFF);
  static const purpleSoft = Color(0xFFF0ECFF);
  static const mapMint = Color(0xFFE8F4F8);
  static const cream = Color(0xFFF7F4F0);

  /// Secondary body copy — dark enough on white.
  static const muted = Color(0xFF5C586C);
  static const hairline = Color(0xFFE8E4DC);

  /// Unselected tabs / nav labels.
  static const navGray = Color(0xFF6E6A7C);
  static const searchFill = Color(0xFFF4F3F8);
  static const chipIdle = Color(0xFFF3F0FA);

  /// Toolbar / AppBar title + icons on white bars.
  static const toolbar = ink;

  static const heroImage =
      'https://images.unsplash.com/photo-1605980776566-0486c3ac7617?w=1400&q=80';
  static const mapImage =
      'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=800&q=80';
}
