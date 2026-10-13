import 'dart:async';

import 'package:flutter/material.dart';

import '../alarm/alarm.dart';
import '../alarm/alarm_platform.dart';
import '../alarm/series.dart';
import '../alarm/ui/stored_photo.dart';
import '../app/routes.dart';

/// Alarms of [ringing]'s series that ring in the next 3 hours after [now].
List<Alarm> laterInSeries(Alarm ringing, List<Alarm> all, DateTime now) {
  final mainId = ringing.parentId ?? ringing.id;
  final nowMin = now.hour * 60 + now.minute;
  bool soon(Alarm a) {
    final m = _minutesUntil(a, nowMin);
    return m > 0 && m <= 180;
  }

  return [
    for (final a in all)
      if (a.id != ringing.id &&
          a.enabled &&
          (a.id == mainId || a.parentId == mainId) &&
          soon(a))
        a,
  ]..sort(
    (a, b) => _minutesUntil(a, nowMin).compareTo(_minutesUntil(b, nowMin)),
  );
}

int _minutesUntil(Alarm a, int nowMin) =>
    (a.hour * 60 + a.minute - nowMin) % (24 * 60);

/// Runs after the alarm was stopped: shows the reminder, then offers to skip
/// the rest of the series today. Returns false when another alarm started
/// ringing meanwhile and took over the screen (the caller must then not
/// close it).
Future<bool> afterStop(
  BuildContext context,
  AlarmPlatform platform,
  Alarm? alarm,
  DateTime now, {
  bool checkRing = false,
}) async {
  if (alarm == null) return true;
  // First, so it is set even if the screen is left at once. The check ring
  // itself schedules no further check (no loop).
  if (!checkRing && alarm.followUpMinutes > 0) {
    try {
      await platform.followUp(alarm.id, alarm.followUpMinutes);
    } catch (_) {
      // The check is a bonus; stopping must not fail because of it.
    }
    if (!context.mounted) return true;
  }
  // The screen stays open while the reminder or the question is shown; a
  // new ring (the next alarm of the series, or tomorrow's if the phone was
  // locked on this screen) must not ring behind it.
  var superseded = false;
  final navigator = Navigator.of(context);
  final watch = Timer.periodic(const Duration(seconds: 1), (t) async {
    List<int> ringing;
    try {
      ringing = await platform.ringingAlarmIds();
    } catch (_) {
      return;
    }
    if (ringing.isEmpty || superseded) return;
    superseded = true;
    t.cancel();
    unawaited(
      navigator.pushNamedAndRemoveUntil(
        '$ringRoutePrefix${ringing.first}',
        (_) => false,
      ),
    );
  });
  try {
    await _afterStop(context, platform, alarm, now, checkRing: checkRing);
  } finally {
    watch.cancel();
  }
  return !superseded;
}

Future<void> _afterStop(
  BuildContext context,
  AlarmPlatform platform,
  Alarm alarm,
  DateTime now, {
  required bool checkRing,
}) async {
  final reminder = alarm.reminder;
  if (reminder != null && !reminder.isEmpty) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ReminderScreen(reminder: reminder)),
    );
    if (!context.mounted) return;
  }
  if (checkRing || (alarm.series == null && alarm.parentId == null)) return;
  List<Alarm> later;
  try {
    later = laterInSeries(alarm, await platform.list(), now);
  } catch (_) {
    return;
  }
  if (later.isEmpty || !context.mounted) return;
  final skip = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      key: const Key('skip-series-dialog'),
      title: const Text('Skip the rest of this series today?'),
      content: Text(
        'Still to ring: ${later.map((a) => a.timeLabel).join(', ')}. '
        'They ring again on their next day.',
      ),
      actions: [
        TextButton(
          key: const Key('skip-series-no'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep them'),
        ),
        FilledButton(
          key: const Key('skip-series-yes'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Skip them'),
        ),
      ],
    ),
  );
  if (skip != true) return;
  for (final a in later) {
    try {
      await platform.skipNext(a.id);
    } catch (_) {
      // That alarm still rings; nothing better to do while waking up.
    }
  }
}

/// "Don't forget": the reminder's photo and caption, full screen.
class ReminderScreen extends StatelessWidget {
  const ReminderScreen({super.key, required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final photo = reminder.photoPath;
    return Scaffold(
      key: const Key('reminder-screen'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text("Don't forget"),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (photo != null) Expanded(child: StoredPhoto(photo)),
              if (reminder.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    reminder.caption,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              FilledButton(
                key: const Key('reminder-done'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The reminder as a small card on the ring screen.
class RingReminderCard extends StatelessWidget {
  const RingReminderCard({super.key, required this.reminder});

  final Reminder reminder;

  @override
  Widget build(BuildContext context) {
    final photo = reminder.photoPath;
    return Card(
      key: const Key('ring-reminder'),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            if (photo != null)
              SizedBox(
                width: 48,
                height: 48,
                child: StoredPhoto(photo, fit: BoxFit.cover),
              ),
            const SizedBox(width: 12),
            // Kept to two lines: the challenge below needs the room.
            Expanded(
              child: Text(
                reminder.caption.isEmpty
                    ? "Don't forget!"
                    : "Don't forget: ${reminder.caption}",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
