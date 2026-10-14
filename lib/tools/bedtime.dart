import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.windDownMinutes = 0,
    this.quietHours = false,
    this.quietHoursAllowed = false,
    this.quietHoursSupported = false,
    this.nextAt,
  });

  final bool enabled;
  final int sleepMinutes;

  /// A "wind down" reminder this long before bedtime; 0 = none.
  final int windDownMinutes;

  /// Do Not Disturb from bedtime until the alarm (alarms still ring).
  final bool quietHours;

  /// The app may switch Do Not Disturb (Android asks once).
  final bool quietHoursAllowed;

  /// This phone can do quiet hours at all (Android).
  final bool quietHoursSupported;

  /// When the next reminder shows (null: off or no alarm ahead).
  final DateTime? nextAt;

  BedtimeSettings copyWith({
    bool? enabled,
    int? sleepMinutes,
    int? windDownMinutes,
    bool? quietHours,
  }) => BedtimeSettings(
    enabled: enabled ?? this.enabled,
    sleepMinutes: sleepMinutes ?? this.sleepMinutes,
    windDownMinutes: windDownMinutes ?? this.windDownMinutes,
    quietHours: quietHours ?? this.quietHours,
    quietHoursAllowed: quietHoursAllowed,
    quietHoursSupported: quietHoursSupported,
    nextAt: nextAt,
  );
}

abstract class BedtimePlatform {
  /// Null when this phone has no bedtime reminder.
  Future<BedtimeSettings?> get();
  Future<BedtimeSettings> set(BedtimeSettings settings);

  /// Opens the system page that lets the app switch Do Not Disturb.
  Future<void> openQuietHoursAccess();
}

/// Wind-down choices, in minutes before bedtime.
const windDownChoices = [0, 15, 30, 45, 60];

String windDownLabel(int minutes) =>
    minutes == 0 ? 'Off' : '${sleepLabelShort(minutes)} before';

String sleepLabelShort(int minutes) =>
    minutes % 60 == 0 ? '${minutes ~/ 60} h' : '$minutes min';

class UnsupportedBedtime implements BedtimePlatform {
  @override
  Future<BedtimeSettings?> get() async => null;

  @override
  Future<BedtimeSettings> set(BedtimeSettings settings) async => settings;

  @override
  Future<void> openQuietHoursAccess() async {}
}

class MethodChannelBedtime implements BedtimePlatform {
  static const _channel = MethodChannel('byebyesleep/bedtime');

  static BedtimeSettings _from(Map<Object?, Object?> m) => BedtimeSettings(
    enabled: m['enabled'] == true,
    sleepMinutes: (m['sleepMinutes'] as num?)?.toInt() ?? 480,
    windDownMinutes: (m['windDownMinutes'] as num?)?.toInt() ?? 0,
    quietHours: m['quietHours'] == true,
    quietHoursAllowed: m['quietHoursAllowed'] == true,
    quietHoursSupported: m.containsKey('quietHours'),
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
      'windDownMinutes': s.windDownMinutes,
      'quietHours': s.quietHours,
    }))!,
  );

  @override
  Future<void> openQuietHoursAccess() =>
      _channel.invokeMethod<void>('openQuietHoursAccess');
}

final bedtimePlatformProvider = Provider<BedtimePlatform>(
  (_) => MethodChannelBedtime(),
);

class BedtimeNotifier extends AsyncNotifier<BedtimeSettings?> {
  @override
  Future<BedtimeSettings?> build() => ref.read(bedtimePlatformProvider).get();

  Future<void> set(BedtimeSettings s) async {
    state = AsyncData(s);
    state = AsyncData(await ref.read(bedtimePlatformProvider).set(s));
  }

  Future<void> change(BedtimeSettings Function(BedtimeSettings) f) async {
    final current = state.value;
    if (current != null) await set(f(current));
  }

  /// Quiet hours need Do Not Disturb access: without it, open the system
  /// page instead (the switch stays off until access is given).
  Future<void> setQuietHours(bool on) async {
    final platform = ref.read(bedtimePlatformProvider);
    final fresh = await platform.get();
    if (fresh == null) return;
    if (on && !fresh.quietHoursAllowed) {
      state = AsyncData(fresh);
      await platform.openQuietHoursAccess();
      return;
    }
    await set(fresh.copyWith(quietHours: on));
  }
}

final bedtimeProvider =
    AsyncNotifierProvider<BedtimeNotifier, BedtimeSettings?>(
      BedtimeNotifier.new,
    );
