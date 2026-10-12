import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../alarm/alarm.dart';
import '../alarm/alarm_platform.dart';
import '../alarm/alarm_providers.dart';
import '../alarm/stage_config.dart';
import '../challenges/core/motion.dart';
import '../challenges/registry.dart';
import 'safety_exit.dart';
import 'stage_engine.dart';
import 'stage_runner.dart';

const snoozeMinutes = 9;

/// Alarm used by the emulator smoke test (debug builds only): no stages.
const debugSmokeAlarmId = 9999;

/// Full-screen ringing UI: the alarm's stages, then Stop / Snooze.
class RingScreen extends ConsumerStatefulWidget {
  const RingScreen({
    super.key,
    required this.alarmId,
    this.onFinished,
    this.clock = DateTime.now,
    this.random,
  });

  final int alarmId;

  /// Called after the alarm is stopped or snoozed. Defaults to closing the
  /// native ring activity.
  final VoidCallback? onFinished;
  final DateTime Function() clock;
  final Random? random;

  @override
  ConsumerState<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends ConsumerState<RingScreen> {
  late final Random _random = widget.random ?? Random();
  Timer? _ticker;
  Alarm? _alarm;
  StageEngine? _engine;
  RingProgress? _progress;
  double? _level;
  int _fallbacks = 0;
  int _stageCount = 0;

  AlarmPlatform get _platform => ref.read(alarmPlatformProvider);

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _load() async {
    final alarms = await ref.read(alarmListProvider.future);
    final alarm = alarms.where((a) => a.id == widget.alarmId).firstOrNull;
    final List<StageConfig> stages =
        kDebugMode && widget.alarmId == debugSmokeAlarmId
        ? const []
        : alarm?.stages ?? defaultStages;
    final now = widget.clock();
    var progress = await _platform.getRingProgress();
    if (progress == null || progress.alarmId != widget.alarmId) {
      progress = RingProgress(
        alarmId: widget.alarmId,
        stageIndex: 0,
        startedAtMs: now.millisecondsSinceEpoch,
      );
      await _platform.saveRingProgress(progress);
    }
    final available = await ref.read(motionSourceProvider).available();
    if (!mounted) return;
    setState(() {
      _alarm = alarm;
      _progress = progress;
      _stageCount = stages.length;
      _engine = StageEngine(
        stages: [for (final s in stages) resolveStage(s, available)],
        ringStartedAt: DateTime.fromMillisecondsSinceEpoch(
          progress!.startedAtMs,
        ),
        startIndex: progress.stageIndex,
        clock: widget.clock,
      );
    });
    _sync();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _engine?.tick();
      _sync();
      if (mounted) setState(() {});
    });
  }

  /// Persists progress and adjusts loudness when the engine moved on.
  void _sync() {
    final engine = _engine;
    final progress = _progress;
    if (engine == null || progress == null) return;
    if (engine.currentIndex != progress.stageIndex) {
      _progress = progress.copyWith(stageIndex: engine.currentIndex);
      _platform.saveRingProgress(_progress!);
    }
    if (engine.ringLevel != _level) {
      _level = engine.ringLevel;
      _platform.setRingLevel(engine.ringLevel);
    }
  }

  void _stagePassed() {
    setState(() => _engine!.stagePassed());
    _sync();
  }

  void _fallback(Running phase) {
    setState(() {
      _engine!.useFallback(fallbackFor(phase.stage.challenge));
      _fallbacks++;
    });
  }

  void _finish() => (widget.onFinished ?? SystemNavigator.pop)();

  Future<void> _safetyExit() async {
    final confirmed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const SafetyExitScreen()));
    if (confirmed != true) return;
    await _platform.stopRinging();
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    final text = Theme.of(context).textTheme;
    final now = widget.clock();
    final label = _alarm?.label ?? '';
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  '${now.hour.toString().padLeft(2, '0')}:'
                  '${now.minute.toString().padLeft(2, '0')}',
                  style: text.displayMedium,
                ),
                if (label.isNotEmpty) Text(label, style: text.titleMedium),
                const SizedBox(height: 12),
                Expanded(
                  child: engine == null
                      ? const Center(child: CircularProgressIndicator())
                      : _body(engine),
                ),
                if (engine != null &&
                    engine.safetyExitAvailable &&
                    engine.phase is! Done)
                  TextButton(
                    key: const Key('safety-exit'),
                    onPressed: _safetyExit,
                    child: const Text("I can't finish — emergency stop"),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(StageEngine engine) {
    return switch (engine.phase) {
      final Running r => Column(
        children: [
          Text('Stage ${r.index + 1} of $_stageCount'),
          const SizedBox(height: 8),
          Expanded(
            child: StageRunner(
              key: ValueKey('stage-${r.index}-$_fallbacks'),
              phase: r,
              random: _random,
              onPassed: _stagePassed,
              onFallback: () => _fallback(r),
            ),
          ),
        ],
      ),
      final Breather b => Center(
        child: Text(
          'Well done! Next stage in ${b.remaining.inSeconds} s',
          key: const Key('breather'),
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
      ),
      Done() => Center(
        child: _ActionButtons(alarmId: widget.alarmId, onFinished: _finish),
      ),
    };
  }
}

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.alarmId, required this.onFinished});

  final int alarmId;
  final VoidCallback onFinished;

  /// Runs [action]; on failure keeps the screen (the alarm keeps ringing)
  /// and tells the user.
  Future<void> _attempt(
    BuildContext context,
    Future<void> Function() action,
    String error,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    onFinished();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platform = ref.read(alarmPlatformProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            key: const Key('stop'),
            onPressed: () => _attempt(
              context,
              platform.stopRinging,
              'Stop failed — try again.',
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Stop'),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('snooze'),
            onPressed: () => _attempt(context, () async {
              await platform.snooze(alarmId, snoozeMinutes);
              await platform.stopRinging();
            }, 'Snooze failed — the alarm keeps ringing.'),
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
