import 'package:flutter/material.dart';

import 'routes.dart';

class ByeByeSleepApp extends StatelessWidget {
  const ByeByeSleepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ByeByeSleep',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.dark,
        ),
      ),
      builder: appBuilder,
      initialRoute: WidgetsBinding.instance.platformDispatcher.defaultRouteName,
      onGenerateRoute: generateRoute,
      onGenerateInitialRoutes: (name) => [
        generateRoute(RouteSettings(name: name)),
      ],
    );
  }
}

/// Wraps every screen, dialog and bottom sheet of the app. Android draws apps
/// edge to edge, under the back / home / switch buttons; keeping everything
/// inside the safe area means no button or text ever sits underneath them.
/// The status bar at the top is handled by each app bar.
Widget appBuilder(BuildContext context, Widget? child) => ColoredBox(
  color: Theme.of(context).colorScheme.surface,
  child: SafeArea(top: false, child: child!),
);
