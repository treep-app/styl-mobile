import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:styl_app/core/routing/app_routes.dart';
import 'package:styl_app/features/auth/presentation/role_selection_screen.dart';
import 'package:styl_app/features/customer/presentation/customer_home_screen.dart';
import 'package:styl_app/features/customer/presentation/customer_shell.dart';
import 'package:styl_app/features/provider/presentation/provider_shell.dart';

void main() {
  testWidgets('role selection is the unique customer entry gate', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: RoleSelectionScreen()),
    );

    expect(find.text('Who are you?'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('customer shell exposes four unique tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerShell(),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
    expect(find.byIcon(Icons.credit_card_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(AppRoutes.customerShell, '/customer');
  });

  testWidgets('provider shell exposes home notifications settings profile', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProviderShell()),
    );

    expect(find.textContaining('Hi'), findsOneWidget);
    expect(find.textContaining('Immanuel'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(AppRoutes.providerShell, '/provider');
  });

  testWidgets('home shows notification icon and view more actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: CustomerHomeScreen()),
        routes: {
          AppRoutes.notifications: (_) =>
              const Scaffold(body: Text('Notification')),
          AppRoutes.barberList: (_) =>
              const Scaffold(body: Text('Barber list')),
        },
      ),
    );

    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.text('Appointment due Today at 2:00pm'), findsOneWidget);
    expect(find.text('view more'), findsNWidgets(2));
    expect(find.text('Best Freelance Barbers'), findsOneWidget);
    expect(find.text('Barber shops near you'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Notification'), findsOneWidget);
  });
}
