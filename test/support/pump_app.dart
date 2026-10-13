import 'package:byebyesleep/alarm/alarm_providers.dart';
import 'package:byebyesleep/app/app.dart';
import 'package:byebyesleep/app/routes.dart';
import 'package:byebyesleep/watch_setup/watch_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_alarm_platform.dart';
import 'memory_watch_store.dart';

/// Pumps the app's routing with [fake] as the alarm platform.
Future<void> pumpApp(
  WidgetTester tester,
  FakeAlarmPlatform fake, {
  String initialRoute = '/',
  List<Object> extraOverrides = const [],
  WatchSettings watch = const WatchSettings(),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        alarmPlatformProvider.overrideWithValue(fake),
        watchSettingsStoreProvider.overrideWithValue(MemoryWatchStore(watch)),
        ...extraOverrides.cast(),
      ],
      child: MaterialApp(
        builder: appBuilder,
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
