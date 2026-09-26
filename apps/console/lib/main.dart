import 'package:flutter/material.dart';
import 'package:ui_kit/ui_kit.dart';

void main() => runApp(const ConsoleApp());

/// Placeholder until the import pipeline + review console slice (weeks 2–4).
/// Internal staff tool; localisation is added with its first real screens.
class ConsoleApp extends StatelessWidget {
  const ConsoleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrepVruksha Console',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const Scaffold(body: Center(child: Text('PrepVruksha Console'))),
    );
  }
}
