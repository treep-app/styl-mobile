import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// API base URL for mobile.
///
/// **TestFlight / App Store / release / profile:** always
/// [https://api.stylaus.com/api/v1](https://api.stylaus.com/api/v1)
/// (localhost overrides are ignored outside debug).
///
/// **Debug (`flutter run`):** local backend by default
/// (`http://192.168.1.2:3000/api/v1`, or `192.168.1.2` on Android emulator).
///
/// Debug overrides:
/// ```
/// flutter run --dart-define=USE_PROD_API=true
/// flutter run --dart-define=USE_LOCAL_API=true
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000/api/v1
/// ```
abstract final class ApiConfig {
  static const String productionBaseUrl = 'https://api.stylaus.com/api/v1';

  /// iOS Simulator / desktop host loopback.
  static const String localBaseUrl = 'http://192.168.1.2:3000/api/v1';

  /// Android emulator → host machine loopback.
  static const String androidEmulatorLocalBaseUrl =
      'http://192.168.1.2:3000/api/v1';

  static const String _fromEnvironment = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const bool useLocalApi = bool.fromEnvironment(
    'USE_LOCAL_API',
    defaultValue: false,
  );

  static const bool useProdApi = bool.fromEnvironment(
    'USE_PROD_API',
    defaultValue: false,
  );

  /// Resolved base URL used by [ApiClient].
  static String get baseUrl {
    // TestFlight, App Store, and any non-debug build → production.
    // Never ship localhost / LAN URLs in profile or release.
    if (!kDebugMode) {
      if (_fromEnvironment.isNotEmpty) {
        final override = _normalize(_fromEnvironment);
        if (_isLocalUrl(override)) return productionBaseUrl;
        return override;
      }
      return productionBaseUrl;
    }

    if (_fromEnvironment.isNotEmpty) return _normalize(_fromEnvironment);
    if (useProdApi) return productionBaseUrl;
    if (useLocalApi) return localDefaultBaseUrl;
    return localDefaultBaseUrl;
  }

  /// Local defaults: Android emulator uses `192.168.1.2`, otherwise `192.168.1.2`.
  static String get localDefaultBaseUrl {
    if (Platform.isAndroid) return androidEmulatorLocalBaseUrl;
    return localBaseUrl;
  }

  static bool _isLocalUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('192.168.1.2') ||
        lower.contains('localhost') ||
        lower.contains('192.168.1.2') ||
        RegExp(r'https?://192\.168\.').hasMatch(lower) ||
        RegExp(r'https?://10\.\d+\.').hasMatch(lower) ||
        RegExp(r'https?://172\.(1[6-9]|2\d|3[0-1])\.').hasMatch(lower);
  }

  /// Strip trailing slash; ensure `/api/v1` when only the host was provided.
  static String _normalize(String url) {
    var value = url.trim();
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    // Allow passing https://api.stylaus.com/ and expand to /api/v1.
    if (value == 'https://api.stylaus.com' || value == 'http://api.stylaus.com') {
      return productionBaseUrl;
    }
    if (value == 'http://192.168.1.2:3000' || value == 'http://localhost:3000') {
      return localBaseUrl;
    }
    if (value == 'http://192.168.1.2:3000') {
      return androidEmulatorLocalBaseUrl;
    }
    return value;
  }
}
