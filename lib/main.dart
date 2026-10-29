import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/auth/auth_controller.dart';
import 'core/config/api_config.dart';
import 'core/constants/styl_taxonomy.dart';
import 'core/routing/app_routes.dart';
import 'core/auth/post_auth_navigation.dart';
import 'core/notifications/notification_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await StylTaxonomy.load();
  } catch (e, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: e,
        stack: stack,
        library: 'STYL startup',
        context: ErrorDescription('loading service taxonomy asset'),
      ),
    );
    rethrow;
  }
  if (kDebugMode) {
    debugPrint('STYL API: ${ApiConfig.baseUrl}');
  }
  final auth = AuthController();
  await auth.bootstrap();
  PostAuthDestination startup;
  try {
    startup = await resolveStartupDestination(auth);
  } catch (e, stack) {
    debugPrint('Startup route failed: $e\n$stack');
    startup = const PostAuthDestination(AppRoutes.welcome);
  }
  final inbox = NotificationController(auth);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: inbox),
      ],
      child: StylApp(startup: startup),
    ),
  );
}
