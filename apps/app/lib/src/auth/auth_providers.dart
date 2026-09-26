import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import 'supabase_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(Supabase.instance.client.auth),
);

final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// The signed-in user's id; changes only on sign-in and sign-out (not on
/// token refreshes).
final userIdProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider.select((user) => user.value?.id)),
);
