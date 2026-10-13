import 'package:flutter/material.dart';

import '../alarm/alarm.dart';
import '../alarm/ui/alarm_edit_screen.dart';
import '../alarm/ui/alarm_list_screen.dart';
import '../game/practice_screen.dart';
import '../game/quest_screen.dart';
import '../ringing/ring_screen.dart';

const editRoute = '/edit';
const ringRoutePrefix = '/ring/';
const questRoute = '/quest';
const practiceRoute = '/practice';

Route<dynamic> generateRoute(RouteSettings settings) {
  final name = settings.name ?? '/';
  final ringId = name.startsWith(ringRoutePrefix)
      ? int.tryParse(name.substring(ringRoutePrefix.length))
      : null;
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => switch (name) {
      _ when ringId != null => RingScreen(alarmId: ringId),
      editRoute => AlarmEditScreen(alarm: settings.arguments as Alarm?),
      questRoute => const QuestScreen(),
      practiceRoute => const PracticeScreen(),
      _ => const AlarmListScreen(),
    },
  );
}
