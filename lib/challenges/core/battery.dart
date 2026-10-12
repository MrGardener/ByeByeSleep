import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the phone is on a charger.
abstract class ChargeSource {
  Future<bool> isPlugged();
  Stream<bool> get plugged;
}

class BatteryPlusChargeSource implements ChargeSource {
  final _battery = Battery();

  static bool _isPlugged(BatteryState s) =>
      s == BatteryState.charging ||
      s == BatteryState.full ||
      s == BatteryState.connectedNotCharging;

  @override
  Future<bool> isPlugged() async => _isPlugged(await _battery.batteryState);

  @override
  Stream<bool> get plugged => _battery.onBatteryStateChanged.map(_isPlugged);
}

final chargeSourceProvider = Provider<ChargeSource>(
  (_) => BatteryPlusChargeSource(),
);

/// The battery charge in percent (0–100).
abstract class BatteryLevelSource {
  Future<int> level();
}

class BatteryPlusLevelSource implements BatteryLevelSource {
  final _battery = Battery();

  @override
  Future<int> level() => _battery.batteryLevel;
}

final batteryLevelProvider = Provider<BatteryLevelSource>(
  (_) => BatteryPlusLevelSource(),
);
