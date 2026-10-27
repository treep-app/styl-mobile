import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/auth/auth_controller.dart';
import 'core/config/api_config.dart';
import 'core/constants/styl_taxonomy.dart';
import 'core/notifications/notification_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StylTaxonomy.load();
  if (kDebugMode) {
    debugPrint('STYL API: ${ApiConfig.baseUrl}');
  }
  final auth = AuthController();
  await auth.bootstrap();
  final inbox = NotificationController(auth);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider.value(value: inbox),
      ],
      child: const StylApp(),
    ),
  );
}
