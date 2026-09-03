import 'package:flutter/material.dart';

import 'screens/home_page.dart';

void main() => runApp(const OptimalRollApp());

class OptimalRollApp extends StatelessWidget {
  const OptimalRollApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OptimalRoll',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      useMaterial3: true,
    ),
    home: const HomePage(),
  );
}
