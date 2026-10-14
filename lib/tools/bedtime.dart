import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ios_bedtime.dart';

/// Sleep goals offered, in minutes (6 h to 10 h).
const sleepGoals = [360, 390, 420, 450, 480, 510, 540, 570, 600];

String sleepLabel(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// "Time for bed" reminder: the next morning's first alarm minus the sleep
/// goal. Scheduled natively (Bedtime.kt), so it follows the alarms even when
/// the app is not opened.
class BedtimeSettings {
  const BedtimeSettings({
    this.enabled = false,
    this.sleepMinutes = 480,
    this.nextAt,
  });

  final bool enabled;
  final int sleepMinutes;

  /// When the next reminder shows (null: off or no alarm ahead).
  final DateTime? nextAt;
}

abstract class BedtimePlatform {
  /// Null when this phone has no bedtime reminder.
  Future<BedtimeSettings?> get();
  Future<BedtimeSettings> set(BedtimeSettings settings);
}

class UnsupportedBedtime implements BedtimePlatform {
  @override
  Future<BedtimeSettings?> get() async => null;

  @override
  Future<BedtimeSettings> set(BedtimeSettings settings) async => settings;
}

class MethodChannelBedtime implements BedtimePlatform {
  static const _channel = MethodChannel('byebyesleep/bedtime');

  static BedtimeSettings _from(Map<Object?, Object?> m) => BedtimeSettings(
    enabled: m['enabled'] == true,
    sleepMinutes: (m['sleepMinutes'] as num?)?.toInt() ?? 480,
    nextAt: m['nextAtMs'] is num
        ? DateTime.fromMillisecondsSinceEpoch((m['nextAtMs']! as num).toInt())
        : null,
  );

  @override
  Future<BedtimeSettings?> get() async {
    try {
      final m = await _channel.invokeMapMethod<Object?, Object?>('get');
      return m == null ? null : _from(m);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<BedtimeSettings> set(BedtimeSettings s) async => _from(
    (await _channel.invokeMapMethod<Object?, Object?>('set', {
      'enabled': s.enabled,
      'sleepMinutes': s.sleepMinutes,
    }))!,
  );
}

/// iPhone: planned in Dart (ios_bedtime.dart); Android: Bedtime.kt.
final bedtimePlatformProvider = Provider<BedtimePlatform>(
  (ref) => ref.watch(isIosProvider)
      ? ref.watch(iosBedtimeProvider)
      : MethodChannelBedtime(),
);

class BedtimeNotifier extends AsyncNotifier<BedtimeSettings?> {
  @override
  Future<BedtimeSettings?> build() => ref.read(bedtimePlatformProvider).get();

  Future<void> set(BedtimeSettings s) async {
    state = AsyncData(s);
    state = AsyncData(await ref.read(bedtimePlatformProvider).set(s));
  }
}

final bedtimeProvider =
    AsyncNotifierProvider<BedtimeNotifier, BedtimeSettings?>(
      BedtimeNotifier.new,
    );
