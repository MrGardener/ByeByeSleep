import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'types.dart';

/// Live heart rate from the ByeByeSleep watch app (native side:
/// android/.../alarm/WatchChannel.kt). Behind an interface for tests.
abstract class HeartRateSource {
  /// A watch with the ByeByeSleep watch app is connected.
  Future<bool> available();

  /// Beats per minute while listened to; listening opens the watch app,
  /// cancelling closes it.
  Stream<int> get bpm;
}

class ChannelHeartRateSource implements HeartRateSource {
  static const _methods = MethodChannel('byebyesleep/watch');
  static const _events = EventChannel('byebyesleep/heart_rate');

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

  @override
  Stream<int> get bpm {
    StreamSubscription<Object?>? sub;
    late final StreamController<int> out;
    out = StreamController<int>(
      onListen: () {
        _methods.invokeMethod<void>('start').catchError((Object _) {});
        sub = _events.receiveBroadcastStream().listen(
          (e) => out.add((e! as num).toInt()),
          onError: (Object _) {},
        );
      },
      onCancel: () async {
        await sub?.cancel();
        await _methods.invokeMethod<void>('stop').catchError((Object _) {});
      },
    );
    return out.stream;
  }
}

final heartRateSourceProvider = Provider<HeartRateSource>(
  (_) => ChannelHeartRateSource(),
);

/// Monotonic time for the heart-rate challenge; tests override it.
final heartRateClockProvider = Provider<Duration Function()>((_) {
  final watch = Stopwatch()..start();
  return () => watch.elapsed;
});

/// Capability probe: {heartRate} when a watch with the app is connected.
Future<Set<SensorKind>> watchCapability() async =>
    await ChannelHeartRateSource().available() ? {SensorKind.heartRate} : {};
