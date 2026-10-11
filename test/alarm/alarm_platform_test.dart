import 'package:byebyesleep/alarm/alarm.dart';
import 'package:byebyesleep/alarm/alarm_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('byebyesleep/alarm');
  final platform = MethodChannelAlarmPlatform();

  void mock(Future<Object?> Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() => mock(null));

  test('upsert sends alarm map and returns trigger', () async {
    late MethodCall seen;
    mock((call) async {
      seen = call;
      return 1760000000000;
    });
    final r = await platform.upsert(
      Alarm(id: 2, hour: 6, minute: 30, repeatDays: {2, 1}),
    );
    expect(seen.method, 'upsert');
    expect((seen.arguments as Map)['repeatDays'], [1, 2]);
    expect(r, 1760000000000);
  });

  test('list parses maps', () async {
    mock(
      (_) async => [
        {
          'id': 1,
          'hour': 7,
          'minute': 0,
          'repeatDays': <int>[],
          'label': '',
          'enabled': true,
        },
      ],
    );
    expect(await platform.list(), [Alarm(id: 1, hour: 7, minute: 0)]);
  });

  test('permissions reports missing kinds', () async {
    mock(
      (_) async => {
        'exactAlarm': true,
        'fullScreenIntent': false,
        'notifications': true,
        'ignoreBatteryOptimizations': false,
      },
    );
    expect((await platform.permissions()).missing, [
      PermissionKind.fullScreenIntent,
      PermissionKind.ignoreBatteryOptimizations,
    ]);
  });

  test('snooze and openSettings send arguments', () async {
    final calls = <MethodCall>[];
    mock((call) async {
      calls.add(call);
      return call.method == 'snooze' ? 42 : null;
    });
    expect(await platform.snooze(7, 9), 42);
    await platform.openSettings(PermissionKind.notifications);
    expect(calls[0].arguments, {'id': 7, 'minutes': 9});
    expect(calls[1].arguments, {'kind': 'notifications'});
  });

  test('isSupported is true when the native engine answers', () async {
    mock((call) async => call.method == 'list' ? <Object?>[] : null);
    expect(await platform.isSupported(), isTrue);
  });

  test('getRingProgress parses map', () async {
    mock((call) async => {'alarmId': 4, 'stageIndex': 2, 'startedAtMs': 1000});
    expect(
      await platform.getRingProgress(),
      const RingProgress(alarmId: 4, stageIndex: 2, startedAtMs: 1000),
    );
  });

  test('saveRingProgress and setRingLevel send arguments', () async {
    final calls = <MethodCall>[];
    mock((call) async {
      calls.add(call);
      return null;
    });
    await platform.saveRingProgress(
      const RingProgress(alarmId: 4, stageIndex: 1, startedAtMs: 5),
    );
    await platform.setRingLevel(0.2);
    expect(calls[0].method, 'saveRingProgress');
    expect(calls[0].arguments, {
      'alarmId': 4,
      'stageIndex': 1,
      'startedAtMs': 5,
    });
    expect(calls[1].method, 'setRingLevel');
    expect(calls[1].arguments, {'level': 0.2});
  });

  test('missing plugin degrades gracefully', () async {
    mock(null);
    expect(await platform.isSupported(), isFalse);
    expect(await platform.list(), isEmpty);
    expect((await platform.permissions()).allGranted, isTrue);
    expect(await platform.upsert(Alarm(id: 1, hour: 1, minute: 1)), isNull);
    expect(await platform.getRingProgress(), isNull);
    await platform.setRingLevel(1);
    await platform.stopRinging();
  });
}
