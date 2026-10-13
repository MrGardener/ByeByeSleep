import 'package:flutter/material.dart';

import '../alarm/ui/alarm_list_screen.dart';
import '../game/practice_screen.dart';
import '../game/quest_screen.dart';
import '../ringing/ring_launcher.dart';

/// The app's three tools, one tab each.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var _tab = 0;

  @override
  Widget build(BuildContext context) {
    return RingLauncher(child: _scaffold());
  }

  Widget _scaffold() {
    return Scaffold(
      // Only the open tab is built, so the game's sensor probes do not run
      // while you are just setting alarms.
      body: switch (_tab) {
        1 => const QuestScreen(),
        2 => const PracticeScreen(),
        _ => const AlarmListScreen(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            key: Key('tab-alarms'),
            icon: Icon(Icons.alarm),
            label: 'Alarms',
          ),
          NavigationDestination(
            key: Key('tab-quest'),
            icon: Icon(Icons.sports_esports),
            label: 'Sensor Quest',
          ),
          NavigationDestination(
            key: Key('tab-practice'),
            icon: Icon(Icons.fitness_center),
            label: 'Practice',
          ),
        ],
      ),
    );
  }
}
