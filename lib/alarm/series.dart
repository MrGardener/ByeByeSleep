import 'package:flutter/foundation.dart';

import '../challenges/core/challenge_id.dart';
import 'alarm.dart';
import 'stage_config.dart';

/// Something not to forget, shown while ringing and after Stop.
@immutable
class Reminder {
  const Reminder({this.photoPath, this.caption = ''});

  factory Reminder.fromJson(Map<String, Object?> j) => Reminder(
    photoPath: j['photo'] as String?,
    caption: j['caption'] as String? ?? '',
  );

  static const maxCaption = 120;

  /// File in the photo store, or null for a caption-only reminder.
  final String? photoPath;
  final String caption;

  bool get isEmpty => photoPath == null && caption.trim().isEmpty;

  Map<String, Object?> toJson() => {
    if (photoPath != null) 'photo': photoPath,
    'caption': caption,
  };

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.photoPath == photoPath &&
      other.caption == caption;

  @override
  int get hashCode => Object.hash(photoPath, caption);
}

/// Main alarm first and the rest after it, or the main alarm as the target
/// at the end with the rest before it.
enum SeriesDirection { after, before }

/// What the other alarms of a series ask for.
enum FollowUp {
  /// The main alarm's challenges.
  same,

  /// One quick broken-calculator sum.
  quick,
}

/// A main alarm repeated [count] times in total, [everyMinutes] apart.
@immutable
class SeriesConfig {
  const SeriesConfig({
    required this.count,
    required this.everyMinutes,
    this.direction = SeriesDirection.after,
    this.followUp = FollowUp.same,
  }) : assert(count >= 2 && count <= maxCount),
       assert(everyMinutes >= 1 && everyMinutes <= maxEvery);

  factory SeriesConfig.fromJson(Map<String, Object?> j) => SeriesConfig(
    count: ((j['count'] as num?)?.toInt() ?? 2).clamp(2, maxCount),
    everyMinutes: ((j['every'] as num?)?.toInt() ?? 5).clamp(1, maxEvery),
    direction: j['direction'] == 'before'
        ? SeriesDirection.before
        : SeriesDirection.after,
    followUp: j['followUp'] == 'quick' ? FollowUp.quick : FollowUp.same,
  );

  static const maxCount = 10;
  static const maxEvery = 30;

  final int count;
  final int everyMinutes;
  final SeriesDirection direction;
  final FollowUp followUp;

  Map<String, Object?> toJson() => {
    'count': count,
    'every': everyMinutes,
    'direction': direction.name,
    'followUp': followUp.name,
  };

  @override
  bool operator ==(Object other) =>
      other is SeriesConfig &&
      other.count == count &&
      other.everyMinutes == everyMinutes &&
      other.direction == direction &&
      other.followUp == followUp;

  @override
  int get hashCode => Object.hash(count, everyMinutes, direction, followUp);
}

/// Id of the [k]-th other alarm (1-based) of main alarm [parentId].
int seriesChildId(int parentId, int k) => parentId * 100 + k;

const quickFollowUp = [
  StageConfig(ChallengeId.brokenCalculator, difficulty: 2),
];

/// The other alarms of [main]'s series, in ringing order. A child that lands
/// on the day before or after keeps ringing on the matching days.
List<Alarm> seriesChildren(Alarm main) {
  final series = main.series;
  if (series == null) return const [];
  final sign = series.direction == SeriesDirection.after ? 1 : -1;
  final base = main.hour * 60 + main.minute;
  final ks = [for (var k = 1; k < series.count; k++) k];
  // "before": the earliest alarm first, so ids still follow ringing order.
  final offsets = sign > 0
      ? [for (final k in ks) k * series.everyMinutes]
      : [for (final k in ks.reversed) -k * series.everyMinutes];
  return [
    for (var i = 0; i < offsets.length; i++)
      _child(main, series, i + 1, base + offsets[i]),
  ];
}

Alarm _child(Alarm main, SeriesConfig series, int k, int minutes) {
  final dayShift = (minutes / (24 * 60)).floor();
  final inDay = minutes - dayShift * 24 * 60;
  return Alarm(
    id: seriesChildId(main.id, k),
    hour: inDay ~/ 60,
    minute: inDay % 60,
    repeatDays: {for (final d in main.repeatDays) (d - 1 + dayShift) % 7 + 1},
    label: main.label,
    enabled: main.enabled,
    stages: series.followUp == FollowUp.quick ? quickFollowUp : main.stages,
    pauseSeconds: main.pauseSeconds,
    reminder: main.reminder,
    parentId: main.id,
  );
}
