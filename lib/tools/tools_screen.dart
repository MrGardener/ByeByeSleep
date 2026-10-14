import 'package:flutter/material.dart';

import 'clock_screen.dart';
import 'stopwatch_screen.dart';
import 'timer_screen.dart';

/// Clock, timer and stopwatch, one tab each.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Clock'),
          bottom: const TabBar(
            tabs: [
              Tab(
                key: Key('tool-clock'),
                icon: Icon(Icons.schedule),
                text: 'Clock',
              ),
              Tab(
                key: Key('tool-timer'),
                icon: Icon(Icons.hourglass_bottom),
                text: 'Timer',
              ),
              Tab(
                key: Key('tool-stopwatch'),
                icon: Icon(Icons.timer_outlined),
                text: 'Stopwatch',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [ClockScreen(), TimerScreen(), StopwatchScreen()],
        ),
      ),
    );
  }
}
