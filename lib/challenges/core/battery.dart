import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
