import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/app_constants.dart';
import 'core/notifications/notification_host.dart';
import 'core/auth/post_auth_navigation.dart';
import 'core/routing/app_navigator.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

class StylApp extends StatelessWidget {
  const StylApp({required this.startup, super.key});

  /// Resolved in [main] after auth bootstrap — avoids a second in-app splash.
  final PostAuthDestination startup;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: stylNavigatorKey,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Product UI is light-first (white scaffolds). System dark mode made
      // AppBar titles inherit light text on white bars → invisible labels.
      themeMode: ThemeMode.light,
      initialRoute: startup.route,
      onGenerateRoute: (settings) {
        final merged = settings.name == startup.route &&
                settings.arguments == null &&
                startup.arguments != null
            ? RouteSettings(
                name: settings.name,
                arguments: startup.arguments,
              )
            : settings;
        return AppRouter.onGenerateRoute(merged);
      },
      builder: (context, child) {
        return NotificationHost(child: child ?? const SizedBox.shrink());
      },
      supportedLocales: const [
        Locale('en'),
      ],
      localizationsDelegates: const [
        CountryLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
