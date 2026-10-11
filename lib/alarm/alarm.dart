import 'package:flutter/foundation.dart';

/// A scheduled alarm. Weekdays use ISO-8601 numbering: 1 = Monday … 7 = Sunday.
/// An empty [repeatDays] means a one-shot alarm.
@immutable
class Alarm {
  Alarm({
    required this.id,
    required this.hour,
    required this.minute,
    this.repeatDays = const {},
    this.label = '',
    this.enabled = true,
  }) : assert(hour >= 0 && hour < 24),
       assert(minute >= 0 && minute < 60),
       assert(repeatDays.every((d) => d >= 1 && d <= 7));

  factory Alarm.fromMap(Map<Object?, Object?> m) => Alarm(
    id: m['id']! as int,
    hour: m['hour']! as int,
    minute: m['minute']! as int,
    repeatDays: {
      for (final d in (m['repeatDays'] as List<Object?>? ?? const []))
        d! as int,
    },
    label: m['label'] as String? ?? '',
    enabled: m['enabled'] as bool? ?? true,
  );

  final int id;
  final int hour;
  final int minute;
  final Set<int> repeatDays;
  final String label;
  final bool enabled;

  bool get isRepeating => repeatDays.isNotEmpty;

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  Alarm copyWith({
    int? hour,
    int? minute,
    Set<int>? repeatDays,
    String? label,
    bool? enabled,
  }) => Alarm(
    id: id,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    repeatDays: repeatDays ?? this.repeatDays,
    label: label ?? this.label,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'hour': hour,
    'minute': minute,
    'repeatDays': repeatDays.toList()..sort(),
    'label': label,
    'enabled': enabled,
  };

  @override
  bool operator ==(Object other) =>
      other is Alarm &&
      other.id == id &&
      other.hour == hour &&
      other.minute == minute &&
      setEquals(other.repeatDays, repeatDays) &&
      other.label == label &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(
    id,
    hour,
    minute,
    Object.hashAllUnordered(repeatDays),
    label,
    enabled,
  );

  @override
  String toString() =>
      'Alarm($id, $timeLabel, $repeatDays, "$label", $enabled)';
}
