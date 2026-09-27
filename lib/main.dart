import 'package:flutter/material.dart';

import 'views/home_view.dart';

void main() {
  runApp(const PitchCoachApp());
}

class PitchCoachApp extends StatelessWidget {
  const PitchCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '음치탈출',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark, useMaterial3: true),
      home: const HomeView(),
    );
  }
}
