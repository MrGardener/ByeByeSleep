import 'package:byebyesleep/alarm/alarm_providers.dart';
import 'package:byebyesleep/app/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_alarm_platform.dart';

/// Pumps the app's routing with [fake] as the alarm platform.
Future<void> pumpApp(
  WidgetTester tester,
  FakeAlarmPlatform fake, {
  String initialRoute = '/',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [alarmPlatformProvider.overrideWithValue(fake)],
      child: MaterialApp(
        onGenerateRoute: generateRoute,
        onGenerateInitialRoutes: (name) => [
          generateRoute(RouteSettings(name: name)),
        ],
        initialRoute: initialRoute,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
