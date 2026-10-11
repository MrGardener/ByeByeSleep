import 'package:flutter/material.dart';

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
      home: const Scaffold(body: Center(child: Text('ByeByeSleep'))),
    );
  }
}
