import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'types.dart';

/// One message from the watch.
sealed class WatchReading {
  const WatchReading();
}

class HeartRateReading extends WatchReading {
  const HeartRateReading(this.bpm);
  final int bpm;
}

/// Wrist movement: linear acceleration (gravity removed) in m/s², ~10 Hz.
class MotionReading extends WatchReading {
  const MotionReading(this.magnitudes);
  final List<double> magnitudes;
}

/// Steps the watch counted since its sensor screen opened.
class StepsReading extends WatchReading {
  const StepsReading(this.steps);
  final int steps;
}

/// Sensors on the wrist. Today: the ByeByeSleep app on a Wear OS watch
/// (Pixel Watch 3 is the reference; Galaxy Watch and other Wear OS watches
/// run the same app). Fitbit trackers cannot run third-party apps; a
/// Health Connect source (minutes behind, no live motion) could implement
/// this interface later.
abstract class WatchSource {
  /// A watch with the ByeByeSleep watch app is connected.
  Future<bool> available();

  /// Readings while listened to; listening opens the watch app's sensor
  /// screen, cancelling closes it.
  Stream<WatchReading> get readings;
}

/// Native side: android/.../alarm/WatchChannel.kt.
class ChannelWatchSource implements WatchSource {
  static const _methods = MethodChannel('byebyesleep/watch');
  static const _events = EventChannel('byebyesleep/watch_readings');

  @override
  Future<bool> available() async {
    try {
      return await _methods.invokeMethod<bool>('available') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static WatchReading? decode(Object? event) {
    if (event is! Map) return null;
    final value = event['value'];
    return switch (event['type']) {
      'hr' when value is num => HeartRateReading(value.toInt()),
      'steps' when value is num => StepsReading(value.toInt()),
      'motion' when value is List => MotionReading([
        for (final v in value)
          if (v is num) v.toDouble(),
      ]),
      _ => null,
    };
  }

  @override
  Stream<WatchReading> get readings {
    StreamSubscription<Object?>? sub;
    late final StreamController<WatchReading> out;
    out = StreamController<WatchReading>(
      onListen: () {
        _methods.invokeMethod<void>('start').catchError((Object _) {});
        sub = _events.receiveBroadcastStream().listen((e) {
          final r = decode(e);
          if (r != null) out.add(r);
        }, onError: (Object _) {});
      },
      onCancel: () async {
        await sub?.cancel();
        await _methods.invokeMethod<void>('stop').catchError((Object _) {});
      },
    );
    return out.stream;
  }
}

final watchSourceProvider = Provider<WatchSource>((_) => ChannelWatchSource());

/// Monotonic time for watch challenges; tests override it.
final watchClockProvider = Provider<Duration Function()>((_) {
  final watch = Stopwatch()..start();
  return () => watch.elapsed;
});

/// Capability probe: the watch app streams heart rate, motion and steps.
Future<Set<SensorKind>> watchCapability() async =>
    await ChannelWatchSource().available()
    ? {SensorKind.heartRate, SensorKind.watchMotion, SensorKind.watchSteps}
    : {};
