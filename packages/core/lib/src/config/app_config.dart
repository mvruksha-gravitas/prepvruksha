/// Runtime configuration passed in at build time with
/// `--dart-define-from-file=config/<env>.json`. Keys are never committed.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.apiUrl,
  });

  /// Reads the values compiled in via `--dart-define`.
  ///
  /// Throws [ConfigException] when a required value is missing.
  factory AppConfig.fromEnvironment() => AppConfig.fromMap(const {
    'APP_ENV': String.fromEnvironment('APP_ENV'),
    'SUPABASE_URL': String.fromEnvironment('SUPABASE_URL'),
    'SUPABASE_PUBLISHABLE_KEY': String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
    'API_URL': String.fromEnvironment('API_URL'),
  });

  /// Builds a config from raw key/value pairs, validating required keys.
  factory AppConfig.fromMap(Map<String, String> values) {
    final missing = [
      for (final key in requiredKeys)
        if ((values[key] ?? '').trim().isEmpty) key,
    ];
    if (missing.isNotEmpty) throw ConfigException(missing);

    for (final key in const ['SUPABASE_URL', 'API_URL']) {
      final uri = Uri.tryParse(values[key]!.trim());
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        throw ConfigException([key], reason: 'not a valid URL');
      }
    }

    final env = (values['APP_ENV'] ?? '').trim();
    return AppConfig(
      environment: env.isEmpty ? 'dev' : env,
      supabaseUrl: values['SUPABASE_URL']!.trim(),
      supabasePublishableKey: values['SUPABASE_PUBLISHABLE_KEY']!.trim(),
      apiUrl: values['API_URL']!.trim().replaceFirst(RegExp(r'/+$'), ''),
    );
  }

  static const requiredKeys = [
    'SUPABASE_URL',
    'SUPABASE_PUBLISHABLE_KEY',
    'API_URL',
  ];

  /// `local`, `dev` or `prod`.
  final String environment;
  final String supabaseUrl;

  /// The public (publishable, formerly "anon") key. Never the secret or
  /// service role key.
  final String supabasePublishableKey;

  /// Base URL of `services/api`, without a trailing slash.
  final String apiUrl;
}

class ConfigException implements Exception {
  ConfigException(this.keys, {this.reason = 'missing'});

  final List<String> keys;
  final String reason;

  @override
  String toString() =>
      'ConfigException: ${keys.join(', ')} $reason. Run with '
      '--dart-define-from-file=config/<env>.json (see config/dev.example.json).';
}
