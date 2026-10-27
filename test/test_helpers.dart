import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:styl_app/core/auth/auth_controller.dart';
import 'package:styl_app/core/network/api_client.dart';
import 'package:styl_app/core/network/api_models.dart';
import 'package:styl_app/core/notifications/notification_controller.dart';

/// Call once before widget tests that touch [SessionStore] / preferences.
Future<void> initStylTestEnvironment() async {
  SharedPreferences.setMockInitialValues({});
  TestWidgetsFlutterBinding.ensureInitialized();
}

http.Client _stylTestHttpClient() {
  return MockClient((request) async {
    final path = request.url.path;
    final Map<String, dynamic> data;

    if (path.contains('/catalog')) {
      data = {
        'shops': <dynamic>[],
        'looks': <dynamic>[],
        'categories': <dynamic>[],
        'professionals': <dynamic>[],
        'areas': <dynamic>[],
        'popularAreas': <dynamic>[],
      };
    } else if (path.contains('/shops/mine')) {
      data = {'shops': <dynamic>[]};
    } else if (path.contains('/appointments')) {
      data = {'appointments': <dynamic>[]};
    } else if (path.contains('unread-count')) {
      data = {'count': 0};
    } else if (path.contains('/notifications')) {
      data = {'notifications': <dynamic>[]};
    } else {
      data = {};
    }

    return http.Response(
      jsonEncode({'success': true, 'data': data}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
}

AuthController createTestAuth({StylUser? user}) {
  final auth = AuthController(
    apiClient: ApiClient(httpClient: _stylTestHttpClient()),
  );
  auth.user = user;
  auth.bootstrapped = true;
  return auth;
}

StylUser testCustomerUser() => const StylUser(
      id: 'test-customer',
      phone: '+447911123456',
      role: 'CLIENT',
      fullName: 'Test Customer',
      email: 'customer@stylaus.com',
    );

StylUser testBarberUser() => const StylUser(
      id: 'test-barber',
      phone: '+447911123455',
      role: 'BARBER',
      fullName: 'Immanuel',
      email: 'barber@stylaus.com',
    );

/// Holds providers created for a test so timers can be stopped in [dispose].
class StylTestHarness {
  StylTestHarness({
    required this.auth,
    required this.notifications,
  });

  final AuthController auth;
  final NotificationController notifications;

  void dispose() {
    notifications.stop();
  }

  Widget app({
    required Widget home,
    Map<String, WidgetBuilder>? routes,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<NotificationController>.value(
          value: notifications,
        ),
      ],
      child: MaterialApp(
        home: home,
        routes: routes ?? const {},
      ),
    );
  }
}

StylTestHarness createTestHarness({StylUser? user}) {
  final auth = createTestAuth(user: user);
  final notifications = NotificationController(auth);
  return StylTestHarness(auth: auth, notifications: notifications);
}

/// Unmount widgets and stop notification polling (required after logged-in tests).
Future<void> tearDownStylTest(WidgetTester tester, StylTestHarness harness) async {
  harness.dispose();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}
