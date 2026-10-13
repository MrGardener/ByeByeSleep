import 'package:flutter/material.dart';

import '../alarm/alarm.dart';
import '../alarm/alarm_platform.dart';
import '../alarm/series.dart';
import '../alarm/ui/stored_photo.dart';

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
/// the rest of the series today.
Future<void> afterStop(
  BuildContext context,
  AlarmPlatform platform,
  Alarm? alarm,
  DateTime now,
) async {
  if (alarm == null) return;
  final reminder = alarm.reminder;
  if (reminder != null && !reminder.isEmpty) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ReminderScreen(reminder: reminder)),
    );
    if (!context.mounted) return;
  }
  if (alarm.series == null && alarm.parentId == null) return;
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
                width: 64,
                height: 64,
                child: StoredPhoto(photo, fit: BoxFit.cover),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reminder.caption.isEmpty
                    ? "Don't forget!"
                    : "Don't forget: ${reminder.caption}",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
