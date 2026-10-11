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
      initialRoute: WidgetsBinding.instance.platformDispatcher.defaultRouteName,
      onGenerateRoute: generateRoute,
      onGenerateInitialRoutes: (name) => [
        generateRoute(RouteSettings(name: name)),
      ],
    );
  }
}
