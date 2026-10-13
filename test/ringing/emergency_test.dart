import 'dart:async';

import 'package:byebyesleep/ringing/emergency.dart';
import 'package:byebyesleep/ringing/emergency_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEmergencySource implements EmergencySource {
  final presses = StreamController<void>.broadcast();
  RadioState? state = const RadioState(
    wifiOn: true,
    bluetoothOn: true,
    airplaneOn: false,
  );

  @override
  Stream<void> get volumePresses => presses.stream;

  @override
  Future<RadioState?> radios() async => state;
}

void main() {
  group('protocol', () {
    test('all four steps in any order complete it', () {
      final p = EmergencyProtocol();
      p.radios(
        const RadioState(wifiOn: true, bluetoothOn: false, airplaneOn: false),
      );
      expect(p.done, {EmergencyStep.bluetoothOff});
      p.radios(
        const RadioState(wifiOn: false, bluetoothOn: true, airplaneOn: true),
      );
      expect(p.complete, isFalse); // volume button still missing
      p.volumePressed();
      expect(p.complete, isTrue);
    });

    test('steps stay done once seen (airplane mode can be undone)', () {
      final p = EmergencyProtocol()
        ..radios(
          const RadioState(wifiOn: false, bluetoothOn: false, airplaneOn: true),
        )
        ..radios(
          const RadioState(wifiOn: true, bluetoothOn: true, airplaneOn: false),
        );
      expect(p.done, {
        EmergencyStep.wifiOff,
        EmergencyStep.bluetoothOff,
        EmergencyStep.airplaneOn,
      });
    });
  });

  group('screen', () {
    late FakeEmergencySource source;
    bool? result;

    setUp(() {
      source = FakeEmergencySource();
      result = null;
    });

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [emergencySourceProvider.overrideWithValue(source)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await Navigator.of(context)
                    .push<bool>(
                      MaterialPageRoute(
                        builder: (_) => const EmergencyScreen(),
                      ),
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('stop button appears only after every step', (tester) async {
      await open(tester);
      expect(find.byKey(const Key('emergency-stop')), findsNothing);
      source.presses.add(null);
      source.state = const RadioState(
        wifiOn: false,
        bluetoothOn: false,
        airplaneOn: true,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byKey(const Key('emergency-stop')), findsOneWidget);
      await tester.tap(find.byKey(const Key('emergency-stop')));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('each step shows its own tick', (tester) async {
      await open(tester);
      source.presses.add(null);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('step-volumeButton-done')), findsOneWidget);
      expect(find.byKey(const Key('step-wifiOff-todo')), findsOneWidget);
      await tester.pumpWidget(const SizedBox()); // stop polling
    });
  });
}
