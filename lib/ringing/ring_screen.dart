import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alarm/alarm_providers.dart';

const snoozeMinutes = 9;

/// Full-screen ringing UI. Phase 0: plain Stop / Snooze.
class RingScreen extends ConsumerStatefulWidget {
  const RingScreen({super.key, required this.alarmId, this.onFinished});

  final int alarmId;

  /// Called after the alarm is stopped or snoozed. Defaults to closing the
  /// native ring activity.
  final VoidCallback? onFinished;

  @override
  ConsumerState<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends ConsumerState<RingScreen> {
  late DateTime _now;
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  void _finish() => (widget.onFinished ?? SystemNavigator.pop)();

  @override
  Widget build(BuildContext context) {
    final alarm = ref
        .watch(alarmListProvider)
        .value
        ?.where((a) => a.id == widget.alarmId)
        .firstOrNull;
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_now.hour.toString().padLeft(2, '0')}:'
                '${_now.minute.toString().padLeft(2, '0')}',
                style: text.displayLarge,
              ),
              if (alarm != null && alarm.label.isNotEmpty)
                Text(alarm.label, style: text.headlineSmall),
              const SizedBox(height: 48),
              _ActionButtons(alarmId: widget.alarmId, onFinished: _finish),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phase 1 replaces this with the challenge stage engine.
class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.alarmId, required this.onFinished});

  final int alarmId;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.read(alarmPlatformProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            key: const Key('stop'),
            onPressed: () async {
              await platform.stopRinging();
              onFinished();
            },
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Stop'),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('snooze'),
            onPressed: () async {
              await platform.snooze(alarmId, snoozeMinutes);
              await platform.stopRinging();
              onFinished();
            },
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Snooze $snoozeMinutes min'),
            ),
          ),
        ],
      ),
    );
  }
}
