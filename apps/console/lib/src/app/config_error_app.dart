import 'package:core/core.dart';
import 'package:flutter/material.dart';

/// Shown instead of the app when the build is missing configuration.
/// Developer-facing only, so the text is not localised.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.error});

  final ConfigException error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(error.toString()),
          ),
        ),
      ),
    );
  }
}
