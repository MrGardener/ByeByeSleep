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
import '../challenges/core/capabilities.dart';
import '../challenges/core/types.dart';
import '../challenges/registry.dart';
import 'after_stop.dart';
import 'emergency_screen.dart';
import 'safety_exit.dart';
import 'stage_engine.dart';
import 'stage_runner.dart';

const snoozeMinutes = 9;
const _loadTimeout = Duration(seconds: 3);

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

  /// Loads stages, progress and sensors. Every step falls back to a safe
  /// default: a ringing alarm must always reach its stages and, after
  /// 15 minutes, the emergency stop.
  Future<void> _load() async {
    Alarm? alarm;
    try {
      // Ask the platform directly: the list provider retries failures and
      // would leave this screen loading forever.
      final alarms = await _platform.list().timeout(_loadTimeout);
      alarm = alarms.where((a) => a.id == widget.alarmId).firstOrNull;
    } catch (_) {
      alarm = null;
    }
    if (!mounted) return;
    final now = widget.clock();
    RingProgress? progress;
    try {
      progress = await _platform.getRingProgress().timeout(_loadTimeout);
    } catch (_) {
      progress = null;
    }
    if (!mounted) return;
    if (progress == null || progress.alarmId != widget.alarmId) {
      progress = RingProgress(
        alarmId: widget.alarmId,
        stageIndex: 0,
        startedAtMs: now.millisecondsSinceEpoch,
      );
      unawaited(_platform.saveRingProgress(progress).catchError((Object _) {}));
    }
    // The "check I'm awake" ring after a Stop asks one quick challenge.
    final List<StageConfig> stages =
        kDebugMode && widget.alarmId == debugSmokeAlarmId
        ? const []
        : progress.followUp
        ? awakeCheckStages
        : alarm?.stages ?? defaultStages;
    Set<SensorKind> available;
    try {
      available = await ref.read(deviceCapabilitiesProvider.future);
    } catch (_) {
      available = const {};
    }
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
        breather: Duration(seconds: alarm?.pauseSeconds ?? 0),
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
      unawaited(
        _platform.saveRingProgress(_progress!).catchError((Object _) {}),
      );
    }
    if (engine.ringLevel != _level) {
      _level = engine.ringLevel;
      unawaited(
        _platform.setRingLevel(engine.ringLevel).catchError((Object _) {}),
      );
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

  /// The alarm stopped for good (not snoozed): reminder, series, then close.
  Future<void> _stopped() async {
    final checkRing = _progress?.followUp ?? false;
    if (await afterStop(
      context,
      _platform,
      _alarm,
      widget.clock(),
      checkRing: checkRing,
    )) {
      _finish();
    }
  }

  Future<void> _emergency() async {
    final confirmed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const EmergencyScreen()));
    if (confirmed != true) return;
    await _platform.stopRinging();
    await _stopped();
  }

  Future<void> _safetyExit() async {
    final confirmed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const SafetyExitScreen()));
    if (confirmed != true) return;
    await _platform.stopRinging();
    await _stopped();
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
                if (_progress?.followUp ?? false)
                  Text('Still awake?', style: text.headlineSmall),
                if (label.isNotEmpty) Text(label, style: text.titleMedium),
                if (_alarm?.reminder case final r? when !r.isEmpty)
                  RingReminderCard(reminder: r),
                const SizedBox(height: 12),
                Expanded(
                  child: engine == null
                      ? const Center(child: CircularProgressIndicator())
                      : _body(engine),
                ),
                if (engine != null && engine.phase is! Done)
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton.icon(
                        key: const Key('emergency'),
                        onPressed: _emergency,
                        icon: const Icon(Icons.emergency_outlined),
                        label: const Text('Emergency stop'),
                      ),
                      if (engine.safetyExitAvailable)
                        TextButton(
                          key: const Key('safety-exit'),
                          onPressed: _safetyExit,
                          child: const Text("I can't finish — type to stop"),
                        ),
                    ],
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
        child: _ActionButtons(
          alarmId: widget.alarmId,
          onSnoozed: _finish,
          onStopped: _stopped,
        ),
      ),
    };
  }
}

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({
    required this.alarmId,
    required this.onSnoozed,
    required this.onStopped,
  });

  final int alarmId;
  final VoidCallback onSnoozed;
  final VoidCallback onStopped;

  /// Runs [action]; on failure keeps the screen (the alarm keeps ringing)
  /// and tells the user.
  Future<void> _attempt(
    BuildContext context,
    Future<void> Function() action,
    String error,
    VoidCallback onDone,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    onDone();
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
              onStopped,
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Stop'),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('snooze'),
            onPressed: () => _attempt(
              context,
              () async {
                await platform.snooze(alarmId, snoozeMinutes);
                await platform.stopRinging();
              },
              'Snooze failed — the alarm keeps ringing.',
              onSnoozed,
            ),
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
