import 'dart:io';

import 'package:byebyesleep/alarm/alarm_providers.dart';
import 'package:byebyesleep/app/app.dart';
import 'package:byebyesleep/app/routes.dart';
import 'package:byebyesleep/app/theme.dart';
import 'package:byebyesleep/tools/clock_prefs.dart';
import 'package:byebyesleep/tools/stopwatch_screen.dart';
import 'package:byebyesleep/tools/world_clock.dart';
import 'package:byebyesleep/tools/timer_bell.dart';
import 'package:byebyesleep/watch_setup/watch_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_alarm_platform.dart';
import 'memory_stopwatch_store.dart';
import 'memory_timer_store.dart';
import 'memory_watch_store.dart';

/// Pumps the app's routing with [fake] as the alarm platform.
Future<void> pumpApp(
  WidgetTester tester,
  FakeAlarmPlatform fake, {
  String initialRoute = '/',
  List<Object> extraOverrides = const [],
  WatchSettings watch = const WatchSettings(),
  ThemeMode themeMode = ThemeMode.dark,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        alarmPlatformProvider.overrideWithValue(fake),
        watchSettingsStoreProvider.overrideWithValue(MemoryWatchStore(watch)),
        timerStoreProvider.overrideWithValue(MemoryTimerStore()),
        stopwatchStoreProvider.overrideWithValue(MemoryStopwatchStore()),
        clockPrefsStoreProvider.overrideWithValue(MemoryClockPrefsStore()),
        // No network in tests.
        httpGetProvider.overrideWithValue(
          (url) async => throw const SocketException('offline in tests'),
        ),
        ...extraOverrides.cast(),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
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
