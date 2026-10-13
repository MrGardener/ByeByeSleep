import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wi-Fi, Bluetooth and airplane mode, as the phone reports them.
class RadioState {
  const RadioState({
    required this.wifiOn,
    required this.bluetoothOn,
    required this.airplaneOn,
  });

  final bool wifiOn;
  final bool bluetoothOn;
  final bool airplaneOn;
}

/// The emergency protocol anyone can follow to stop a ringing alarm without
/// the challenges. Any order.
enum EmergencyStep {
  volumeButton('Press a volume button'),
  wifiOff('Turn Wi-Fi off'),
  bluetoothOff('Turn Bluetooth off'),
  airplaneOn('Turn airplane mode on');

  const EmergencyStep(this.label);

  final String label;
}

/// Tracks the steps. A step stays done once seen, so turning airplane mode
/// on (which also switches the radios off) and back does not undo anything.
class EmergencyProtocol {
  final done = <EmergencyStep>{};

  bool get complete => done.length == EmergencyStep.values.length;

  void volumePressed() => done.add(EmergencyStep.volumeButton);

  void radios(RadioState s) {
    if (!s.wifiOn) done.add(EmergencyStep.wifiOff);
    if (!s.bluetoothOn) done.add(EmergencyStep.bluetoothOff);
    if (s.airplaneOn) done.add(EmergencyStep.airplaneOn);
  }
}

/// Volume key presses on the ring screen and the radio switches.
abstract class EmergencySource {
  Stream<void> get volumePresses;

  /// Null when the phone cannot tell.
  Future<RadioState?> radios();
}

class ChannelEmergencySource implements EmergencySource {
  static const _methods = MethodChannel('byebyesleep/emergency');
  static const _keys = EventChannel('byebyesleep/volume_keys');

  @override
  Stream<void> get volumePresses => _keys
      .receiveBroadcastStream()
      .handleError(
        (Object _) {},
        test: (e) => e is PlatformException || e is MissingPluginException,
      )
      .map((_) {});

  @override
  Future<RadioState?> radios() async {
    try {
      final m = await _methods.invokeMapMethod<String, bool>('radios');
      if (m == null) return null;
      return RadioState(
        wifiOn: m['wifi'] ?? false,
        bluetoothOn: m['bluetooth'] ?? false,
        airplaneOn: m['airplane'] ?? false,
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

final emergencySourceProvider = Provider<EmergencySource>(
  (_) => ChannelEmergencySource(),
);
