import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  group('AppConfig.fromMap', () {
    test('reads valid values and defaults the environment to dev', () {
      final config = AppConfig.fromMap({
        'SUPABASE_URL': 'http://127.0.0.1:54321',
        'SUPABASE_PUBLISHABLE_KEY': 'anon',
        'API_URL': 'http://127.0.0.1:8000/',
      });
      expect(config.environment, 'dev');
      expect(config.apiUrl, 'http://127.0.0.1:8000');
      expect(config.supabaseUrl, 'http://127.0.0.1:54321');
      expect(config.supabasePublishableKey, 'anon');
    });

    test('lists every missing key', () {
      expect(
        () => AppConfig.fromMap({'SUPABASE_URL': ' '}),
        throwsA(
          isA<ConfigException>().having((e) => e.keys, 'keys', [
            'SUPABASE_URL',
            'SUPABASE_PUBLISHABLE_KEY',
            'API_URL',
          ]),
        ),
      );
    });

    test('rejects a URL without a scheme', () {
      expect(
        () => AppConfig.fromMap({
          'SUPABASE_URL': 'example.supabase.co',
          'SUPABASE_PUBLISHABLE_KEY': 'anon',
          'API_URL': 'http://127.0.0.1:8000',
        }),
        throwsA(isA<ConfigException>()),
      );
    });
  });
}
