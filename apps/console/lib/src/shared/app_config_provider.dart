import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overridden in `main.dart` with the values from `--dart-define`.
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden'),
);
