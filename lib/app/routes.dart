import 'package:flutter/material.dart';

import '../alarm/alarm.dart';
import '../alarm/ui/alarm_edit_screen.dart';
import '../alarm/ui/alarm_list_screen.dart';

const editRoute = '/edit';

Route<dynamic> generateRoute(RouteSettings settings) {
  final name = settings.name ?? '/';
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => switch (name) {
      editRoute => AlarmEditScreen(alarm: settings.arguments as Alarm?),
      _ => const AlarmListScreen(),
    },
  );
}
