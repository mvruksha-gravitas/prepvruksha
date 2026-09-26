import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'app_config_provider.dart';

/// The signed-in staff member's access token for `services/api`.
final accessTokenProvider = Provider<AccessTokenProvider>(
  (ref) =>
      () async => Supabase.instance.client.auth.currentSession?.accessToken,
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    baseUrl: ref.watch(appConfigProvider).apiUrl,
    accessToken: ref.watch(accessTokenProvider),
  ),
);
