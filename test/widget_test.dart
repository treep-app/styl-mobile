import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:styl_app/core/routing/app_routes.dart';
import 'package:styl_app/features/auth/presentation/role_selection_screen.dart';
import 'package:styl_app/features/customer/presentation/customer_home_screen.dart';
import 'package:styl_app/features/customer/presentation/customer_shell.dart';
import 'package:styl_app/features/provider/presentation/provider_shell.dart';

import 'test_helpers.dart';

void main() {
  setUpAll(() async {
    await initStylTestEnvironment();
  });

  testWidgets('role selection shows account type choices', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RoleSelectionScreen()),
    );

    expect(find.text('Who are you?'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Service Provider'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
  });

  testWidgets('customer shell exposes five bottom tabs', (
    WidgetTester tester,
  ) async {
    final harness = createTestHarness();
    await tester.pumpWidget(
      harness.app(home: const CustomerShell()),
    );
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(AppRoutes.customerShell, '/customer');

    await tearDownStylTest(tester, harness);
  });

  testWidgets('provider shell exposes home calendar clients more', (
    WidgetTester tester,
  ) async {
    final harness = createTestHarness();
    await tester.pumpWidget(
      harness.app(home: const ProviderShell()),
    );
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Clients'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(AppRoutes.providerShell, '/provider');

    await tearDownStylTest(tester, harness);
  });

  testWidgets('customer home shows brand header and notifications', (
    WidgetTester tester,
  ) async {
    final harness = createTestHarness();
    await tester.pumpWidget(
      harness.app(
        home: const Scaffold(body: CustomerHomeScreen()),
        routes: {
          AppRoutes.notifications: (_) =>
              const Scaffold(body: Text('Notification')),
        },
      ),
    );
    await tester.pump();

    expect(find.text('STYL'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Notification'), findsOneWidget);

    await tearDownStylTest(tester, harness);
  });
}
